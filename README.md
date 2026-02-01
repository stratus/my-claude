# my-claude

Personal Claude Code configuration repository.

## Overview

This repository contains my Claude Code configuration, including:

- **CLAUDE.md** - Global development standards and instructions
- **agents/** - Custom agent definitions (code-reviewer, debug-specialist, docs-updater)
- **hooks/** - Enforcement scripts for security and quality
- **skills/** - Reusable automation commands
- **docs/** - Setup guides (MCP servers, etc.)

## Installation

### Via bootstrap-my-mac

```bash
# Full bootstrap includes my-claude
curl -fsSL https://raw.githubusercontent.com/stratus/bootstrap-my-mac/main/bootstrap.sh | bash
```

### Standalone

```bash
git clone git@github.com:stratus/my-claude.git ~/my-claude
cd ~/my-claude
make install
```

## Structure

```
my-claude/
├── config/
│   ├── CLAUDE.md           # Development standards
│   ├── PERMISSIONS-GUIDE.md # Security & permissions
│   ├── settings.json       # Claude Code settings
│   └── agents/             # Custom agents
│       ├── code-reviewer.md
│       ├── debug-specialist.md
│       └── docs-updater.md
├── hooks/                  # Enforcement hooks
├── skills/                 # Slash commands
├── docs/                   # Reference documentation
├── install.sh              # Installation script
├── Makefile                # Build orchestration
└── README.md
```

## Configuration Files

### CLAUDE.md

Global development standards applied to all projects:
- Security-first approach
- 80% minimum test coverage
- Documentation requirements
- Code readability standards
- Git workflow guidelines

### Agents

Custom agents for specialized tasks:

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Reviews code for security, quality, and best practices |
| `debug-specialist` | Diagnoses errors and provides fixes |
| `docs-updater` | Keeps documentation current |

### Hooks

Enforcement scripts that run deterministically:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `block-secrets.py` | PreToolUse | Prevents access to .env files |
| `block-dangerous-commands.sh` | PreToolUse | Blocks destructive operations |
| `after-edit.sh` | PostToolUse | Runs formatters after edits |
| `end-of-turn.sh` | Stop | Quality gates and validation |
| `notify.sh` | Notification | Desktop notifications |

### Skills

Reusable automation via slash commands:

| Skill | Usage | Purpose |
|-------|-------|---------|
| `commit-messages` | `/commit-messages` | Generate conventional commits |
| `security-audit` | `/security-audit` | Run vulnerability scans |

### MCP Servers

External tool integrations configured globally. See [docs/mcp-setup.md](docs/mcp-setup.md).

| Server | Purpose |
|--------|---------|
| `github` | Issue/PR management, repo access |
| `context7` | Current documentation lookup |

## Deployment

Configuration deploys to `~/.claude/`:

```
~/.claude/
├── CLAUDE.md
├── PERMISSIONS-GUIDE.md
├── settings.json
├── agents/
├── hooks/
├── commands/    # Skills deploy here
├── config/
└── plans/
```

## Usage

After installation, start Claude Code:

```bash
claude
```

## Updating

Pull latest changes and reinstall:

```bash
cd ~/my-claude
git pull
make install
```

## Related

- [bootstrap-my-mac](https://github.com/stratus/bootstrap-my-mac) - Full Mac setup
- [claude-code-mastery](https://github.com/TheDecipherist/claude-code-mastery) - Community resources
