#!/usr/bin/env bash
# =============================================================================
# SessionStart Hook: Prune Stale Review Markers
# =============================================================================
#
# Review markers (~/.claude/review-markers/*) are set by review agents and
# checked by pretooluse-bash.sh Phase B at commit time. They expire after
# 10 minutes — but markers from a *prior* session can linger and confuse the
# user mid-new-session ("why is it complaining about a marker I never set?").
#
# This hook runs on session startup and deletes any marker file older than
# 1 hour. The 10-minute commit-time TTL still applies on top; this is purely
# a hygiene sweep that prevents user confusion when sessions are short.
#
# Matcher: "startup" (session begin); not on resume/clear/compact, since
# those carry the same logical session forward.
#
# Exit code: always 0. Hygiene failures must never block a session.
# =============================================================================

set -euo pipefail

MARKER_DIR="$HOME/.claude/review-markers"
PRUNE_AGE_MIN=60  # minutes

# Bail silently if the marker dir doesn't exist yet (first-ever session).
[[ -d "$MARKER_DIR" ]] || exit 0

# find -mmin handles "older than N minutes" cleanly on both macOS and Linux.
find "$MARKER_DIR" -maxdepth 1 -type f -mmin "+$PRUNE_AGE_MIN" -delete 2>/dev/null || true

exit 0
