#!/usr/bin/env bash
# =============================================================================
# PreToolUse Hook: Pre-Commit Quality Gate
# =============================================================================
#
# Intercepts `git commit` commands and enforces review requirements:
#   - >20 lines changed → code review required
#   - Security-sensitive files → security review required
#   - User-facing changes without doc updates → warning (non-blocking)
#
# Reviews are marked done via ~/.claude/hooks/mark-reviewed.sh
# Markers expire after 10 minutes to ensure fresh reviews.
#
# Exit codes:
#   0 = Allow commit
#   2 = Block commit (stderr fed back to Claude with instructions)
#
# =============================================================================

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Only gate git commit commands
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
    exit 0
fi

# Don't gate --allow-empty (initial commits, CI markers) or --amend (fixing existing commit)
if echo "$COMMAND" | grep -qE '\-\-allow-empty|\-\-amend'; then
    exit 0
fi

# Bail early if not inside a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Use $HOME/.claude/ for markers — stable path across shell and hook contexts
# (TMPDIR differs between user shell and Claude Code hook environment)
MARKER_DIR="$HOME/.claude/review-markers"
MARKER_TTL=600  # 10 minutes in seconds

SECURITY_PATTERNS='(auth|login|session|token|password|credential|crypto|encrypt|decrypt|hash|permission|role|access|middleware|security|cors|csrf|sanitiz|validat|secret|oauth|jwt|cookie|firewall)'
USER_FACING_PATTERNS='\.(tsx?|jsx?|vue|svelte|html)$|route|endpoint|controller|handler|/pages/|/views/|/components/'
DOC_PATTERNS='(readme|changelog|doc/|docs/|\.md$)'

# ---------------------------------------------------------------------------
# Determine what's being committed
# ---------------------------------------------------------------------------

# Detect -a / --all flag (stages all tracked changes)
if echo "$COMMAND" | grep -qE ' -[a-zA-Z]*a| --all'; then
    DIFF_REF="HEAD"
else
    DIFF_REF="--cached"
fi

# Count lines changed (additions + deletions)
LINES_CHANGED=$(git diff "$DIFF_REF" --numstat 2>/dev/null | awk '{s+=$1+$2} END {print s+0}')

# If nothing to commit, let git handle the error
if [[ "$LINES_CHANGED" -eq 0 ]]; then
    exit 0
fi

# Get changed file names
CHANGED_FILES=$(git diff "$DIFF_REF" --name-only 2>/dev/null || true)

# grep exits 1 on no match; || true prevents set -e from aborting
SECURITY_FILES=$(echo "$CHANGED_FILES" | grep -iE "$SECURITY_PATTERNS" || true)

# Check for user-facing changes
USER_FACING=$(echo "$CHANGED_FILES" | grep -iE "$USER_FACING_PATTERNS" || true)
DOC_CHANGES=$(echo "$CHANGED_FILES" | grep -iE "$DOC_PATTERNS" || true)

# ---------------------------------------------------------------------------
# Helper: check if a marker is fresh (exists and < TTL seconds old)
# ---------------------------------------------------------------------------

