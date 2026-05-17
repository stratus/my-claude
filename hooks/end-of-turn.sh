#!/usr/bin/env bash
# =============================================================================
# end-of-turn.sh — MOVED
# =============================================================================
#
# The full implementation has been archived to:
#   templates/hooks/end-of-turn.sh.disabled
#
# It was unwired in commit 916a30e ("Cut per-turn hook and statusline latency")
# because re-running tsc / cargo check / clippy / ruff with 30s timeouts after
# every assistant turn dominated "writes feel slow." The same checks already
# gate at commit time via pretooluse-bash.sh (Phase B), so the post-turn
# fan-out was redundant.
#
# To re-enable: copy the archived script back to this path, then add a `Stop`
# hook entry pointing at it in config/settings.json. (See the header inside
# the archived file for the exact JSON snippet.)
#
# This stub exists only because install.sh deploys every file in hooks/. It is
# never wired up. If you see it in ~/.claude/hooks/, deletion is safe.
# =============================================================================

exit 0
