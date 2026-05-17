#!/usr/bin/env bash
# =============================================================================
# PreToolUse Hook: Combined Bash gate
# =============================================================================
#
# Single-process replacement for the formerly separate
#   block-dangerous-commands.sh + pre-commit-gate.sh
# pair. Both scripts ran on every Bash invocation and each independently
# paid bash startup + cat-stdin + jq-parse. Merging into one hook saves
# ~30-80ms per Bash call.
#
# Behavior is preserved exactly:
#   Phase A — block dangerous Bash patterns (rm -rf /, force push to main,
#             curl|sh, dd to disk device, etc.).
#   Phase B — when the command is `git commit`, enforce the 5 quality gates
#             (code review, security review, tests, coverage, docs) plus
#             stale CUJ/AD detection.
#
# Phase A is skipped when the command is purely a `git commit` — its body
# is text being stored in a commit object, not code being executed. Real
# curl-pipe-bash etc. invocations OUTSIDE git commit are still scanned.
#
# Exit codes:
#   0 = Allow command
#   2 = Block command (stderr fed back to Claude)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Shared parse — done once for both phases.
# -----------------------------------------------------------------------------
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Is the command "primarily" a `git commit` (carve-out test for Phase A)?
PRIMARY_GIT_COMMIT=false
if echo "$COMMAND" | grep -qE '^[[:space:]]*(sudo[[:space:]]+)?git[[:space:]]+commit([[:space:]]|$)'; then
    PRIMARY_GIT_COMMIT=true
fi

# Does the command contain `git commit` anywhere (gate trigger for Phase B)?
IS_GIT_COMMIT=false
if echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
    IS_GIT_COMMIT=true
fi

# Autopilot bypass eligibility — set when CLAUDE_AUTOPILOT=1 and the command
# is a `git *` invocation other than `git commit`. Resolved AFTER Phase A so
# dangerous patterns (force push to protected branches, etc.) still block.
AUTOPILOT_GIT_ALLOW=false
if [[ "${CLAUDE_AUTOPILOT:-0}" == "1" ]] \
   && [[ "$IS_GIT_COMMIT" == "false" ]] \
   && echo "$COMMAND" | grep -qE '^[[:space:]]*git([[:space:]]|$)'; then
    AUTOPILOT_GIT_ALLOW=true
fi

# =============================================================================
# Phase A — dangerous-command scan
# =============================================================================
if [[ "$PRIMARY_GIT_COMMIT" == "false" ]]; then

    # rm -rf with dangerous paths
    if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|-rf|-fr)\s+(/|~|\.\.|\$HOME|\$\{HOME\})'; then
        echo "🛑 BLOCKED: Destructive rm command targeting root, home, or parent directory" >&2
        echo "Command: $COMMAND" >&2
        exit 2
    fi

    # rm -rf /* or rm -rf ~/*
    if echo "$COMMAND" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|-rf|-fr)\s+(/\*|~/\*|/home)'; then
        echo "🛑 BLOCKED: Destructive rm command with wildcard on sensitive path" >&2
        echo "Command: $COMMAND" >&2
        exit 2
    fi

    # Force push to main/master
    if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(-f|--force)\s+.*(main|master|production|release)'; then
        echo "🛑 BLOCKED: Force push to protected branch" >&2
        echo "Command: $COMMAND" >&2
        echo "Tip: Create a PR instead of force pushing to main/master" >&2
        exit 2
    fi

    # chmod 777 (world-writable)
    if echo "$COMMAND" | grep -qE 'chmod\s+(777|a\+rwx)'; then
        echo "⚠️ BLOCKED: Setting world-writable permissions (777)" >&2
        echo "Command: $COMMAND" >&2
        echo "Tip: Use 755 for directories, 644 for files" >&2
        exit 2
    fi

    # curl piped to shell — \b anchors the (ba)?sh end so we don't match shasum, shellcheck, etc.
    if echo "$COMMAND" | grep -qE 'curl\s+.*\|\s*(ba)?sh\b'; then
        echo "⚠️ BLOCKED: Piping curl output directly to shell" >&2
        echo "Command: $COMMAND" >&2
        echo "Tip: Download script first, review it, then execute" >&2
        exit 2
    fi

    # wget piped to shell
    if echo "$COMMAND" | grep -qE 'wget\s+.*\|\s*(ba)?sh\b'; then
        echo "⚠️ BLOCKED: Piping wget output directly to shell" >&2
        echo "Command: $COMMAND" >&2
        exit 2
    fi

    # dd writing to disk devices
    if echo "$COMMAND" | grep -qE 'dd\s+.*of=/dev/(sd|hd|nvme|disk)'; then
        echo "🛑 BLOCKED: dd command writing directly to disk device" >&2
        echo "Command: $COMMAND" >&2
        exit 2
    fi

    # mkfs (format disk)
    if echo "$COMMAND" | grep -qE 'mkfs'; then
        echo "🛑 BLOCKED: mkfs command (disk formatting)" >&2
        echo "Command: $COMMAND" >&2
        exit 2
    fi

    # Commands that could exfiltrate data
    if echo "$COMMAND" | grep -qE '(curl|wget|nc|netcat)\s+.*\.(env|pem|key|secret)'; then
        echo "⚠️ BLOCKED: Command appears to exfiltrate sensitive files" >&2
        echo "Command: $COMMAND" >&2
        exit 2
    fi

    # Reading .env files via cat/less/head/tail
    if echo "$COMMAND" | grep -qE '(cat|less|head|tail|more|bat)\s+.*\.env'; then
        echo "⚠️ BLOCKED: Reading .env file via $COMMAND" >&2
        echo "Tip: Use environment variables instead of reading .env directly" >&2
        exit 2
    fi
