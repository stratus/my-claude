# my-claude Project Guidelines

## Purpose

Configuration repo that deploys Claude Code settings to `~/.claude/`. Contains global CLAUDE.md, agents, hooks, skills, and statusline config. Managed via `make install`.

## Security

**This repo is PUBLIC on GitHub.** Never commit:
- API keys, tokens, passwords, or credentials
- Personal project details or internal URLs
- Anything from `~/.claude/projects/` (auto memory is local-only)
- Private `.env` files or secrets of any kind
- Real names, emails, or employer-specific trust prose in `config/settings.json` — the Auto Mode `environment` array ships with placeholders inside an `--- identity block start ---` / `--- identity block end ---` marker pair. Real identity lives in `$CLAUDE_DIR/identity.json` (gitignored) and is spliced in by `install.sh`. See "Identity" below.

## Identity

`config/settings.json` ships identity-neutral. Per-target identity (name, email, optional org prose, optional `[includeIf]` git block) is configured by `make set-identity`, which writes `$CLAUDE_DIR/identity.json` — a gitignored file under the *deploy* target, not the repo. `install.sh` re-applies the overlay on every run by splicing `environment_extras` between the markers in `settings.json`. Source of truth lives outside the repo; the repo only holds placeholders.

**gitdir patterns are about work-repo trees, not `$CLAUDE_DIR`.** Common trap: someone running `make set-identity CLAUDE_TARGETS=~/.claude-corp` types `~/.claude-corp/` at the gitdir prompt because that's what's in front of them. But the includeIf needs to match the directory tree where **work repos** live (e.g. `~/claude-corp/`, `~/work/nvidia/`), which is usually unrelated to the Claude config dir. The script's prompt copy now makes this explicit and supports multiple comma-separated patterns.

Three orthogonal revert paths:

- `make unset-identity` — deletes `$CLAUDE_DIR/identity.json` and re-runs install with `FORCE_UPDATE=1` to restore `settings.json` placeholders. Does NOT touch `~/.gitconfig`.
- `make unset-git-identity` — removes only the `[includeIf]` path values this tooling wrote to `~/.gitconfig` (uses `git config --unset --fixed-value` for surgical removal); deletes `$CLAUDE_DIR/.gitconfig.d/identity.inc`. Does NOT touch `identity.json`. Writes a timestamped+PID-suffixed backup of `~/.gitconfig` first.
- `make reset-all-identity` — both of the above.

## Statusline backends

Two statusline backends are supported, plus a "none" option. The choice is per-target, persisted in `$CLAUDE_DIR/statusline-choice` (gitignored).

| Choice | Backend | settings.json `statusLine.command` |
|--------|---------|-----------------------------------|
| `rz1989s` (default) | rz1989s/claude-code-statusline + local `statusline-wrapper.sh` | `bash ~/.claude/statusline/statusline-wrapper.sh` |
| `tmck` | tmck-code/yet-another-statusline (Python entrypoint) | `python3 ~/.claude/statusline_command.py` |
| `none` | No statusline | (key absent from settings.json) |

Both backends are fetched at install time from the upstream GitHub repos, pinned to specific commits, and verified by SHA-256 before extraction. Pins live in `install.sh` (rz1989s) and `scripts/install-statusline-tmck.sh` (tmck).

**Setting the choice.**

- First `make install` on a new machine prompts once (interactive) and persists the answer to `~/.claude/statusline-choice`. Subsequent installs honor that marker silently.
- `make set-statusline` (interactive) or `make set-statusline CHOICE=tmck` (non-interactive) switches the backend. This is the only path that overwrites an existing marker.
- `STATUSLINE_CHOICE=tmck make install` overrides for **the current run only** — a bare env var does NOT rewrite the marker. This prevents a stray `export STATUSLINE_CHOICE=...` in `.zshrc` from silently laundering itself into the persisted record.
- `make unset-statusline` resets the per-target marker to `rz1989s` (rather than deleting it — deletion would let install.sh fall through to the primary `$HOME/.claude/statusline-choice`, potentially re-pinning to tmck on the next bare install). Restores the rz1989s install, and optionally prompts to remove the extracted tmck source under `$CLAUDE_DIR/external/yet-another-statusline-*/`.

**tmck requires Python ≥ 3.14** (stdlib-only, no venv). Preflight contract:

- If `STATUSLINE_CHOICE=tmck` was set **explicitly** on this run (env or `make set-statusline tmck`) and Python is too old: hard-fail with an actionable message.
- If the choice came from the **persisted marker** and Python is too old: log a warning and fall back to rz1989s **for this run only**. The marker is unchanged, so the next install retries tmck once Python is upgraded.

