#!/usr/bin/env bash
#
# Remove the persisted statusline choice and restore the default (rz1989s).
# Optionally clean the extracted tmck source tree under $CLAUDE_DIR/external/.
#
# Usage:
#   CLAUDE_DIR=~/.claude ./scripts/unset-statusline.sh
#
# Symmetry with `make unset-identity`: this script deletes the choice marker
# but leaves the on-disk artifact (extracted tarball under external/) alone by
# default — the user is prompted, default N. The directory is small and
# re-selecting tmck later is a no-op if the pinned tree is still there.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

marker="$CLAUDE_DIR/statusline-choice"
external_dir="$CLAUDE_DIR/external"

if [ -f "$marker" ]; then
    current="$(cat "$marker")"
    rm -f "$marker"
    echo "🗑️  Removed statusline choice marker (was: $current)"
else
    echo "⏭️  No statusline-choice marker at $marker — nothing to remove."
fi

# Offer to clean the extracted tmck source tree (small, but symmetry with
# unset-identity which also offers cleanup).
if [ -d "$external_dir" ] && [ -n "$(find "$external_dir" -maxdepth 1 -name 'yet-another-statusline-*' -print -quit)" ]; then
    if [ -t 0 ]; then
        read -rp "Also remove extracted tmck source under $external_dir/yet-another-statusline-*? [y/N] " confirm
        confirm="${confirm:-N}"
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            find "$external_dir" -maxdepth 1 -name 'yet-another-statusline-*' -exec rm -rf {} +
            # Drop the external/ dir if now empty
            rmdir "$external_dir" 2>/dev/null || true
            echo "🗑️  Removed extracted tmck source tree."
        else
            echo "⏭️  Leaving extracted tmck source in place."
        fi
    else
        echo "⏭️  Non-interactive run — leaving extracted tmck source in place."
    fi
fi

# Re-run install.sh so settings.json is rewritten to the default rz1989s wiring.
# We intentionally do NOT set STATUSLINE_CHOICE_PERSIST here — the marker was
# just deleted, so install.sh's "marker doesn't exist" branch will write the
# new default, which is what we want.
echo "🔄 Re-running install.sh to restore default (rz1989s)..."
FORCE_UPDATE=1 STATUSLINE_CHOICE="rz1989s" CLAUDE_DIR="$CLAUDE_DIR" \
    "$REPO_ROOT/install.sh"
