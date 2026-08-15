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

## Statusline

`config/statusline/statusline.sh` (bash + `jq`) is the whole statusline. There is no
backend choice, no marker file, no pinned commit, and no network fetch — `install.sh`
copies the script and points `settings.json` at
`bash ~/.claude/statusline/statusline.sh`.

**The invariant: exactly two lines, for every possible payload.** This is the property
the file exists to guarantee. It replaced a vendored backend whose height was hardcoded
in Python and grew with activity — a boxed panel that reached 15 rows with subagents
running. `check-config.sh` and `tests/statusline.bats` both assert the line count; treat
a third line as a bug, not a feature.

```
 ~/d/s/my-claude  main*  Opus 5 · high
 ctx ████░░░░░░ 38%  |  5h 23%  |  7d 41%
```

Line 1: abbreviated cwd, git branch + `*` if dirty, model, effort. Line 2: context-window
usage, then 5h/7d rate-limit headroom. Under `~/claude-corp/` line 2 shows session cost
and elapsed time instead — that path is API-billed, where cost is real and `rate_limits`
is absent. This cwd branch is the only conditional in the script and preserves the intent
of the former `statusline-wrapper.sh`.

**Read the native payload fields; never parse the transcript.** Claude Code now ships
pre-calculated `context_window.used_percentage` and a `rate_limits` object
(`five_hour`/`seven_day`, each `used_percentage` + `resets_at`). Estimating tokens from
the transcript JSONL is what made the third-party projects thousands of lines long. If a
new segment is wanted, check the payload schema first — it also carries `fast_mode`,
`thinking`, `vim.mode`, `agent.name`, `pr.*`, and `worktree.*`.

Constraints worth knowing before editing:

- **`tput cols` cannot work here.** Claude Code captures stdout instead of attaching a
  tty. Read `$COLUMNS` (it sets it). The old backend's `tmux display-message` probe is
  why it picked a 110-column layout inside an 80-column terminal.
- **Sanitize types in `jq`, not bash.** All numeric fields go through
  `if (… | type) == "number"`. A string `total_cost_usd` reaching `printf '%.2f'` writes
  to stderr and breaks the silent-stderr contract.
- **Never emit an empty field.** Fields are read positionally, one per line, via
  `mapfile`. An empty or newline-containing value desyncs every field after it — that bug
  shipped once and showed the context percentage where the model name belonged.
- **Nulls are normal.** `context_window` is null before the first API call and after
  `/compact`; `rate_limits` is absent on non-Pro/Max accounts. When rate limits are
  missing, drop those segments rather than printing `0%` — a false zero reads as "no
  quota used."
- **Multi-line bars are officially fragile** (escape codes, resize collapse), so keep
  line 2 ANSI-light and always reset before the newline.

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
| `scripts/check-config.sh` | (invoked, not deployed) | Repo consistency checks; also run in CI |
| `config/statusline/statusline.sh` | `~/.claude/statusline/statusline.sh` | The 2-line session bar (bash + jq) |
| `tests/*.bats` | (not deployed) | bats suites for `pretooluse-bash.sh` and the statusline |
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
instead of manual `/plugin install` steps. Enabled today (10, all first-party): 4 LSPs
(pyright, typescript, gopls, rust-analyzer), 5 workflow plugins (skill-creator,
plugin-dev, pr-review-toolkit, code-review, claude-md-management), and github.

Plugin versions **float** — the marketplace stores no ref, the repo publishes no tags,
and a plugin's `"version"` is metadata, not a pin. Prefer first-party plugins, keep the
set small, and treat `installed_plugins.json`'s `gitCommitSha` as the change-detection
signal. Avoid plugins whose MCP servers resolve `@latest` at spawn time (this is why
`playwright` is not enabled).

Curation rule: **don't enable capabilities that overlap what's already here.** Plugin
skills share the same listing budget as local ones, and duplicate coverage makes routing
worse. `security-guidance`, `feature-dev`, `hookify`, and `commit-commands` are
deliberately excluded — `security-analyst`, `/implement`, hand-written hooks, and
`/commit-messages` already cover them. `skill-creator` is worth knowing about: it runs
evals against a skill to measure trigger accuracy, which beats guessing at descriptions.

### Never sync deployed settings back into the repo

**`skillOverrides` in this repo holds repo-owned skills only.** The deployed
`~/.claude/settings.json` accumulates entries naming internal/employer tooling (Jira,
Slack, PagerDuty, Glean, SharePoint, and similar). This repo is PUBLIC, so copying a
deployed `settings.json` back over `config/settings.json` would publish that list. The
merge is deliberately one-directional — deployed values flow *into* the deploy target at
install time and never back into the repo. Add repo-owned entries by hand; never by
copying the live file.

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
1. Run `bash scripts/check-config.sh` — validates settings.json, rules/skills/agents frontmatter, documented counts, and the statusline (parses, renders exactly 2 lines, wired in settings.json)
2. Run `make install` to deploy
3. Start a new `claude` session to pick up changes
4. Verify the change takes effect (skills appear in `/help`, agents load, etc.)

CI (`.github/workflows/ci.yml`) runs on every push: shellcheck (error severity) on hooks/scripts/statusline/installer, `scripts/check-config.sh`, and the bats suites in `tests/` covering `pretooluse-bash.sh` (dangerous patterns, autopilot bypass, all 5 gates, trivial carve-out) and `statusline.sh` (the 2-line invariant, field extraction, corp split, hostile input, width fitting).

For CLAUDE.md changes: the file is loaded into every session's system prompt. Check that instructions are clear and unambiguous.
