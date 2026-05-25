#!/usr/bin/env bash
#
# Persist a statusline choice for the given CLAUDE_DIR and re-run install.sh
# so the new choice is wired into settings.json and the appropriate backend
# is installed.
#
# Usage:
#   CLAUDE_DIR=~/.claude ./scripts/set-statusline.sh           (interactive)
#   CLAUDE_DIR=~/.claude ./scripts/set-statusline.sh tmck      (non-interactive)
#
# Valid values: rz1989s | tmck | none
#
# This script writes $CLAUDE_DIR/statusline-choice and then invokes install.sh
# with FORCE_UPDATE=1 and STATUSLINE_CHOICE=<value> so the marker is the
# authoritative source.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

choice="${1:-}"

if [ -z "$choice" ]; then
    choice="$("$SCRIPT_DIR/prompt-statusline.sh")"
fi

case "$choice" in
    rz1989s|tmck|none) ;;
    *)
        echo "❌ Invalid statusline choice: '$choice' (valid: rz1989s, tmck, none)" >&2
        exit 1
        ;;
esac

mkdir -p "$CLAUDE_DIR"
printf '%s\n' "$choice" > "$CLAUDE_DIR/statusline-choice"
echo "📌 Recorded statusline choice: $choice ($CLAUDE_DIR/statusline-choice)"

# Re-run install.sh with FORCE_UPDATE so settings.json is rewritten and the
# new backend is installed.
echo "🔄 Re-running install.sh to apply..."
FORCE_UPDATE=1 STATUSLINE_CHOICE="$choice" CLAUDE_DIR="$CLAUDE_DIR" \
    "$REPO_ROOT/install.sh"
