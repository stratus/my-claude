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

### Skills (14 total)
- One directory per skill under `skills/`
- Must have `SKILL.md` with YAML frontmatter (`name`, `description`, `model`)
- All skills must have explicit `model:` (haiku for mechanical, sonnet for reasoning, opus for quality ceiling)
- Sections: When to Use, Process, Output, Examples
- Key skills: `/plan` → `/implement` → `/audit` → `/polish` → `/learnings`
- Hands-off variant: `/plan` → `/autopilot <slug>` runs the whole plan unattended; stops only on hook exit 2, sandbox/network deny, or repeated test failure
- See `skills/commit-messages/SKILL.md` for reference

### Agents (12 total)
- Markdown files in `config/agents/` with frontmatter: `model`, `tools`, `maxTurns`, `color`
- Core workflow: code-reviewer → security-analyst → docs-updater
- Quality specialists: integration-tester, cuj-verifier, architect-reviewer (opus), reliability-engineer (opus), ux-reviewer
- Stack specialists: react-frontend, python-backend, ansible-engineer, debug-specialist

### Pre-Commit Gate (5 blocking gates)
- Gate 1: Code review (>20 lines) — marker: `code-reviewed`
- Gate 2: Security review (sensitive files) — marker: `security-reviewed`
- Gate 3: Tests pass — marker: `tests-passed`
- Gate 4: Coverage >= 80% — marker: `coverage-checked` (format: `TIMESTAMP:PERCENTAGE`)
- Gate 5: Docs review (user-facing changes) — marker: `docs-reviewed`
- Stale CUJ/AD touching changed code also blocks
- Escape hatch: `mark-reviewed.sh --all`

**Trivial-change carve-out**: Gates 3 (tests) and 4 (coverage) are skipped when ALL of: `LINES_CHANGED ≤ 20`, no changed file matches the security pattern, and no changed file matches the user-facing pattern. This mirrors Gate 1's threshold so typo fixes, comment tweaks, and small config nudges commit cleanly without a full test+coverage cycle. Gates 1, 2, and 5 stay active on their own triggers.

### Hooks
- Shell scripts in `hooks/`
- Must be executable (`chmod +x`)
- Referenced from `config/settings.json`

### Permission Posture

Bash commands are gated in this order: `deny` → `ask` → `allow` (first match wins), then any explicit hook decision overrides.

- **`permissions.allow`** — silent auto-approve. Covers safe git (`status`, `diff`, `log`, `add`, `commit -m`, `checkout -b`, `fetch`, ...), most local language tools (`go *`, `npm *`, `pytest *`, `uv *`, `cargo *`, `make *`, `ansible *`, `gh *`, linters, formatters, ...), and the `mark-reviewed.sh` helpers.
- **`permissions.ask`** — always prompts. Reserved for destructive or remote git: `push`, `pull`, `reset --hard`, `rebase`, `merge`, `branch -D`, `clean -fd`, `stash drop`, `revert`, `cherry-pick`, `tag -d`, `remote add/remove/set-url`, and `checkout/switch main|master`.
- **`permissions.deny`** — hard-blocks. Reads of `.env*`, `*.pem`, `*.key`, and anything under `./secrets/`.
- **`defaultMode: "acceptEdits"`** — file edits/writes auto-approve. The `block-secrets-wrapper.sh` PreToolUse hook still independently blocks Edit/Write to secret paths, so this is safe.

Under `/autopilot`, the env var `CLAUDE_AUTOPILOT=1` is exported. The `pretooluse-bash.sh` hook reads it and emits `permissionDecision: "allow"` for every `git *` invocation other than `git commit`. This silences the destructive-git prompts during a hands-off run **without** disabling: Phase A dangerous-pattern checks (force-push-to-protected-branch, `rm -rf /`, `mkfs`, etc.), Phase B's 5-gate commit blocker, or the secret blocker.

## Testing Changes

After modifying any config:
1. Run `make install` to deploy
2. Start a new `claude` session to pick up changes
3. Verify the change takes effect (skills appear in `/help`, agents load, etc.)

For CLAUDE.md changes: the file is loaded into every session's system prompt. Check that instructions are clear and unambiguous.
