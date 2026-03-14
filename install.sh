#!/usr/bin/env bash
#
# Install my-claude configuration to ~/.claude/
#
# Usage: ./install.sh
#        FORCE_UPDATE=1 ./install.sh   (skip prompts, overwrite all)
#
# This script deploys Claude Code configuration files to the user's
# home directory. New files are copied in; existing files are compared
# by SHA-256 checksum. On mismatch, the user is shown a diff and
# prompted to overwrite or keep the local version.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
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

# Install rz1989s/claude-code-statusline if not already present
STATUSLINE_DIR="$CLAUDE_DIR/statusline"
if [ ! -f "$STATUSLINE_DIR/statusline.sh" ]; then
    echo "  📊 Installing claude-code-statusline..."
    curl -sSfL https://raw.githubusercontent.com/rz1989s/claude-code-statusline/main/install.sh | bash -s -- --preserve-statusline
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

# Deploy configuration files
copy_if_missing "$CONFIG_SOURCE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
copy_if_missing "$CONFIG_SOURCE/PERMISSIONS-GUIDE.md" "$CLAUDE_DIR/PERMISSIONS-GUIDE.md"
copy_if_missing "$CONFIG_SOURCE/README.md" "$CLAUDE_DIR/README.md"
copy_if_missing "$CONFIG_SOURCE/settings.json" "$CLAUDE_DIR/settings.json"

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
                # Compare each file within the skill directory
                for skill_file in "$skill_dir"*; do
                    if [ -f "$skill_file" ]; then
                        copy_if_missing "$skill_file" "$CLAUDE_DIR/commands/$skill_name/$(basename "$skill_file")"
                    fi
                done
            fi
        fi
    done
fi

echo ""
echo "✅ my-claude installation complete!"
echo ""
echo "Configuration: ~/.claude/"
echo "Development standards: ~/.claude/CLAUDE.md"
echo "Rules (auto-loaded): ~/.claude/rules/"
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
