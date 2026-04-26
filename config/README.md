# Claude Code Configuration

This is the deployed `~/.claude/` configuration. Source repo: [my-claude](https://github.com/stratus/my-claude).

## What's Here

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Top-level instructions loaded into every session — short, points at `rules/` |
| `PERMISSIONS-GUIDE.md` | Sandbox, permission allow/deny semantics |
| `settings.json` | Hooks, permissions, sandbox config |
| `rules/` | Auto-loaded rule files (testing, security, git, languages, etc.) |
| `agents/` | 10 specialized sub-agents |
| `commands/` | Slash-command skills (`/plan`, `/implement`, `/polish`, …) |
| `hooks/` | Event hooks (pre-commit gate, dangerous-command blocker, formatters) |
| `statusline/` | Statusline binary + Config.toml + wrapper |
| `review-markers/` | Runtime — fresh-review markers used by the pre-commit gate |
| `projects/` | Runtime — per-project auto-memory (local only, never commit) |
| `plans/` | Runtime — saved implementation plans |

## Workflow

```
/plan → /implement → /polish
```

Pre-commit gate enforces 5 conditions on every `git commit`:

1. Code review for >20 lines changed
2. Security review for sensitive files
3. Tests pass
4. Coverage ≥ 80%
5. Docs review for user-facing changes

Markers expire after 10 minutes. Escape hatch when consciously skipping: `~/.claude/hooks/mark-reviewed.sh --all`.

## Updating

```bash
cd ~/my-claude
git pull
make install
```

The installer compares each file by SHA-256 and prompts before overwriting local edits. Use `FORCE_UPDATE=1` to skip prompts.

## Customization

- **Machine-specific overrides**: edit files in `~/.claude/` directly. `make install` will detect divergence and prompt.
- **New agent**: add `~/.claude/agents/<name>.md` with frontmatter (`model`, `tools`, `maxTurns`). Reference it as the `subagent_type` when dispatching the Agent tool.
- **New skill**: create `~/.claude/commands/<name>/SKILL.md` with `name`, `description`, `model` frontmatter. Trigger with `/<name>`.
- **New rule**: drop a `.md` file in `~/.claude/rules/`. Auto-loaded on session start.

To contribute changes back, edit the corresponding source file in `~/my-claude/config/` and commit there — `make install` round-trips them.

## More

- **Source repo**: [github.com/stratus/my-claude](https://github.com/stratus/my-claude)
- **Long-form guide**: [docs/GUIDE.md](https://github.com/stratus/my-claude/blob/main/docs/GUIDE.md)
- **MCP setup**: [docs/mcp-setup.md](https://github.com/stratus/my-claude/blob/main/docs/mcp-setup.md)
- **Official docs**: https://docs.claude.com/en/docs/claude-code
