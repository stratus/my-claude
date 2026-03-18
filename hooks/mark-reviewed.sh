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
#   ~/.claude/hooks/mark-reviewed.sh --both        # Mark both done
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
    *)
        echo "Unknown argument: ${1}" >&2
        echo "Usage: mark-reviewed.sh [--code|--security|--both]" >&2
        exit 1
        ;;
esac
