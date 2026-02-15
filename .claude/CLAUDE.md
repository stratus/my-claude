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
make install    # Deploy to ~/.claude/ (copy-if-missing)
make clean      # Remove ~/.claude/ (creates backup first)
```

**copy-if-missing pattern**: `install.sh` only copies files that don't already exist at the destination. This preserves user customizations. To force-update a file, delete the target first then re-run `make install`.

## File Structure

| Path | Deploys to | Purpose |
|------|-----------|---------|
| `config/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global dev standards |
| `config/settings.json` | `~/.claude/settings.json` | Claude Code settings |
| `config/agents/*.md` | `~/.claude/agents/` | Agent definitions |
| `skills/*/SKILL.md` | `~/.claude/commands/*/SKILL.md` | Slash command skills |
| `hooks/*` | `~/.claude/hooks/` | Event hooks (made executable) |
| `config/statusline/` | `~/.claude/statusline/` | Statusline config |

## Conventions

### Skills
- One directory per skill under `skills/`
- Must have `SKILL.md` with YAML frontmatter (`name`, `description`)
- Sections: When to Use, Process, Output, Examples
- See `skills/commit-messages/SKILL.md` for reference

### Agents
- Markdown files in `config/agents/`
- Used via `subagent_type` in Task tool calls
- See existing agents for format

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