**Multi-target behaviour.** The Makefile prompts once before iterating `CLAUDE_TARGETS`, so a fresh-machine `make install CLAUDE_TARGETS="~/.claude ~/.claude-corp"` asks the question once and applies the same choice to every target. To diverge intentionally, run `make set-statusline CHOICE=tmck CLAUDE_TARGETS=~/.claude-corp` after the initial install.

**Non-default targets** symlink against the primary install, mirroring the existing rz1989s pattern — one tarball extraction per pinned commit, regardless of how many targets are deployed.

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
| `scripts/set-identity.sh` | (invoked, not deployed) | Interactive setup for `$CLAUDE_DIR/identity.json` |
| `scripts/install-statusline-tmck.sh` | (invoked, not deployed) | Fetches + verifies + extracts tmck-code/yet-another-statusline at a pinned commit |
| `scripts/prompt-statusline.sh` | (invoked, not deployed) | One-shot interactive chooser (rz1989s / tmck / none) |
| `scripts/set-statusline.sh` | (invoked, not deployed) | Persists `$CLAUDE_DIR/statusline-choice` and re-runs `install.sh` |
| `scripts/unset-statusline.sh` | (invoked, not deployed) | Removes marker + offers cleanup of extracted source; restores rz1989s |
| `config/statusline/` | `~/.claude/statusline/` | Statusline config (rz1989s wrapper + Config.toml) |
| `templates/cuj-template.md` | (manual copy) | CUJ document template |
| `templates/ad-template.md` | (manual copy) | Architecture Decision Record template |
| `templates/mcp.json.example` | (manual copy) | Recommended MCP servers for new projects |

## Conventions

### Rules loading
- Rules in `config/rules/` use `paths:` frontmatter (official key) to scope loading to matching files; rules without `paths:` load into every session. **Never use `globs:`** — Claude Code silently ignores unknown keys and loads the rule unconditionally. `scripts/check-config.sh` (and CI) enforce this.
- On-demand references live outside `rules/`: SRE reliability material is at `skills/plan/references/reliability.md`.

### Skills (14 total)
- One directory per skill under `skills/`
- Must have `SKILL.md` with YAML frontmatter (`name`, `description`, `model`)
- All skills must have explicit `model:` (haiku for mechanical, sonnet for reasoning, opus for quality ceiling)
- Sections: When to Use, Process, Output, Examples
- Key skills: `/plan` → `/egm` → `/implement` → `/audit` → `/polish` → `/learnings`
- Hands-off variant: `/plan` → `/autopilot <slug>` runs the whole plan unattended; stops only on hook exit 2, sandbox/network deny, or repeated test failure
- See `skills/commit-messages/SKILL.md` for reference

**Skill descriptions are a shared budget, not free text.** Claude Code injects every
skill's name + description each turn, capped at `skillListingBudgetFraction` of the
context window; on overflow it *silently truncates descriptions*, so a skill keeps
appearing installed while quietly losing the keywords it routes on. Check 6 in
`scripts/check-config.sh` caps this repo's contribution at 2000 chars (1% of a 200k
context) and CI enforces it. Write descriptions like the first-party ones — third
person, literal user phrasings front-loaded ("Use when the user says …"), not
conceptual prose. Skills that are always *typed* rather than inferred (`/autopilot`)
carry `disable-model-invocation: true`, which drops them from the listing entirely
while keeping the slash command.

**Skill handoffs must be dispatched, not suggested.** `/plan` previously told the user
to run `/egm` in prose and it never once fired. The working pattern — used for both the
Goldfish and autopilot handoffs — is `AskUserQuestion`, then emit the literal text
`/egm <slug>` (or `/autopilot <slug>`) and stop. Skills never transitively invoke other
skills; the slash-dispatch surface stays the only interrupt path.

### Agents (12 total)
- Markdown files in `config/agents/` with frontmatter: `model`, `tools`, `maxTurns`, `color`
- code-reviewer, security-analyst, and debug-specialist carry `memory: local` — persistent per-project agent memory under `.claude/agent-memory-local/<name>/`, never committed
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

### Plugins

Declared in `config/settings.json` via `enabledPlugins` (`{"plugin-id@marketplace-id": true}`)
and `extraKnownMarketplaces`, so a fresh machine reproduces the set through `make install`
instead of manual `/plugin install` steps. Enabled today: 4 LSPs (pyright, typescript,
gopls, rust-analyzer), 5 workflow plugins (skill-creator, plugin-dev, pr-review-toolkit,
code-review, claude-md-management), 2 integrations (github, playwright).

Curation rule: **don't enable capabilities that overlap what's already here.** Plugin
skills share the same listing budget as local ones, and duplicate coverage makes routing
worse. `security-guidance`, `feature-dev`, `hookify`, and `commit-commands` are
deliberately excluded — `security-analyst`, `/implement`, hand-written hooks, and
`/commit-messages` already cover them. `skill-creator` is worth knowing about: it runs
evals against a skill to measure trigger accuracy, which beats guessing at descriptions.

