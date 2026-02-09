#!/usr/bin/env bash
#
# Install my-claude configuration to ~/.claude/
#
# Usage: ./install.sh
#
# This script deploys Claude Code configuration files to the user's
# home directory. Files are only copied if they don't already exist
# to preserve user customizations.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CONFIG_SOURCE="$SCRIPT_DIR/config"

echo "🤖 Installing my-claude configuration..."
echo ""

# Create .claude directory structure
mkdir -p "$CLAUDE_DIR"/{agents,config,plans,hooks,commands}

# Copy main config files (only if they don't exist)
copy_if_missing() {
    local src="$1"
    local dest="$2"
    local name="$(basename "$src")"

    if [ -f "$dest" ]; then
        echo "  ⏭️  $name already exists (preserving)"
    else
        echo "  📄 Copying $name"
        cp "$src" "$dest"
    fi
}

# Install rz1989s/claude-code-statusline if not already present
STATUSLINE_DIR="$CLAUDE_DIR/statusline"
if [ ! -f "$STATUSLINE_DIR/statusline.sh" ]; then
    echo "  📊 Installing claude-code-statusline..."
    curl -sSfL https://raw.githubusercontent.com/rz1989s/claude-code-statusline/main/install.sh | bash -s -- --preserve-statusline
else
    echo "  ⏭️  claude-code-statusline already installed"
fi

# Deploy our Config.toml (only if it doesn't exist)
if [ -d "$CONFIG_SOURCE/statusline" ]; then
    mkdir -p "$STATUSLINE_DIR"
    copy_if_missing "$CONFIG_SOURCE/statusline/Config.toml" "$STATUSLINE_DIR/Config.toml"
fi

# Deploy configuration files
copy_if_missing "$CONFIG_SOURCE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
copy_if_missing "$CONFIG_SOURCE/PERMISSIONS-GUIDE.md" "$CLAUDE_DIR/PERMISSIONS-GUIDE.md"
copy_if_missing "$CONFIG_SOURCE/README.md" "$CLAUDE_DIR/README.md"
copy_if_missing "$CONFIG_SOURCE/settings.json" "$CLAUDE_DIR/settings.json"

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
            if [ -f "$CLAUDE_DIR/hooks/$hook_name" ]; then
                echo "    ⏭️  hooks/$hook_name already exists (preserving)"
            else
                echo "    📄 Copying hooks/$hook_name"
                cp "$hook" "$CLAUDE_DIR/hooks/$hook_name"
                chmod +x "$CLAUDE_DIR/hooks/$hook_name"
            fi
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
            if [ -d "$CLAUDE_DIR/commands/$skill_name" ]; then
                echo "    ⏭️  skills/$skill_name already exists (preserving)"
            else
                echo "    📄 Copying skills/$skill_name"
                cp -r "$skill_dir" "$CLAUDE_DIR/commands/$skill_name"
            fi
        fi
    done
fi

echo ""
echo "✅ my-claude installation complete!"
echo ""
echo "Configuration: ~/.claude/"
echo "Development standards: ~/.claude/CLAUDE.md"
echo ""
echo "Available agents:"
for agent in "$CLAUDE_DIR/agents/"*.md; do
    if [ -f "$agent" ]; then
        agent_name="$(basename "$agent" .md)"
        echo "  - $agent_name"
    fi
done
echo ""
