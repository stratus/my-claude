# my-claude Project Guidelines

## Purpose

Configuration repo that deploys Claude Code settings to `~/.claude/`. Contains global CLAUDE.md, agents, hooks, skills, and statusline config. Managed via `make install`.

## Security

**This repo is PUBLIC on GitHub.** Never commit:
- API keys, tokens, passwords, or credentials
- Personal project details or internal URLs
- Anything from `~/.claude/projects/` (auto memory is local-only)
- Private `.env` files or secrets of any kind

## Deployment

```bash
make install              # Deploy to ~/.claude/ (interactive on conflicts)
FORCE_UPDATE=1 make install  # Overwrite all diverged files without prompting
make clean                # Remove ~/.claude/ (creates backup first)

# Multi-target: deploy to additional Claude instances
make install CLAUDE_TARGETS="~/.claude ~/.claude-corp"
```

**Smart deploy**: `install.sh` copies new files and compares existing ones by SHA-256 checksum. On content mismatch, it shows a diff and prompts to overwrite or keep the local version. Use `FORCE_UPDATE=1` to skip prompts. Use `CLAUDE_TARGETS` to deploy to multiple directories in one go.

## File Structure

| Path | Deploys to | Purpose |
|------|-----------|---------|
| `config/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global dev standards (~100 lines) |
| `config/rules/*.md` | `~/.claude/rules/` | Auto-loaded rule files (split from CLAUDE.md) |
| `config/settings.json` | `~/.claude/settings.json` | Claude Code settings (hooks, permissions, sandbox) |
| `config/agents/*.md` | `~/.claude/agents/` | Agent definitions |
| `skills/*/SKILL.md` | `~/.claude/commands/*/SKILL.md` | Slash command skills |
| `hooks/*` | `~/.claude/hooks/` | Event hooks (made executable) |
| `config/statusline/` | `~/.claude/statusline/` | Statusline config |
| `templates/cuj-template.md` | (manual copy) | CUJ document template |
| `templates/ad-template.md` | (manual copy) | Architecture Decision Record template |
| `templates/mcp.json.example` | (manual copy) | Recommended MCP servers for new projects |

## Conventions

### Skills (12 total)
- One directory per skill under `skills/`
- Must have `SKILL.md` with YAML frontmatter (`name`, `description`, `model`)
- All skills must have explicit `model:` (haiku for mechanical, sonnet for reasoning, opus for quality ceiling)
- Sections: When to Use, Process, Output, Examples
- Key skills: `/plan` → `/implement` → `/audit` → `/polish` → `/learnings`
- See `skills/commit-messages/SKILL.md` for reference

### Agents (10 total)
- Markdown files in `config/agents/` with frontmatter: `model`, `tools`, `maxTurns`, `color`
- Core workflow: code-reviewer → security-analyst → docs-updater
- Quality specialists: integration-tester, cuj-verifier, architect-reviewer (opus), ux-reviewer
- Stack specialists: react-frontend, python-backend, debug-specialist

### Pre-Commit Gate (5 blocking gates)
- Gate 1: Code review (>20 lines) — marker: `code-reviewed`
- Gate 2: Security review (sensitive files) — marker: `security-reviewed`
- Gate 3: Tests pass — marker: `tests-passed`
- Gate 4: Coverage >= 80% — marker: `coverage-checked` (format: `TIMESTAMP:PERCENTAGE`)
- Gate 5: Docs review (user-facing changes) — marker: `docs-reviewed`
- Stale CUJ/AD touching changed code also blocks
- Escape hatch: `mark-reviewed.sh --all`

### Hooks
- Shell scripts in `hooks/`
- Must be executable (`chmod +x`)
- Referenced from `config/settings.json`

## Testing Changes

After modifying any config:
1. Run `make install` to deploy
2. Start a new `claude` session to pick up changes
3. Verify the change takes effect (skills appear in `/help`, agents load, etc.)

For CLAUDE.md changes: the file is loaded into every session's system prompt. Check that instructions are clear and unambiguous.
