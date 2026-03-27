#!/usr/bin/env bash
# =============================================================================
# PreToolUse Hook: Pre-Commit Quality Gate
# =============================================================================
#
# Intercepts `git commit` commands and enforces review requirements:
#   Gate 1: >20 lines changed → code review required
#   Gate 2: Security-sensitive files → security review required
#   Gate 3: Tests must pass before commit
#   Gate 4: Coverage must meet 80% threshold
#   Gate 5: User-facing changes → docs review required
#   Bonus:  Stale CUJ/AD touching changed code → blocking
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
# NOTE: Only works with plain-timestamp markers. Do NOT use for coverage-checked
# (which has format TIMESTAMP:PERCENTAGE). Coverage is parsed inline in Gate 4.
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

# Gate 3: Tests must pass
if ! marker_is_fresh "$MARKER_DIR/tests-passed"; then
    BLOCKING_ISSUES="${BLOCKING_ISSUES}🧪 Tests must pass before commit\n"
    BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Run tests for your project, then: ~/.claude/hooks/mark-reviewed.sh --tests\n"
    BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Or run the code-reviewer agent (it sets this marker automatically)\n\n"
fi

# Gate 4: Coverage must meet threshold (80%)
COVERAGE_MARKER="$MARKER_DIR/coverage-checked"
if [[ -f "$COVERAGE_MARKER" ]]; then
    # Coverage marker format: TIMESTAMP:PERCENTAGE (not plain timestamp)
    COVERAGE_CONTENT=$(cat "$COVERAGE_MARKER" 2>/dev/null || echo "0:0")
    COVERAGE_TIME="${COVERAGE_CONTENT%%:*}"
    COVERAGE_PCT="${COVERAGE_CONTENT##*:}"
    COVERAGE_AGE=$(( $(date +%s) - COVERAGE_TIME ))
    if [[ $COVERAGE_AGE -ge $MARKER_TTL ]]; then
        rm -f "$COVERAGE_MARKER" 2>/dev/null || true
        BLOCKING_ISSUES="${BLOCKING_ISSUES}📊 Coverage check expired — re-run tests with coverage\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Then: ~/.claude/hooks/mark-reviewed.sh --coverage <pct>\n\n"
    elif [[ "$COVERAGE_PCT" -lt 80 ]]; then
        BLOCKING_ISSUES="${BLOCKING_ISSUES}📊 Coverage too low: ${COVERAGE_PCT}% (minimum: 80%)\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Increase test coverage, then: ~/.claude/hooks/mark-reviewed.sh --coverage <pct>\n\n"
    fi
else
    BLOCKING_ISSUES="${BLOCKING_ISSUES}📊 Coverage check required before commit\n"
    BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Run tests with coverage, then: ~/.claude/hooks/mark-reviewed.sh --coverage <pct>\n"
    BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Or run the code-reviewer agent (it sets this marker automatically)\n\n"
fi

# Gate 5: User-facing changes require docs review
if [[ -n "$USER_FACING" && -z "$DOC_CHANGES" ]]; then
    if ! marker_is_fresh "$MARKER_DIR/docs-reviewed"; then
        BLOCKING_ISSUES="${BLOCKING_ISSUES}📝 Documentation review required for user-facing changes\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Run the docs-updater agent, then: ~/.claude/hooks/mark-reviewed.sh --docs\n"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Changed user-facing files:\n"
        while IFS= read -r f; do
            [[ -n "$f" ]] && BLOCKING_ISSUES="${BLOCKING_ISSUES}     - $f\n"
        done <<< "$USER_FACING"
        BLOCKING_ISSUES="${BLOCKING_ISSUES}\n"
    fi
fi

# CUJ/AD staleness check
# - Pure staleness (no code relationship): WARNING (non-blocking)
# - Changed code touches a stale CUJ/AD: BLOCKING
STALENESS_THRESHOLD=$((90 * 86400))  # 90 days in seconds
CURRENT_EPOCH=$(date +%s)

# Track stale CUJ/AD files as newline-delimited lists (bash 3.2 compatible)
STALE_CUJ_FILES=""
STALE_AD_FILES=""