marker_is_fresh() {
    local marker_file="$1"

    if [[ ! -f "$marker_file" ]]; then
        return 1
    fi

    local marker_time
    marker_time=$(cat "$marker_file" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local age=$((current_time - marker_time))

    if [[ $age -lt $MARKER_TTL ]]; then
        return 0
    else
        rm -f "$marker_file" 2>/dev/null || true  # clean up expired marker
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Evaluate gates
# ---------------------------------------------------------------------------

BLOCKING_ISSUES=""
WARNINGS=""

# Gate 1: Large changes require code review
if [[ "$LINES_CHANGED" -gt 20 ]]; then
    if ! marker_is_fresh "$MARKER_DIR/code-reviewed"; then
        BLOCKING_ISSUES="${BLOCKING_ISSUES}📋 Code review required (${LINES_CHANGED} lines changed, threshold: 20)\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Run the code-reviewer agent to review changes\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Then run: ~/.claude/hooks/mark-reviewed.sh\n\n"
    fi
fi

# Gate 2: Security-sensitive files require security review
if [[ -n "$SECURITY_FILES" ]]; then
    if ! marker_is_fresh "$MARKER_DIR/security-reviewed"; then
        BLOCKING_ISSUES="${BLOCKING_ISSUES}🔒 Security review required for sensitive files:\n"
        while IFS= read -r f; do
            [[ -n "$f" ]] && BLOCKING_ISSUES="${BLOCKING_ISSUES}   - $f\n"
        done <<< "$SECURITY_FILES"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Run the security-analyst agent or /security-audit\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Then run: ~/.claude/hooks/mark-reviewed.sh --security\n\n"
    fi
fi

# Warning (non-blocking): user-facing changes without doc updates
if [[ -n "$USER_FACING" && -z "$DOC_CHANGES" ]]; then
    WARNINGS="${WARNINGS}📝 User-facing files changed but no documentation updates detected.\n"
    WARNINGS="${WARNINGS}   Consider running the docs-updater agent before or after committing.\n"
fi

# Warning (non-blocking): CUJ/AD staleness check
STALENESS_THRESHOLD=$((90 * 86400))  # 90 days in seconds
CURRENT_EPOCH=$(date +%s)

# Check CUJs for staleness (only if directory exists and not opted out)
if [[ -d "docs/cujs" && ! -f "docs/cujs/.opted-out" ]]; then
    for cuj_file in docs/cujs/*.md; do
        [[ -f "$cuj_file" ]] || continue
        # Extract last-verified date from frontmatter
        verified_date=$(sed -n '/^---$/,/^---$/{ s/^last-verified:[[:space:]]*//p; }' "$cuj_file" | head -1)
        if [[ -n "$verified_date" && "$verified_date" != "YYYY-MM-DD" ]]; then
            # Convert date to epoch (macOS date -j)
            verified_epoch=$(date -j -f "%Y-%m-%d" "$verified_date" "+%s" 2>/dev/null || echo "0")
            age=$((CURRENT_EPOCH - verified_epoch))
            if [[ $age -gt $STALENESS_THRESHOLD ]]; then
                cuj_name=$(basename "$cuj_file")
                WARNINGS="${WARNINGS}📋 CUJ docs/cujs/$cuj_name may be stale (last verified: $verified_date)\n"
            fi
        fi
    done

    # Check if any changed files are mentioned in CUJ content
    while IFS= read -r changed; do
        [[ -n "$changed" ]] || continue
        module=$(basename "$changed" | sed 's/\.[^.]*$//')
        match=$(grep -rl "$module" docs/cujs/*.md 2>/dev/null | head -1 || true)
        if [[ -n "$match" ]]; then
            cuj_name=$(basename "$match")
            WARNINGS="${WARNINGS}📋 Changed file $changed may affect CUJ docs/cujs/$cuj_name — consider reviewing.\n"
        fi
    done <<< "$CHANGED_FILES"
fi

# Check ADs for staleness (only if directory exists and not opted out)
if [[ -d "docs/decisions" && ! -f "docs/decisions/.opted-out" ]]; then
    for ad_file in docs/decisions/*.md; do
        [[ -f "$ad_file" ]] || continue
        # Extract date from frontmatter
        ad_date=$(sed -n '/^---$/,/^---$/{ s/^date:[[:space:]]*//p; }' "$ad_file" | head -1)
        if [[ -n "$ad_date" && "$ad_date" != "YYYY-MM-DD" ]]; then
            ad_epoch=$(date -j -f "%Y-%m-%d" "$ad_date" "+%s" 2>/dev/null || echo "0")
            age=$((CURRENT_EPOCH - ad_epoch))
            if [[ $age -gt $STALENESS_THRESHOLD ]]; then
                ad_name=$(basename "$ad_file")
                WARNINGS="${WARNINGS}📐 AD docs/decisions/$ad_name may be stale (date: $ad_date)\n"
            fi
        fi
    done
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# Print warnings (non-blocking) regardless
if [[ -n "$WARNINGS" ]]; then
    echo "" >&2
    printf "%b" "$WARNINGS" >&2
fi

# Block if there are unresolved issues
if [[ -n "$BLOCKING_ISSUES" ]]; then
    echo "🚧 Pre-commit quality gate — review required before committing:" >&2
    echo "" >&2
    printf "%b" "$BLOCKING_ISSUES" >&2
    exit 2
fi

exit 0
