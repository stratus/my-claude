#!/usr/bin/env bash
#
# Install my-claude configuration to ~/.claude/
#
# Usage: ./install.sh
#        CLAUDE_DIR=~/.claude-corp ./install.sh   (install to alternate dir)
#        FORCE_UPDATE=1 ./install.sh               (skip prompts, overwrite all)
#
# This script deploys Claude Code configuration files to the user's
# home directory. New files are copied in; existing files are compared
# by SHA-256 checksum. On mismatch, the user is shown a diff and
# prompted to overwrite or keep the local version.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CONFIG_SOURCE="$SCRIPT_DIR/config"

# Tildified form of $CLAUDE_DIR used by the settings.json sed rewrite and the
# new statusLine Python splicer. Computed once here so both code paths share
# the value and the path-rewrite logic stays consistent.
if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
    CLAUDE_DIR_TILDE="~/.claude"
else
    CLAUDE_DIR_TILDE="${CLAUDE_DIR/#$HOME/\~}"
fi

# ---------------------------------------------------------------------------
# Resolve statusline backend choice: env var > per-target marker > primary
# marker > default rz1989s. install.sh does NOT prompt — that responsibility
# lives in the Makefile `install` target so multi-target runs ask once, not
# once per target.
#
# Two booleans:
#   STATUSLINE_CHOICE_EXPLICIT: the user named the choice on THIS run (env
#     var or persisted marker — anything not the default). Controls whether
#     preflight failure for tmck is hard-fail or silent fallback.
#   STATUSLINE_CHOICE_PERSIST: caller explicitly wants the marker rewritten
#     this run. Set by set-statusline.sh, NOT by a bare env var. Prevents a
#     stray STATUSLINE_CHOICE=tmck in .zshrc from laundering itself into
#     the persisted marker on every install.
# ---------------------------------------------------------------------------
# STATUSLINE_CHOICE_EXPLICIT: 1 only when the choice came from an env var on
#   THIS run (signals "user is actively asking for this right now"). Drives
#   the preflight-fallback contract: explicit-env tmck hard-fails on bad
#   Python; marker-derived tmck falls back to rz1989s for this run only.
# STATUSLINE_CHOICE_PERSIST: 1 only when the caller (set-statusline.sh)
#   asked us to rewrite the marker. NOT set by a bare env var, so a stray
#   STATUSLINE_CHOICE=tmck in .zshrc does not silently rewrite the marker.
STATUSLINE_CHOICE_EXPLICIT=0
STATUSLINE_CHOICE_PERSIST="${STATUSLINE_CHOICE_PERSIST:-0}"
if [ -n "${STATUSLINE_CHOICE:-}" ]; then
    STATUSLINE_CHOICE_EXPLICIT=1
elif [ -f "$CLAUDE_DIR/statusline-choice" ]; then
    STATUSLINE_CHOICE="$(cat "$CLAUDE_DIR/statusline-choice")"
elif [ -f "$HOME/.claude/statusline-choice" ]; then
    STATUSLINE_CHOICE="$(cat "$HOME/.claude/statusline-choice")"
else
    STATUSLINE_CHOICE="rz1989s"
fi
case "$STATUSLINE_CHOICE" in
    rz1989s|tmck|none) ;;
    *)
        echo "  ⚠️  Unknown STATUSLINE_CHOICE='$STATUSLINE_CHOICE' — falling back to rz1989s"
        STATUSLINE_CHOICE="rz1989s"
        STATUSLINE_CHOICE_EXPLICIT=0
        STATUSLINE_CHOICE_PERSIST=0
        ;;
esac

echo "🤖 Installing my-claude configuration..."
echo "   statusline: $STATUSLINE_CHOICE"
echo ""

# Create .claude directory structure
mkdir -p "$CLAUDE_DIR"/{agents,config,plans,hooks,commands,rules}