# Check CUJs for staleness (only if directory exists and not opted out)
if [[ -d "docs/cujs" && ! -f "docs/cujs/.opted-out" ]]; then
    for cuj_file in docs/cujs/*.md; do
        [[ -f "$cuj_file" ]] || continue
        # Extract last-verified date from frontmatter
        verified_date=$(sed -n '/^---$/,/^---$/{ s/^last-verified:[[:space:]]*//p; }' "$cuj_file" | head -1)
        if [[ -n "$verified_date" && "$verified_date" != "YYYY-MM-DD" ]]; then
            verified_epoch=$(date -j -f "%Y-%m-%d" "$verified_date" "+%s" 2>/dev/null || echo "0")
            age=$((CURRENT_EPOCH - verified_epoch))
            if [[ $age -gt $STALENESS_THRESHOLD ]]; then
                cuj_name=$(basename "$cuj_file")
                STALE_CUJ_FILES="${STALE_CUJ_FILES}${cuj_file}|${verified_date}\n"
                WARNINGS="${WARNINGS}📋 CUJ docs/cujs/$cuj_name may be stale (last verified: $verified_date)\n"
            fi
        fi
    done

    # Check if changed files are mentioned in CUJ content
    # If the CUJ is stale AND code touches it → BLOCKING
    # If the CUJ is fresh AND code touches it → WARNING
    while IFS= read -r changed; do
        [[ -n "$changed" ]] || continue
        module=$(basename "$changed" | sed 's/\.[^.]*$//')
        match=$(grep -rl "$module" docs/cujs/*.md 2>/dev/null | head -1 || true)
        if [[ -n "$match" ]]; then
            cuj_name=$(basename "$match")
            # Check if this CUJ is in the stale list (pipe-delimited: filepath|date)
            stale_entry=$(printf "%b" "$STALE_CUJ_FILES" | grep "^${match}|" || true)
            if [[ -n "$stale_entry" ]]; then
                stale_date="${stale_entry##*|}"
                BLOCKING_ISSUES="${BLOCKING_ISSUES}📋 Changed file $changed affects STALE CUJ docs/cujs/$cuj_name (last verified: $stale_date)\n"
                BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Update and re-verify the CUJ before committing\n\n"
            else
                WARNINGS="${WARNINGS}📋 Changed file $changed may affect CUJ docs/cujs/$cuj_name — consider reviewing.\n"
            fi
        fi
    done <<< "$CHANGED_FILES"
fi

# Check ADs for staleness (only if directory exists and not opted out)
if [[ -d "docs/decisions" && ! -f "docs/decisions/.opted-out" ]]; then
    for ad_file in docs/decisions/*.md; do
        [[ -f "$ad_file" ]] || continue
        ad_date=$(sed -n '/^---$/,/^---$/{ s/^date:[[:space:]]*//p; }' "$ad_file" | head -1)
        if [[ -n "$ad_date" && "$ad_date" != "YYYY-MM-DD" ]]; then
            ad_epoch=$(date -j -f "%Y-%m-%d" "$ad_date" "+%s" 2>/dev/null || echo "0")
            age=$((CURRENT_EPOCH - ad_epoch))
            if [[ $age -gt $STALENESS_THRESHOLD ]]; then
                ad_name=$(basename "$ad_file")
                STALE_AD_FILES="${STALE_AD_FILES}${ad_file}|${ad_date}\n"
                WARNINGS="${WARNINGS}📐 AD docs/decisions/$ad_name may be stale (date: $ad_date)\n"
            fi
        fi
    done

    # Check if changed files are mentioned in AD content
    while IFS= read -r changed; do
        [[ -n "$changed" ]] || continue
        module=$(basename "$changed" | sed 's/\.[^.]*$//')
        match=$(grep -rl "$module" docs/decisions/*.md 2>/dev/null | head -1 || true)
        if [[ -n "$match" ]]; then
            ad_name=$(basename "$match")
            stale_entry=$(printf "%b" "$STALE_AD_FILES" | grep "^${match}|" || true)
            if [[ -n "$stale_entry" ]]; then
                stale_date="${stale_entry##*|}"
                BLOCKING_ISSUES="${BLOCKING_ISSUES}📐 Changed file $changed affects STALE AD docs/decisions/$ad_name (date: $stale_date)\n"
                BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Update and re-verify the AD before committing\n\n"
            else
                WARNINGS="${WARNINGS}📐 Changed file $changed may affect AD docs/decisions/$ad_name — consider reviewing.\n"
            fi
        fi
    done <<< "$CHANGED_FILES"
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
