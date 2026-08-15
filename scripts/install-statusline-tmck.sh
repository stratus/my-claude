#!/usr/bin/env bash
#
# Install tmck-code/yet-another-statusline as a Claude Code statusline backend.
#
# Pinned to a reviewed commit and verified by SHA-256. The pinned tarball is
# fetched from codeload.github.com (deterministic from a commit SHA), extracted
# under $CLAUDE_DIR/external/yet-another-statusline-<short-sha>/, and the two
# runtime files are symlinked into $CLAUDE_DIR/ where Claude Code expects them.
#
# Behaviour mirrors the rz1989s/claude-code-statusline block in install.sh:
#   - Primary target ($CLAUDE_DIR == ~/.claude): fetch + verify + extract + symlink
#   - Non-default target: symlink from the primary install (one source of truth)
#   - Missing primary on a non-default target: error with actionable message
#
# Preflight: Python >= 3.14 is required (upstream uses 3.14 syntax). The
# fallback contract is enforced by the caller (install.sh) — this script only
# decides go/no-go and reports failure. The caller decides whether to hard-fail
# or fall back to rz1989s based on whether STATUSLINE_CHOICE was explicit.
#
# Usage:
#   CLAUDE_DIR=/path/to/target ./scripts/install-statusline-tmck.sh
#
# Exit codes:
#   0  installed (or already installed at the pinned commit)
#   2  Python preflight failed (caller decides fallback vs hard-fail)
#   1  any other failure (network, checksum, extraction)
#
# To bump the pin:
#   1. SHA=$(curl -sSfL https://api.github.com/repos/tmck-code/yet-another-statusline/commits/main | \
#         python3 -c "import json,sys; print(json.load(sys.stdin)['sha'])")
#   2. curl -sSfL "https://codeload.github.com/tmck-code/yet-another-statusline/tar.gz/$SHA" -o /tmp/tmck.tgz
#   3. shasum -a 256 /tmp/tmck.tgz   # paste both values below
#

set -euo pipefail

TMCK_COMMIT="401ae073cbaa7628450a207efb8128147372523a"
TMCK_SHA256="cf466c0b9d330731c362abf7b3da26cbc1922cb3866e2780ff2a6431a8fb97b1"
TMCK_TARBALL_URL="https://codeload.github.com/tmck-code/yet-another-statusline/tar.gz/${TMCK_COMMIT}"

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SHORT_SHA="${TMCK_COMMIT:0:7}"

