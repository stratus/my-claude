#!/usr/bin/env bash
# =============================================================================
# PostToolUse Hook: After File Edit
# =============================================================================
#
# This hook runs AFTER Claude edits or writes a file.
# Use it for fast operations like formatting that should run immediately.
#
# For heavier checks (tests, full linting), run them explicitly or wire a
# Stop hook (an archived example lives in templates/hooks/end-of-turn.sh.disabled).
#
# Usage:
#   Add to ~/.claude/settings.json:
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "matcher": "Edit|Write",
#           "hooks": [
#             {
#               "type": "command",
#               "command": "~/.claude/hooks/after-edit.sh"
#             }
#           ]
#         }
#       ]
#     }
#   }
# =============================================================================

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract the file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0  # No file path, nothing to do
fi

# Get file extension
EXTENSION="${FILE_PATH##*.}"

# -----------------------------------------------------------------------------
# Format based on file type
# -----------------------------------------------------------------------------

# Run formatters in background so PostToolUse returns immediately and the
# agent loop is not blocked. Format-on-save is a "nice to have"; the commit
# gate enforces formatting at commit time anyway.
#
# Each formatter is wrapped in a 5-second guard so a wedged or pathologically
# slow formatter (e.g. prettier on a 50MB JSON) cannot orphan the subprocess.
# Uses GNU `timeout` if available (coreutils via Homebrew on macOS), or
# `gtimeout`, otherwise falls back to no guard.
if   command -v timeout  &>/dev/null; then GUARD=(timeout 5)
elif command -v gtimeout &>/dev/null; then GUARD=(gtimeout 5)
else GUARD=()  # no guard available; formatter runs unconstrained
fi

(
    case "$EXTENSION" in
        js|jsx|ts|tsx|json|md|yaml|yml|css|scss|html)
            command -v prettier &>/dev/null && "${GUARD[@]+"${GUARD[@]}"}" prettier --write "$FILE_PATH" 2>/dev/null || true
            ;;
        py)
            command -v black &>/dev/null && "${GUARD[@]+"${GUARD[@]}"}" black --quiet "$FILE_PATH" 2>/dev/null || true
            command -v ruff  &>/dev/null && "${GUARD[@]+"${GUARD[@]}"}" ruff check --fix --silent "$FILE_PATH" 2>/dev/null || true
            ;;
        go)
            command -v gofmt &>/dev/null && "${GUARD[@]+"${GUARD[@]}"}" gofmt -w "$FILE_PATH" 2>/dev/null || true
            ;;
        rs)
            command -v rustfmt &>/dev/null && "${GUARD[@]+"${GUARD[@]}"}" rustfmt "$FILE_PATH" 2>/dev/null || true
            ;;
        sh|bash)
            command -v shfmt &>/dev/null && "${GUARD[@]+"${GUARD[@]}"}" shfmt -w "$FILE_PATH" 2>/dev/null || true
            ;;
    esac
) </dev/null >/dev/null 2>&1 &
disown $! 2>/dev/null || true

exit 0
