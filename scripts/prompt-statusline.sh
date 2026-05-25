#!/usr/bin/env bash
#
# Prompt the user once for which statusline backend to install.
# Echoes the chosen value to stdout (rz1989s | tmck | none).
# Writes the prompt to /dev/tty so the caller can capture the answer via
# command substitution.
#
# Used by the Makefile `install` target so the question is asked once per
# `make install` invocation, not once per CLAUDE_TARGETS entry.
#
# Reuses the read -rp + default pattern from scripts/set-identity.sh.
#

set -euo pipefail

if [ ! -t 0 ] || [ ! -t 1 ]; then
    # Non-interactive shell — caller didn't pre-set STATUSLINE_CHOICE.
    # Fall back to the default without trying to read from a closed tty.
    echo "rz1989s"
    exit 0
fi

{
    echo ""
    echo "  📊 Statusline backend selection (first run)"
    echo "  ──────────────────────────────────────────"
    echo "    1) rz1989s/claude-code-statusline (default — themed multi-line, configurable via Config.toml)"
    echo "    2) tmck-code/yet-another-statusline (Python-based; requires Python >= 3.14)"
    echo "    3) none (no statusline)"
    echo ""
    echo "  Choose 1, 2, or 3 [default: 1]."
    echo "  You can change this later with: make set-statusline"
} > /dev/tty

read -rp "  > " choice < /dev/tty
choice="${choice:-1}"

case "$choice" in
    1|rz1989s) echo "rz1989s" ;;
    2|tmck)    echo "tmck" ;;
    3|none)    echo "none" ;;
    *)
        echo "  ⚠️  Unrecognized choice '$choice' — defaulting to rz1989s" > /dev/tty
        echo "rz1989s"
        ;;
esac
