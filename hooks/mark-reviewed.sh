#!/usr/bin/env bash
# =============================================================================
# Mark Review Complete
# =============================================================================
#
# Sets a time-based marker indicating that a review has been completed.
# Used by pre-commit-gate.sh to allow commits past the quality gate.
#
# Usage:
#   ~/.claude/hooks/mark-reviewed.sh              # Mark code review done
#   ~/.claude/hooks/mark-reviewed.sh --security    # Mark security review done
#   ~/.claude/hooks/mark-reviewed.sh --both        # Mark code + security done
#   ~/.claude/hooks/mark-reviewed.sh --tests       # Mark tests passed
#   ~/.claude/hooks/mark-reviewed.sh --docs        # Mark docs reviewed
#   ~/.claude/hooks/mark-reviewed.sh --coverage N  # Mark coverage at N%
#   ~/.claude/hooks/mark-reviewed.sh --all         # Mark all gates done
#
# Marker formats:
#   Most markers: plain UNIX timestamp
#   coverage-checked: TIMESTAMP:PERCENTAGE (colon-separated)
#
# Markers expire after 10 minutes (configured in pre-commit-gate.sh).
# =============================================================================

set -euo pipefail

MARKER_DIR="$HOME/.claude/review-markers"
mkdir -p "$MARKER_DIR"

TIMESTAMP=$(date +%s)

case "${1:-}" in
    ""|--code)
        echo "$TIMESTAMP" > "$MARKER_DIR/code-reviewed"
        echo "Code review marker set (expires in 10 minutes)"
        ;;
    --security)
        echo "$TIMESTAMP" > "$MARKER_DIR/security-reviewed"
        echo "Security review marker set (expires in 10 minutes)"
        ;;
    --both)
        echo "$TIMESTAMP" > "$MARKER_DIR/code-reviewed"
        echo "$TIMESTAMP" > "$MARKER_DIR/security-reviewed"
        echo "Code review and security review markers set (expire in 10 minutes)"
        ;;
    --tests)
        echo "$TIMESTAMP" > "$MARKER_DIR/tests-passed"
        echo "Tests-passed marker set (expires in 10 minutes)"
        ;;
    --docs)
        echo "$TIMESTAMP" > "$MARKER_DIR/docs-reviewed"
        echo "Docs review marker set (expires in 10 minutes)"
        ;;
    --coverage)
        if [[ -z "${2:-}" || ! "${2:-}" =~ ^[0-9]+$ ]]; then
            echo "Error: --coverage requires an integer percentage argument" >&2
            echo "Usage: mark-reviewed.sh --coverage <percentage>" >&2
            exit 1
        fi
        echo "${TIMESTAMP}:${2}" > "$MARKER_DIR/coverage-checked"
        echo "Coverage marker set at ${2}% (expires in 10 minutes)"
        ;;
    --all)
        echo "$TIMESTAMP" > "$MARKER_DIR/code-reviewed"
        echo "$TIMESTAMP" > "$MARKER_DIR/security-reviewed"
        echo "$TIMESTAMP" > "$MARKER_DIR/tests-passed"
        echo "$TIMESTAMP" > "$MARKER_DIR/docs-reviewed"
        echo "${TIMESTAMP}:80" > "$MARKER_DIR/coverage-checked"
        echo "All review markers set (expire in 10 minutes)"
        ;;
    *)
        echo "Unknown argument: ${1}" >&2
        echo "Usage: mark-reviewed.sh [--code|--security|--both|--tests|--docs|--coverage <pct>|--all]" >&2
        exit 1
        ;;
esac