# Defense against pathological CLAUDE_DIR values (e.g. `/`) that would make
# the `rm -rf "$EXTERNAL_DIR"` step below touch system paths. We require an
# absolute path with at least one component below root.
if [[ "$CLAUDE_DIR" != /* ]] || [ "$CLAUDE_DIR" = "/" ]; then
    echo "  ❌ tmck statusline: refusing to install with CLAUDE_DIR='$CLAUDE_DIR'" >&2
    echo "     Expected an absolute path below '/' (e.g. ~/.claude)." >&2
    exit 1
fi

EXTERNAL_DIR="$CLAUDE_DIR/external/yet-another-statusline-${SHORT_SHA}"

# PRIMARY_DIR identifies the "source of truth" install for non-default targets
# to symlink against. Defaults to ~/.claude; override only for verify-loop
# testing against throwaway $TMPDIR roots when invoking this script directly.
# Note: PRIMARY_DIR is NOT propagated through `make` recipes — Makefile-driven
# tests should override $HOME instead (e.g. HOME=$TMPDIR/test-home make install).
PRIMARY_DIR="${PRIMARY_DIR:-$HOME/.claude}"
PRIMARY_ENTRYPOINT="$PRIMARY_DIR/statusline_command.py"
PRIMARY_THEMES="$PRIMARY_DIR/statusline/themes.py"

# ---------------------------------------------------------------------------
# Preflight: Python >= 3.14 (stdlib-only; no venv or pip needed)
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
    echo "  ❌ tmck statusline preflight: python3 not found" >&2
    echo "     Install Python 3.14+ (e.g. via pyenv, uv, or homebrew)" >&2
    exit 2
fi
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,14) else 1)' 2>/dev/null; then
    actual="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
    echo "  ❌ tmck statusline preflight: Python $actual found, need >= 3.14" >&2
    echo "     Install Python 3.14+ (e.g. via pyenv, uv, or homebrew), then re-run." >&2
    echo "     Or pick the rz1989s backend instead: STATUSLINE_CHOICE=rz1989s make install" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Idempotency: if BOTH symlinks already point at the pinned commit's tree AND
# their targets actually resolve to existing files, skip. The `-e` test follows
# symlinks, so a dangling link (e.g. after $CLAUDE_DIR/external/ was wiped by
# `unset-statusline`'s cleanup) correctly falls through to re-extract instead
# of self-perpetuating a broken install.
# ---------------------------------------------------------------------------
entrypoint_link="$CLAUDE_DIR/statusline_command.py"
themes_link="$CLAUDE_DIR/statusline/themes.py"
if [ -L "$entrypoint_link" ] && [ -L "$themes_link" ] && \
   [ -e "$entrypoint_link" ] && [ -e "$themes_link" ]; then
    ep_target="$(readlink "$entrypoint_link")"
    th_target="$(readlink "$themes_link")"
    case "$ep_target:$th_target" in
        *"yet-another-statusline-${SHORT_SHA}"*:*"yet-another-statusline-${SHORT_SHA}"*)
            echo "  ⏭️  tmck statusline already installed at ${SHORT_SHA}"
            exit 0
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# Non-default target: symlink from primary install rather than re-extracting.
# Matches the rz1989s pattern (one source of truth per pinned commit).
# ---------------------------------------------------------------------------
if [ "$CLAUDE_DIR" != "$PRIMARY_DIR" ]; then
    if [ ! -f "$PRIMARY_ENTRYPOINT" ] || [ ! -f "$PRIMARY_THEMES" ]; then
        echo "  ⚠️  tmck statusline: primary install not found at $PRIMARY_DIR" >&2
        echo "     Install to ~/.claude first, then re-run for this target." >&2
        exit 1
    fi
    echo "  📊 Linking tmck statusline from primary install (${SHORT_SHA})..."
    mkdir -p "$CLAUDE_DIR/statusline"
    # ln -sf unlinks any pre-existing symlink at the destination rather than
    # following it (verified on macOS/BSD and Linux/GNU). Do NOT change these
    # to `cp -f`, which would follow a pre-existing symlink and clobber its
    # target (potentially a system path).
    ln -sf "$PRIMARY_ENTRYPOINT" "$entrypoint_link"
    ln -sf "$PRIMARY_THEMES" "$themes_link"
    exit 0
fi

# ---------------------------------------------------------------------------
# Primary target: fetch tarball, verify SHA-256, extract, symlink.
# ---------------------------------------------------------------------------
echo "  📊 Installing tmck-code/yet-another-statusline (pinned ${SHORT_SHA})..."

mkdir -p "$CLAUDE_DIR/external" "$CLAUDE_DIR/statusline"

# Stage everything in temp paths, then promote with atomic mv/ln only after
# all sub-steps succeed. Closes the partial-install window between extract
# steps and symlink updates.
tarball_tmp="$(mktemp "${TMPDIR:-/tmp}/tmck-statusline.XXXXXX")"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/tmck-staging.XXXXXX")"
trap 'rm -rf "$tarball_tmp" "$staging_dir"' EXIT

curl -sSfL "$TMCK_TARBALL_URL" -o "$tarball_tmp"

actual_sha="$(shasum -a 256 "$tarball_tmp" | cut -d' ' -f1)"
if [ "$actual_sha" != "$TMCK_SHA256" ]; then
    echo "  ❌ tmck statusline tarball checksum mismatch — refusing to install" >&2
    echo "     expected: $TMCK_SHA256" >&2
    echo "     actual:   $actual_sha" >&2
    exit 1
fi

# Extract the two runtime files into the staging directory. The two paths
# have different prefix depths inside the tarball so they need separate
# --strip-components values; one tar call cannot cover both.
mkdir -p "$staging_dir/statusline"
tar -xzf "$tarball_tmp" \
    --strip-components=2 \
    -C "$staging_dir" \
    "yet-another-statusline-${TMCK_COMMIT}/claude/statusline_command.py"
tar -xzf "$tarball_tmp" \
    --strip-components=3 \
    -C "$staging_dir/statusline" \
    "yet-another-statusline-${TMCK_COMMIT}/claude/statusline/themes.py"

# Verify both files are present before promoting — a partial extraction is
# never written to the final EXTERNAL_DIR.
if [ ! -f "$staging_dir/statusline_command.py" ] || \
   [ ! -f "$staging_dir/statusline/themes.py" ]; then
    echo "  ❌ tmck staging extraction incomplete; aborting" >&2
    exit 1
fi

# Promote: remove any prior install at this SHA, move staging into place.
# Directory mv on the same filesystem is atomic; the symlink updates that
# follow are also atomic per ln -sf. The combined sequence means the user
# never sees a state where statusline_command.py points at the new SHA but
# themes.py points at the old one (or vice versa).
rm -rf "$EXTERNAL_DIR"
mv "$staging_dir" "$EXTERNAL_DIR"

# Symlink the runtime files into the locations Claude Code expects.
# statusline_command.py loads themes.py via importlib from "./statusline/themes.py"
# relative to its own dir, so this directory layout matches upstream.
# ln -sf unlinks any pre-existing symlink at the destination rather than
# following it (verified on macOS/BSD and Linux/GNU). Do NOT change these
# to `cp -f`, which would follow a pre-existing symlink and clobber its
# target (potentially a system path).
ln -sf "$EXTERNAL_DIR/statusline_command.py" "$entrypoint_link"
ln -sf "$EXTERNAL_DIR/statusline/themes.py" "$themes_link"

# Clear trap (mirrors the rz1989s block in install.sh:182) — staging_dir was
# already consumed by mv, so the trap rm -rf would be a no-op, but explicitly
# clearing matches the project style.
trap - EXIT
rm -f "$tarball_tmp"

echo "  ✅ tmck statusline installed: $EXTERNAL_DIR -> $entrypoint_link"