fi

# Autopilot bypass — emit explicit allow decision for safe `git *` commands
# (Phase A's dangerous patterns above already vetoed force-push-to-main, etc.).
# `git commit` deliberately falls through to Phase B so the 5-gate still runs.
if [[ "$AUTOPILOT_GIT_ALLOW" == "true" ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
fi

# =============================================================================
# Phase B — pre-commit quality gate
# =============================================================================
if [[ "$IS_GIT_COMMIT" == "false" ]]; then
    exit 0
fi

# Don't gate --amend (rewriting an already-gated commit).
if echo "$COMMAND" | grep -qE '\-\-amend'; then
    exit 0
fi

# --allow-empty only bypasses when the commit is genuinely empty.
if echo "$COMMAND" | grep -qE '\-\-allow-empty'; then
    STAGED_LINES=$(git diff --cached --numstat 2>/dev/null | awk '{s+=$1+$2} END {print s+0}')
    if [[ "$STAGED_LINES" -eq 0 ]]; then
        exit 0
    fi
fi

# Bail early if not inside a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MARKER_DIR="$HOME/.claude/review-markers"
MARKER_TTL=600  # 10 minutes in seconds

SECURITY_PATTERNS='(auth|login|session|token|password|credential|crypto|encrypt|decrypt|hash|permission|role|access|middleware|security|cors|csrf|sanitiz|validat|secret|oauth|jwt|cookie|firewall)'
USER_FACING_PATTERNS='\.(tsx?|jsx?|vue|svelte|html)$|route|endpoint|controller|handler|/pages/|/views/|/components/'
DOC_PATTERNS='(readme|changelog|doc/|docs/|\.md$)'

# ---------------------------------------------------------------------------
# Determine what's being committed
# ---------------------------------------------------------------------------
if echo "$COMMAND" | grep -qE ' -[a-zA-Z]*a| --all'; then
    DIFF_REF="HEAD"
else
    DIFF_REF="--cached"
fi

LINES_CHANGED=$(git diff "$DIFF_REF" --numstat 2>/dev/null | awk '{s+=$1+$2} END {print s+0}')

if [[ "$LINES_CHANGED" -eq 0 ]]; then
    exit 0
fi

CHANGED_FILES=$(git diff "$DIFF_REF" --name-only 2>/dev/null || true)
SECURITY_FILES=$(echo "$CHANGED_FILES" | grep -iE "$SECURITY_PATTERNS" || true)
USER_FACING=$(echo "$CHANGED_FILES" | grep -iE "$USER_FACING_PATTERNS" || true)
DOC_CHANGES=$(echo "$CHANGED_FILES" | grep -iE "$DOC_PATTERNS" || true)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
parse_date_to_epoch() {
    local date_str="$1"
    if date -j -f "%Y-%m-%d" "$date_str" "+%s" 2>/dev/null; then
        return
    fi
    date -d "$date_str" "+%s" 2>/dev/null || echo "0"
}

# Plain-timestamp marker freshness check. Do NOT use for coverage-checked
# (which has format TIMESTAMP:PERCENTAGE — parsed inline in Gate 4).
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
        rm -f "$marker_file" 2>/dev/null || true
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Evaluate gates
# ---------------------------------------------------------------------------
BLOCKING_ISSUES=""
WARNINGS=""

# Trivial-change carve-out: when ≤20 lines change AND no file is security-
# sensitive AND no file is user-facing, the commit gets a pass on Gate 3
# (tests-passed) and Gate 4 (coverage-checked). This mirrors the existing
# Gate 1 threshold: small, low-risk changes (typo fixes, comment tweaks,
# config nudges) shouldn't require running the full test+coverage harness.
# Gates 1, 2, 5 already self-gate on their triggers and remain active.
TRIVIAL_CHANGE=false
if [[ "$LINES_CHANGED" -le 20 && -z "$SECURITY_FILES" && -z "$USER_FACING" ]]; then
    TRIVIAL_CHANGE=true
fi

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

# Gate 3: Tests must pass (skipped for trivial changes)
if [[ "$TRIVIAL_CHANGE" == "false" ]] && ! marker_is_fresh "$MARKER_DIR/tests-passed"; then
    BLOCKING_ISSUES="${BLOCKING_ISSUES}🧪 Tests must pass before commit\n"
    BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Run tests for your project, then: ~/.claude/hooks/mark-reviewed.sh --tests\n"
    BLOCKING_ISSUES="${BLOCKING_ISSUES}   → Or run the code-reviewer agent (it sets this marker automatically)\n\n"
fi

# Gate 4: Coverage must meet threshold (80%) (skipped for trivial changes)
if [[ "$TRIVIAL_CHANGE" == "false" ]]; then
    COVERAGE_MARKER="$MARKER_DIR/coverage-checked"
    if [[ -f "$COVERAGE_MARKER" ]]; then
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
STALENESS_THRESHOLD=$((90 * 86400))
CURRENT_EPOCH=$(date +%s)

STALE_CUJ_FILES=""
STALE_AD_FILES=""

if [[ -d "docs/cujs" && ! -f "docs/cujs/.opted-out" ]]; then
    for cuj_file in docs/cujs/*.md; do
        [[ -f "$cuj_file" ]] || continue
        verified_date=$(sed -n '/^---$/,/^---$/{ s/^last-verified:[[:space:]]*//p; }' "$cuj_file" | head -1)
        if [[ -n "$verified_date" && "$verified_date" != "YYYY-MM-DD" ]]; then
            verified_epoch=$(parse_date_to_epoch "$verified_date")
            age=$((CURRENT_EPOCH - verified_epoch))
            if [[ $age -gt $STALENESS_THRESHOLD ]]; then
                cuj_name=$(basename "$cuj_file")
                STALE_CUJ_FILES="${STALE_CUJ_FILES}${cuj_file}|${verified_date}\n"
                WARNINGS="${WARNINGS}📋 CUJ docs/cujs/$cuj_name may be stale (last verified: $verified_date)\n"
            fi
        fi
    done

    while IFS= read -r changed; do
        [[ -n "$changed" ]] || continue
        module=$(basename "$changed" | sed 's/\.[^.]*$//')
        [[ ${#module} -lt 4 ]] && continue
        match=$(grep -rwl "$module" docs/cujs/*.md 2>/dev/null | head -1 || true)
        if [[ -n "$match" ]]; then
            cuj_name=$(basename "$match")
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

if [[ -d "docs/decisions" && ! -f "docs/decisions/.opted-out" ]]; then
    for ad_file in docs/decisions/*.md; do
        [[ -f "$ad_file" ]] || continue
        ad_date=$(sed -n '/^---$/,/^---$/{ s/^date:[[:space:]]*//p; }' "$ad_file" | head -1)
        if [[ -n "$ad_date" && "$ad_date" != "YYYY-MM-DD" ]]; then
            ad_epoch=$(parse_date_to_epoch "$ad_date")
            age=$((CURRENT_EPOCH - ad_epoch))
            if [[ $age -gt $STALENESS_THRESHOLD ]]; then
                ad_name=$(basename "$ad_file")
                STALE_AD_FILES="${STALE_AD_FILES}${ad_file}|${ad_date}\n"
                WARNINGS="${WARNINGS}📐 AD docs/decisions/$ad_name may be stale (date: $ad_date)\n"
            fi
        fi
    done

    while IFS= read -r changed; do
        [[ -n "$changed" ]] || continue
        module=$(basename "$changed" | sed 's/\.[^.]*$//')
        [[ ${#module} -lt 4 ]] && continue
        match=$(grep -rwl "$module" docs/decisions/*.md 2>/dev/null | head -1 || true)
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
if [[ -n "$WARNINGS" ]]; then
    echo "" >&2
    printf "%b" "$WARNINGS" >&2
fi

if [[ -n "$BLOCKING_ISSUES" ]]; then
    echo "🚧 Pre-commit quality gate — review required before committing:" >&2
    echo "" >&2
    printf "%b" "$BLOCKING_ISSUES" >&2
    exit 2
fi

exit 0
