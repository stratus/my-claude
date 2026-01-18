#!/bin/bash
#
# Claude Code status line wrapper
# Tries ccstatusline first, falls back to simple script
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read JSON from stdin into variable (needed for both paths)
input=$(cat)

# Try ccstatusline if bun is available and config exists
if command -v bun &>/dev/null && [ -f "$HOME/.config/ccstatusline/settings.json" ]; then
    echo "$input" | bun x ccstatusline@latest 2>/dev/null
    if [ $? -eq 0 ]; then
        exit 0
    fi
fi

# Fallback to simple script
echo "$input" | "$SCRIPT_DIR/statusline-simple.sh"