# Copy if missing or diverged — prompts user on content mismatch
copy_if_missing() {
    local src="$1"
    local dest="$2"
    local name="$(basename "$src")"

    if [ ! -f "$dest" ]; then
        echo "  📄 Copying $name"
        cp "$src" "$dest"
        return
    fi

    # File exists — compare checksums
    local src_hash dest_hash
    src_hash="$(shasum -a 256 "$src" | cut -d' ' -f1)"
    dest_hash="$(shasum -a 256 "$dest" | cut -d' ' -f1)"

    if [ "$src_hash" = "$dest_hash" ]; then
        echo "  ✅ $name up to date"
        return
    fi

    # Content diverged — show diff and ask
    echo ""
    echo "  ⚠️  $name differs from repo version:"
    echo "  ────────────────────────────────────"
    diff --color=auto -u "$dest" "$src" | head -40 || true
    echo "  ────────────────────────────────────"
    echo ""

    if [ "${FORCE_UPDATE:-}" = "1" ]; then
        echo "  🔄 Overwriting $name (FORCE_UPDATE=1)"
        cp "$src" "$dest"
        return
    fi

    read -rp "  Overwrite local $name with repo version? [y/N/d(iff)] " choice
    case "$choice" in
        y|Y)
            echo "  🔄 Overwriting $name"
            cp "$src" "$dest"
            ;;
        d|D)
            diff --color=auto -u "$dest" "$src" || true
            read -rp "  Overwrite? [y/N] " confirm
            case "$confirm" in
                y|Y) echo "  🔄 Overwriting $name"; cp "$src" "$dest" ;;
                *)   echo "  ⏭️  Keeping local $name" ;;
            esac
            ;;
        *)
            echo "  ⏭️  Keeping local $name"
            ;;
    esac
}

# Deploy configuration files (before statusline — its installer verifies settings.json)
copy_if_missing "$CONFIG_SOURCE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
copy_if_missing "$CONFIG_SOURCE/PERMISSIONS-GUIDE.md" "$CLAUDE_DIR/PERMISSIONS-GUIDE.md"
copy_if_missing "$CONFIG_SOURCE/README.md" "$CLAUDE_DIR/README.md"
copy_if_missing "$CONFIG_SOURCE/settings.json" "$CLAUDE_DIR/settings.json"

