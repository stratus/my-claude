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

echo "🤖 Installing my-claude configuration..."
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

# Install rz1989s/claude-code-statusline
#
# We pin to a specific upstream commit and verify its install.sh by SHA-256
# instead of `curl … | bash`'ing main. To bump the pin:
#   1. SHA=$(curl -sSfL https://api.github.com/repos/rz1989s/claude-code-statusline/commits/main | jq -r .sha)
#   2. curl -sSfL "https://raw.githubusercontent.com/rz1989s/claude-code-statusline/$SHA/install.sh" -o /tmp/sl.sh
#   3. shasum -a 256 /tmp/sl.sh   # paste both values below
STATUSLINE_COMMIT="90866b5a910236dbdd5b0298e22565a575dde6c0"
STATUSLINE_SHA256="fee0e745087b0a521eb9173cf98caa11e1d568aa63b1311815c402c73b22e9b0"
STATUSLINE_URL="https://raw.githubusercontent.com/rz1989s/claude-code-statusline/${STATUSLINE_COMMIT}/install.sh"
STATUSLINE_DIR="$CLAUDE_DIR/statusline"
PRIMARY_STATUSLINE="$HOME/.claude/statusline/statusline.sh"

if [ ! -f "$STATUSLINE_DIR/statusline.sh" ]; then
    if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
        # Primary target: install from upstream (pinned + checksum-verified)
        echo "  📊 Installing claude-code-statusline (pinned ${STATUSLINE_COMMIT:0:7})..."
        statusline_tmp="$(mktemp)"
        trap 'rm -f "$statusline_tmp"' EXIT
        curl -sSfL "$STATUSLINE_URL" -o "$statusline_tmp"
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
        # Non-default target: symlink from primary install
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

# Deploy statusline config and wrapper
if [ -d "$CONFIG_SOURCE/statusline" ]; then
    mkdir -p "$STATUSLINE_DIR"
    copy_if_missing "$CONFIG_SOURCE/statusline/Config.toml" "$STATUSLINE_DIR/Config.toml"
    # Always update wrapper (it's the routing logic, not user-customizable)
    echo "  📄 Deploying statusline-wrapper.sh"
    cp "$CONFIG_SOURCE/statusline/statusline-wrapper.sh" "$STATUSLINE_DIR/statusline-wrapper.sh"
    chmod +x "$STATUSLINE_DIR/statusline-wrapper.sh"
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