### settings.json is deploy-merged, not just copied

`copy_if_missing` is a whole-file `cp`, so any key that exists only in the deployed
`~/.claude/settings.json` is destroyed by `FORCE_UPDATE=1`. `install.sh` therefore
snapshots live `skillOverrides` *before* the copy and re-merges after: repo-owned skills
(anything with `skills/<name>/SKILL.md`) take the repo's value, everything else — corp
skills under `$CLAUDE_DIR/skills/`, synced claude.ai skills, anything toggled via
`/skills` — is carried forward. Add new always-local settings keys to
`config/settings.json` as a tracked baseline rather than letting them live only in the
deployed file.

### Hooks
- Shell scripts in `hooks/`
- Must be executable (`chmod +x`)
- Referenced from `config/settings.json`

Wired events (6):
- **PreToolUse / Bash** → `pretooluse-bash.sh` (dangerous-pattern scan + 5-gate commit blocker + autopilot bypass)
- **PreToolUse / Edit|Write** → `block-secrets-wrapper.sh` (fast secret-path veto)
- **PostToolUse / Edit|Write** → `after-edit.sh` (background format-on-save with timeout guard)
- **Notification** → `notify.sh` (desktop notifications)
- **SessionStart / startup** → `session-start-prune-markers.sh` (delete review markers >1h old to prevent stale-marker confusion)
- **UserPromptExpansion / plan|implement|autopilot|polish|audit|egm** → `log-skill-usage.sh` (one-line TSV log to `~/.claude/skill-usage.log` for the long-running workflow skills). Keep this matcher in sync when adding a workflow skill — the log is the only evidence of which skills actually run, and `egm`'s absence from it is why "why doesn't /egm fire?" took an investigation instead of a `grep`.
- **PreCompact / manual|auto** → `pre-compact-snapshot.sh` (writes a small recovery snapshot to `~/.claude/projects/<slug>/last-pre-compact.md` with branch, HEAD, recent commits, staged files, most recent plan)

### Permission Posture

Bash commands are gated in this order: `deny` → `ask` → `allow` (first match wins), then any explicit hook decision overrides.

- **`permissions.allow`** — silent auto-approve. Covers safe git (`status`, `diff`, `log`, `add`, `commit -m`, `checkout -b`, `fetch`, ...), most local language tools (`go *`, `npm *`, `pytest *`, `uv *`, `cargo *`, `make *`, `ansible *`, `gh *`, linters, formatters, ...), and the `mark-reviewed.sh` helpers.
- **`permissions.ask`** — always prompts. Reserved for destructive or remote git: `push`, `pull`, `reset --hard`, `rebase`, `merge`, `branch -D`, `clean -fd`, `stash drop`, `revert`, `cherry-pick`, `tag -d`, `remote add/remove/set-url`, and `checkout/switch main|master`.
- **`permissions.deny`** — hard-blocks. Reads of `.env*`, `*.pem`, `*.key`, and anything under `./secrets/`.
- **`defaultMode: "auto"`** — Auto Mode (Claude Code 2.1.83+). A Sonnet-4.6 classifier auto-approves safe actions including `git push`, `gh pr create`, and package installs using the prose rules in `autoMode.environment` / `autoMode.allow` / `autoMode.soft_deny` / `autoMode.hard_deny`. File edits/writes in the working directory still auto-approve (Auto Mode's built-in tier-2 default). The `block-secrets-wrapper.sh` PreToolUse hook still independently blocks Edit/Write to secret paths regardless of classifier verdict.

Under `/autopilot`, the env var `CLAUDE_AUTOPILOT=1` is exported. The `pretooluse-bash.sh` hook reads it and emits `permissionDecision: "allow"` for every `git *` invocation other than `git commit`. This silences the destructive-git prompts during a hands-off run **without** disabling: Phase A dangerous-pattern checks (force-push-to-protected-branch, `rm -rf /`, `mkfs`, etc.), Phase B's 5-gate commit blocker, or the secret blocker.

## Testing Changes

After modifying any config:
1. Run `bash scripts/check-config.sh` — validates settings.json, rules/skills/agents frontmatter, and documented counts
2. Run `make install` to deploy
3. Start a new `claude` session to pick up changes
4. Verify the change takes effect (skills appear in `/help`, agents load, etc.)

CI (`.github/workflows/ci.yml`) runs on every push: shellcheck (error severity) on hooks/scripts/installer, `scripts/check-config.sh`, and the bats suite in `tests/` covering `pretooluse-bash.sh` (dangerous patterns, autopilot bypass, all 5 gates, trivial carve-out).

For CLAUDE.md changes: the file is loaded into every session's system prompt. Check that instructions are clear and unambiguous.