# Rewrite ~/.claude/ paths in settings.json for non-default targets
if [ "$CLAUDE_DIR" != "$HOME/.claude" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    claude_dir_tilde="${CLAUDE_DIR/#$HOME/\~}"
    echo "  🔄 Rewriting paths in settings.json → $claude_dir_tilde/"
    sed -i '' "s|~/.claude/|${claude_dir_tilde}/|g" "$CLAUDE_DIR/settings.json"
fi

# Apply per-target identity overlay (if present) — runs unconditionally so the
# placeholder block in settings.json is always replaced when an overlay exists,
# regardless of whether copy_if_missing overwrote the file. Must run AFTER the
# path-rewrite above so user-typed `~/.claude/` references in overlay prose
# aren't mangled.
if [ -f "$CLAUDE_DIR/identity.json" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    if ! command -v python3 >/dev/null 2>&1; then
        echo "  ⚠️  python3 not found — skipping identity overlay (install Xcode CLT then re-run)"
    else
        echo "  🪪 Applying identity overlay from identity.json"
        # Build the replacement block on stdout, one JSON array string per line,
        # using the same 6-space indent as the surrounding "environment" array.
        overlay_block="$(python3 - "$CLAUDE_DIR/identity.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    ident = json.load(f)
lines = ident.get("environment_extras", [])
if not lines:
    name = ident.get("name", "")
    email = ident.get("email", "")
    lines = [f"Developer: {name} ({email}), individual developer."]
indent = "      "
print("\n".join(f'{indent}{json.dumps(line)},' for line in lines))
PYEOF
)"
        # Write block to temp file, then use awk to splice it between markers.
        tmp_dir="${TMPDIR:-/tmp}"
        tmp_block="$tmp_dir/my-claude-identity-block.$$"
        tmp_out="$tmp_dir/my-claude-settings.$$"
        trap 'rm -f "$tmp_block" "$tmp_out"' EXIT
        printf '%s\n' "$overlay_block" > "$tmp_block"
        awk -v blockfile="$tmp_block" '
            /--- identity block start \(managed by make set-identity\) ---/ {
                print
                while ((getline line < blockfile) > 0) print line
                close(blockfile)
                in_block = 1
                next
            }
            /--- identity block end ---/ {
                in_block = 0
                print
                next
            }
            !in_block { print }
        ' "$CLAUDE_DIR/settings.json" > "$tmp_out"
        if python3 -c "import json; json.load(open('$tmp_out'))" 2>/dev/null; then
            mv "$tmp_out" "$CLAUDE_DIR/settings.json"
        else
            echo "  ❌ Overlay produced invalid JSON — keeping original settings.json" >&2
            rm -f "$tmp_out"
        fi
        rm -f "$tmp_block"
        trap - EXIT
    fi
fi

# Install the chosen statusline backend.
#
# Three backends are supported, selected by $STATUSLINE_CHOICE (resolved above):
#   - rz1989s: themed multi-line wrapper-fronted backend (the default)
#   - tmck:    Python entrypoint from tmck-code/yet-another-statusline
#   - none:    no statusline (statusLine key omitted from settings.json)
#
# Each backend's installation lives in its own block. The settings.json
# splicer further below points statusLine.command at the right entrypoint.

STATUSLINE_DIR="$CLAUDE_DIR/statusline"

# install_rz1989s — fetch, verify, and deploy rz1989s/claude-code-statusline.
# Called from two sites: (a) the normal STATUSLINE_CHOICE=rz1989s path, and
# (b) the tmck preflight-fallback path so the user gets a *working* rz1989s
# statusbar this run (not a half-deployed wrapper pointing at a missing
# backend). Extracted into a function so a future pin bump only edits one
# place.
#
# To bump the pin:
#   1. SHA=$(curl -sSfL https://api.github.com/repos/rz1989s/claude-code-statusline/commits/main | jq -r .sha)
#   2. curl -sSfL "https://raw.githubusercontent.com/rz1989s/claude-code-statusline/$SHA/install.sh" -o /tmp/sl.sh
#   3. shasum -a 256 /tmp/sl.sh   # paste both values below
install_rz1989s() {
    local STATUSLINE_COMMIT="90866b5a910236dbdd5b0298e22565a575dde6c0"
    local STATUSLINE_SHA256="fee0e745087b0a521eb9173cf98caa11e1d568aa63b1311815c402c73b22e9b0"
    local STATUSLINE_URL="https://raw.githubusercontent.com/rz1989s/claude-code-statusline/${STATUSLINE_COMMIT}/install.sh"
    local PRIMARY_STATUSLINE="$HOME/.claude/statusline/statusline.sh"

    if [ ! -f "$STATUSLINE_DIR/statusline.sh" ]; then
        if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
            # Primary target: install from upstream (pinned + checksum-verified)
            echo "  📊 Installing claude-code-statusline (pinned ${STATUSLINE_COMMIT:0:7})..."
            local statusline_tmp
            statusline_tmp="$(mktemp)"
            trap 'rm -f "$statusline_tmp"' EXIT
            curl -sSfL "$STATUSLINE_URL" -o "$statusline_tmp"
            local actual_sha
            actual_sha="$(shasum -a 256 "$statusline_tmp" | cut -d' ' -f1)"
            if [ "$actual_sha" != "$STATUSLINE_SHA256" ]; then
                echo "  ❌ Statusline installer checksum mismatch — refusing to execute" >&2
                echo "     expected: $STATUSLINE_SHA256" >&2
                echo "     actual:   $actual_sha" >&2
                exit 1
            fi
            bash "$statusline_tmp" --preserve-statusline
            rm -f "$statusline_tmp"
            trap - EXIT
        elif [ -f "$PRIMARY_STATUSLINE" ]; then
            # Non-default target: symlink from primary install.
            # ln -sf unlinks any pre-existing symlink at the destination rather
            # than following it — so a malicious pre-existing symlink at
            # $STATUSLINE_DIR/statusline.sh cannot redirect this write.
            echo "  📊 Linking statusline from primary install..."
            mkdir -p "$STATUSLINE_DIR"
            ln -sf "$PRIMARY_STATUSLINE" "$STATUSLINE_DIR/statusline.sh"
            # Also link supporting files (lib/, examples/, version.txt)
            for item in lib examples version.txt; do
                if [ -e "$HOME/.claude/statusline/$item" ]; then
                    ln -sf "$HOME/.claude/statusline/$item" "$STATUSLINE_DIR/$item"
                fi
            done
        else
            echo "  ⚠️  Statusline not available — install to ~/.claude first, then re-run"
        fi
    else
        echo "  ⏭️  claude-code-statusline already installed"
    fi

    # Deploy statusline config and wrapper (rz1989s only — tmck does not use the wrapper)
    if [ -d "$CONFIG_SOURCE/statusline" ]; then
        mkdir -p "$STATUSLINE_DIR"
        copy_if_missing "$CONFIG_SOURCE/statusline/Config.toml" "$STATUSLINE_DIR/Config.toml"
        # Always update wrapper (it's the routing logic, not user-customizable)
        echo "  📄 Deploying statusline-wrapper.sh"
        cp "$CONFIG_SOURCE/statusline/statusline-wrapper.sh" "$STATUSLINE_DIR/statusline-wrapper.sh"
        chmod +x "$STATUSLINE_DIR/statusline-wrapper.sh"
    fi
}

if [ "$STATUSLINE_CHOICE" = "rz1989s" ]; then
    install_rz1989s

elif [ "$STATUSLINE_CHOICE" = "tmck" ]; then
    # Run the dedicated tmck installer. Exit 2 from that script means the
    # Python preflight failed; how we react depends on whether the user
    # explicitly asked for tmck on this run (env var or via set-statusline).
    # On fallback, we flip STATUSLINE_CHOICE to rz1989s in-place AND run the
    # full rz1989s install so the user gets a working statusbar this run.
    # The marker file is left alone so the next install retries tmck once
    # Python is fixed.
    set +e
    "$SCRIPT_DIR/scripts/install-statusline-tmck.sh"
    tmck_rc=$?
    set -e
    if [ "$tmck_rc" -eq 2 ]; then
        if [ "$STATUSLINE_CHOICE_EXPLICIT" -eq 1 ]; then
            echo "  ❌ tmck statusline preflight failed and STATUSLINE_CHOICE=tmck was explicit" >&2
            echo "     Install Python 3.14+ then re-run, or pick rz1989s." >&2
            exit 1
        fi
        echo "  📛 tmck preflight failed — falling back to rz1989s for this run only"
        echo "     (your statusline-choice marker is unchanged; next install retries tmck)"
        STATUSLINE_CHOICE="rz1989s"
        install_rz1989s
    elif [ "$tmck_rc" -ne 0 ]; then
        exit "$tmck_rc"
    fi

elif [ "$STATUSLINE_CHOICE" = "none" ]; then
    echo "  ⏭️  statusline disabled (STATUSLINE_CHOICE=none) — no backend installed"
fi

# ---------------------------------------------------------------------------
# Persist the resolved choice to the per-target marker. We only write when
# (a) the marker doesn't exist yet (first install), or (b) the caller asked
# us to persist (STATUSLINE_CHOICE_PERSIST=1 — set by set-statusline.sh).
# A bare STATUSLINE_CHOICE env var does NOT trigger persistence, so a stray
# export in .zshrc does not launder itself into the marker.
# ---------------------------------------------------------------------------
if [ ! -f "$CLAUDE_DIR/statusline-choice" ] || [ "$STATUSLINE_CHOICE_PERSIST" -eq 1 ]; then
    printf '%s\n' "$STATUSLINE_CHOICE" > "$CLAUDE_DIR/statusline-choice"
fi

# ---------------------------------------------------------------------------
# Rewrite settings.json.statusLine to match the resolved choice. JSON
# load/mutate/dump (mirroring the identity-overlay Python block above) — not
# AWK-marker splicing, because the statusLine object spans multiple lines and
# would be vulnerable to any formatter that reorders keys.
# ---------------------------------------------------------------------------
if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$CLAUDE_DIR/settings.json" "$STATUSLINE_CHOICE" "$CLAUDE_DIR_TILDE" <<'PYEOF'
import json, os, sys
path, choice, tilde = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    s = json.load(f)
if choice == "rz1989s":
    s["statusLine"] = {
        "type": "command",
        "command": f"bash {tilde}/statusline/statusline-wrapper.sh",
        "refreshInterval": 5,
    }
elif choice == "tmck":
    s["statusLine"] = {
        "type": "command",
        "command": f"python3 {tilde}/statusline_command.py",
        "refreshInterval": 5,
    }
elif choice == "none":
    s.pop("statusLine", None)
else:
    sys.exit(f"unknown statusline choice: {choice!r}")
# Write atomically to avoid leaving a half-written file if the process is killed.
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")
os.replace(tmp, path)
PYEOF
    then
        echo "  ❌ statusLine splice failed — settings.json unchanged" >&2
        rm -f "$CLAUDE_DIR/settings.json.tmp"
    else
        echo "  🎚️  settings.json statusLine wired for: $STATUSLINE_CHOICE"
    fi
fi

# Deploy rules (auto-loaded by Claude Code)
if [ -d "$CONFIG_SOURCE/rules" ] && [ "$(ls -A "$CONFIG_SOURCE/rules" 2>/dev/null)" ]; then
    echo ""
    echo "  📏 Setting up rules..."
    for rule in "$CONFIG_SOURCE/rules/"*.md; do
        if [ -f "$rule" ]; then
            rule_name="$(basename "$rule")"
            copy_if_missing "$rule" "$CLAUDE_DIR/rules/$rule_name"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Remove files this repo used to deploy but no longer does. copy_if_missing
# never deletes, so without this list a renamed or deleted rule lingers in
# $CLAUDE_DIR forever — and rules keep loading into every session.
# ---------------------------------------------------------------------------
STALE_FILES=(
    "rules/quality-workflow.md"    # merged into CLAUDE.md
    "rules/remote-and-voice.md"    # moved to repo docs/reference/
    "rules/reliability.md"         # moved to commands/plan/references/
    "hooks/end-of-turn.sh"         # unwired stub, deleted from repo
)
for stale in "${STALE_FILES[@]}"; do
    if [ -f "$CLAUDE_DIR/$stale" ]; then
        echo "  🧹 Removing stale $stale"
        rm -f "$CLAUDE_DIR/$stale"
    fi
done

# Deploy agents
echo ""
echo "  🤖 Setting up agents..."
for agent in "$CONFIG_SOURCE/agents/"*.md; do
    if [ -f "$agent" ]; then
        agent_name="$(basename "$agent")"
        copy_if_missing "$agent" "$CLAUDE_DIR/agents/$agent_name"
    fi
done

# Deploy hooks (if present)
if [ -d "$SCRIPT_DIR/hooks" ] && [ "$(ls -A "$SCRIPT_DIR/hooks" 2>/dev/null)" ]; then
    echo ""
    echo "  🪝 Setting up hooks..."
    for hook in "$SCRIPT_DIR/hooks/"*; do
        if [ -f "$hook" ]; then
            hook_name="$(basename "$hook")"
            copy_if_missing "$hook" "$CLAUDE_DIR/hooks/$hook_name"
            chmod +x "$CLAUDE_DIR/hooks/$hook_name"
        fi
    done
fi

# Deploy skills (if present)
if [ -d "$SCRIPT_DIR/skills" ] && [ "$(ls -A "$SCRIPT_DIR/skills" 2>/dev/null)" ]; then
    echo ""
    echo "  🎯 Setting up skills..."
    mkdir -p "$CLAUDE_DIR/commands"
    for skill_dir in "$SCRIPT_DIR/skills/"*/; do
        if [ -d "$skill_dir" ]; then
            skill_name="$(basename "$skill_dir")"
            if [ ! -d "$CLAUDE_DIR/commands/$skill_name" ]; then
                echo "    📄 Copying skills/$skill_name"
                cp -r "$skill_dir" "$CLAUDE_DIR/commands/$skill_name"
            else
                # Compare each file within the skill directory (recursively)
                while read -r -u3 skill_file; do
                    rel="${skill_file#"$skill_dir"}"
                    dest="$CLAUDE_DIR/commands/$skill_name/$rel"
                    mkdir -p "$(dirname "$dest")"
                    copy_if_missing "$skill_file" "$dest"
                done 3< <(find "$skill_dir" -type f)
            fi
        fi
    done
fi

echo ""
echo "✅ my-claude installation complete!"
echo ""
echo "Configuration: $CLAUDE_DIR/"
echo "Development standards: $CLAUDE_DIR/CLAUDE.md"
echo "Rules (auto-loaded): $CLAUDE_DIR/rules/"
echo ""
echo "Available agents:"
for agent in "$CLAUDE_DIR/agents/"*.md; do
    if [ -f "$agent" ]; then
        agent_name="$(basename "$agent" .md)"
        echo "  - $agent_name"
    fi
done
echo ""
echo "Available skills (/slash commands):"
for skill_dir in "$CLAUDE_DIR/commands/"*/; do
    if [ -d "$skill_dir" ]; then
        skill_name="$(basename "$skill_dir")"
        echo "  - /$skill_name"
    fi
done
echo ""
