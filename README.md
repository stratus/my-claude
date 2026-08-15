# my-claude

Personal Claude Code configuration repository. Deploys global standards, agents, skills, hooks, and rules to `~/.claude/`.

## Overview

This repo is the source of truth for a Claude Code setup that emphasizes:

- **Quality ratchets** — pre-commit gate with 5 blocking checks (review, security, tests, coverage, docs)
- **Specialized agents** — 12 sub-agents for code review, security, debugging, integration testing, architecture, reliability, UX, and stack work (React, Python, Ansible)
- **Workflow skills** — `/plan` → `/implement` → `/polish` covers most of a feature lifecycle
- **Auto-loaded rules** — modular guidance under `~/.claude/rules/` instead of one monolithic CLAUDE.md
- **Reusable templates** — Next.js, React Native, Go CLI, plus CUJ/ADR/MCP scaffolds

## Prerequisites

- **macOS or Linux** — installer uses BSD `sed -i ''` on macOS; pre-commit gate handles both BSD and GNU `date`.
- **bash 4+ recommended** (bash 3.2 on macOS works but lacks some features the inner skills assume)
- **`jq`** — required by `pretooluse-bash.sh`, `notify.sh`, `after-edit.sh`
- **`python3`** — required by `block-secrets.py` (the Read/Edit/Write secrets blocker)
- **`git`** — for the pre-commit gate's diff inspection
- **`shasum`** — used by `install.sh` to detect drift on update (preinstalled on macOS; install via `coreutils` on Linux)
- **Claude Code CLI** — install from <https://docs.claude.com/en/docs/claude-code>

Quick sanity check before installing:

```bash
command -v jq git shasum bash python3 >/dev/null && echo "ok"
```

## Installation

```bash
# Replace YOUR-FORK with your GitHub username (or use the upstream URL if you haven't forked)
git clone git@github.com:YOUR-FORK/my-claude.git ~/my-claude
cd ~/my-claude
make install
```

`make install` deploys to `~/.claude/`. On a content mismatch with an existing file, the installer shows a diff and asks before overwriting. Use `FORCE_UPDATE=1 make install` to skip prompts.

To deploy the same config to a secondary Claude instance (e.g., a corp-managed install):

```bash
make install CLAUDE_TARGETS="~/.claude ~/.claude-corp"
```

To remove a deployed config (creates a backup first):

```bash
make clean
```

## Personalizing your install

`make install` ships an identity-neutral configuration — `config/settings.json` contains a placeholder developer description rather than anyone's real name or email. To configure your own identity:

```bash
make set-identity                                            # writes ~/.claude/identity.json
make set-identity CLAUDE_TARGETS="~/.claude ~/.claude-corp"  # per-target prompts
```

This walks you through:

- Your name and email (used to render the Auto Mode `environment` prose that the permission classifier reads)
- Optional organization-specific trust prose (e.g., internal domains your employer's tools live on)
- Optional `[includeIf "gitdir:..."]` stanzas in `~/.gitconfig` that scope `user.name` / `user.email` to one or more **work-repo directory trees**

### gitdir patterns describe work-repo trees, not your Claude config dir

When prompted for `gitdir` patterns, supply the directory tree(s) under which you **clone your actual git repos** — not your `$CLAUDE_DIR`. These are often different. Example for a typical NVIDIA developer:

```
Claude config dir:  ~/.claude-corp/        (where settings.json lives)
Work repo tree:     ~/claude-corp/         (where corp git repos are cloned)
```

You can supply multiple comma-separated patterns in one prompt:

```
Patterns: ~/claude-corp/, ~/work/nvidia/, ~/src/nvidia/
```

Each becomes its own `[includeIf "gitdir/i:..."]` stanza pointing at the same `identity.inc`. Patterns must end with `/`. macOS defaults to case-insensitive matching (`gitdir/i:`); Linux to case-sensitive (`gitdir:`).

**Note on symlinks:** git's gitdir matching uses the canonical path of the `.git` directory. If your repo path traverses a symlink (e.g. `~/work` is a symlink to `/Volumes/external/work`), supply the canonical form as the pattern.

The resulting `$CLAUDE_DIR/identity.json` is gitignored — it lives in your deploy target, never in the repo. To revert:

```bash
make unset-identity         # remove identity.json overlay (restore settings.json placeholders)
make unset-git-identity     # remove the [includeIf] stanzas this tooling wrote to ~/.gitconfig
make reset-all-identity     # both of the above
```

`unset-git-identity` is surgical: it removes only the `path = ` values pointing at this target's `identity.inc`. Legacy `[includeIf]` stanzas under the same subsection (if you had one before) are left intact. A timestamped backup of `~/.gitconfig` is written before any mutation.

## Statusline backends

`make install` lets you pick one of two third-party statuslines (or none) for the Claude Code session bar. Both are fetched from upstream at install time and pinned to a reviewed commit (SHA-256 verified).

| Choice | Backend | Notes |
|--------|---------|-------|
| `rz1989s` (default) | [rz1989s/claude-code-statusline](https://github.com/rz1989s/claude-code-statusline) | Themed multi-line wrapper, configurable via `~/.claude/statusline/Config.toml`. The repo's existing `statusline-wrapper.sh` provides corp-vs-personal `ENV_CONFIG_*` routing on top. |
| `tmck` | [tmck-code/yet-another-statusline](https://github.com/tmck-code/yet-another-statusline) | Python entrypoint. Requires **Python ≥ 3.14** (stdlib-only — no venv or pip install). |
| `none` | No statusline | The `statusLine` key is omitted from `settings.json`. |

On the first `make install` on a new machine, the installer prompts once for the choice and persists the answer to `~/.claude/statusline-choice`. Subsequent installs honor that marker silently.

To switch backends later — `CHOICE=` is a Makefile variable (same syntax as `CLAUDE_TARGETS=`), so it goes **after** the target:

```bash
make set-statusline              # interactive (rz1989s | tmck | none)
make set-statusline CHOICE=tmck  # non-interactive
make unset-statusline            # reset the per-target marker to rz1989s
```

For a one-off override that does **not** persist — `STATUSLINE_CHOICE=` is an environment variable, so it goes **before** the command:

```bash
STATUSLINE_CHOICE=none make install
```

A bare env var controls the current run only; it never overwrites the persisted marker. (This prevents a stray `export STATUSLINE_CHOICE=...` in `.zshrc` from silently laundering into the marker.) For multi-target installs (`CLAUDE_TARGETS="~/.claude ~/.claude-corp"`), the first-run prompt fires **once** and the same choice is applied to every target.

**Python 3.14 fallback contract.** If you pick `tmck` and later lose Python ≥ 3.14, the next `make install`:

- **Hard-fails** when `STATUSLINE_CHOICE=tmck` is set explicitly on the command line (you asked for it).
- **Falls back to `rz1989s`** when the choice came from the persisted marker. The marker is left unchanged, so the next install retries `tmck` once Python is fixed. The fallback runs the full rz1989s install — you get a working statusbar for this run, not a half-deployed wrapper.

There is no `make reset-all-statusline` target (in contrast to identity's `reset-all-identity`). Statusline has no `~/.gitconfig` side effects to clean up — `make unset-statusline` covers the marker and offers cleanup of the extracted tmck source under `$CLAUDE_DIR/external/`.

## Repository Structure

```
my-claude/
├── config/                       # Source of truth — deploys to ~/.claude/
│   ├── CLAUDE.md                 # Global standards (concise, points at rules/)
│   ├── PERMISSIONS-GUIDE.md      # Permissions and sandbox notes
│   ├── settings.json             # Hooks, permissions, sandbox config
│   ├── rules/*.md                # Auto-loaded rule files
│   ├── agents/*.md               # 12 sub-agent definitions
│   └── statusline/               # Statusline wrapper + Config.toml
├── skills/<name>/SKILL.md        # 14 slash-command skills → ~/.claude/commands/
├── hooks/*.sh                    # Event hooks → ~/.claude/hooks/ (chmod +x)
├── scripts/                      # Setup helpers (set-identity.sh, set-statusline.sh,
│                                 #   install-statusline-tmck.sh, prompt-statusline.sh, ...)
├── docs/                         # Reference docs (GUIDE.md, mcp-setup.md)
├── templates/                    # Project scaffolds + doc templates
│   ├── nextjs/.claude/CLAUDE.md
│   ├── react-native/.claude/CLAUDE.md
│   ├── go-cli/.claude/CLAUDE.md
│   ├── cuj-template.md
│   ├── ad-template.md
│   └── mcp.json.example
├── .claude/CLAUDE.md             # Project-local rules for editing this repo
├── install.sh                    # Checksum-aware deployer
├── Makefile                      # install / clean / help / set-identity / set-statusline / ...
└── README.md
```

`config/` is what deploys. `.claude/` is local — only Claude reads it when working **in this repo** (e.g., to enforce "this repo is public, never commit secrets").

## Workflow

```
/plan → /implement → /polish
```

That's the whole user-facing workflow. Everything else (running agents, setting review markers, capturing learnings) is automatic.

The **pre-commit gate** runs on every `git commit` and blocks until 5 conditions are met:

1. Code review for >20 lines changed
2. Security review for sensitive files (auth, crypto, validation, etc.)
3. Tests pass
4. Coverage ≥ 80%
5. Docs review for user-facing changes

Markers expire after 10 minutes. Escape hatch: `~/.claude/hooks/mark-reviewed.sh --all`.

## Agents

Markdown definitions in `config/agents/` deploy to `~/.claude/agents/`.

| Agent | Model | Purpose |
|-------|-------|---------|
| `code-reviewer` | opus | Security, quality, tests, best practices — mandatory after >20 lines |
| `security-analyst` | opus | Threat modeling, auth flow review, infrastructure security |
| `docs-updater` | haiku | Keeps user-facing documentation in sync with code |
| `debug-specialist` | opus | Root-cause analysis for errors, test failures, unexpected behavior |
| `integration-tester` | sonnet | E2E tests, API contracts, cross-component flows |
| `cuj-verifier` | sonnet | Walks documented Critical User Journeys to catch doc/code drift |
| `architect-reviewer` | opus | Cross-component changes, new dependencies, AD compliance |
| `reliability-engineer` | opus | SLOs, failure modes, observability, rollback — plan-time SRE lens |
| `ux-reviewer` | sonnet | Loading/empty/error states, a11y, responsive design |
| `react-frontend` | sonnet | React 19, Zustand, React Flow, Tailwind v4 |
| `python-backend` | sonnet | FastAPI, async, Temporal, SQLAlchemy, Pydantic |
| `ansible-engineer` | sonnet | Ansible playbooks, roles, collections, molecule testing |

Most agents dispatch automatically from `/audit` and `/polish`.

## Skills (Slash Commands)

Each skill is a directory under `skills/` with a `SKILL.md`. Deployed to `~/.claude/commands/<name>/`.

| Skill | Model | Purpose |
|-------|-------|---------|
| `/plan` | opus | Interview, design phased approach, produce implementation plan |
| `/egm` | opus | Goldfish Protocol — verify design doc completeness before implementing |
| `/implement` | opus | Phased execution with quality gates after planning |
| `/autopilot` | opus | Hands-off plan execution — runs phases, dispatches review agents, commits per phase |
| `/audit` | sonnet | Read-only health report (code, security, docs, CUJ/AD) |
| `/polish` | opus | Fix audit findings, walk DoD, score 0-100, save learnings |
| `/learnings` | haiku | Capture what went well/wrong after a feature or hard fix |
| `/security-audit` | sonnet | Vulnerability scan with OWASP reference material |
| `/ansible-audit` | sonnet | Production-readiness audit for Ansible playbooks, roles, collections, molecule scenarios |
| `/commit-messages` | haiku | Generate conventional commit messages from staged diff |
| `/pr` | haiku | Create PR with title, description, test plan, linked issues |
| `/cuj` | haiku | Scaffold a new Critical User Journey document |
| `/ad` | haiku | Scaffold a new Architecture Decision Record |
| `/remember` | haiku | Save learnings/patterns to persistent memory |

## Rules

Every file in `config/rules/` deploys to `~/.claude/rules/`. Rules **without** `paths:` frontmatter load into every session; rules **with** `paths:` load only when Claude works with matching files — that keeps the always-loaded context small. (Note: the key is `paths:`, not `globs:` — Claude Code silently ignores unknown frontmatter keys and loads the rule unconditionally.)

| Rule | Loads | Topic |
|------|-------|-------|
| `code-readability.md` | code files | Naming, function size, complexity limits |
| `cujs-and-ads.md` | always | CUJ/ADR conventions, opt-out, staleness |
| `definition-of-done.md` | always | Per-project-type DoD checklists |
| `design-first.md` | always | Elephant-Goldfish Model, Goldfish-proof docs, session recovery |
| `documentation.md` | `**/*.md` | README requirements, the "litmus test" |
| `ecosystem-tools.md` | always | When to suggest TDD Guard, Trail of Bits, claude-rules-doctor |
| `git.md` | always | Commit/branch/PR conventions |
| `karpathy-principles.md` | always | Surface assumptions, surgical edits, verify-loop format |
| `languages.md` | code files | Per-language linter/test commands |
| `mcp-playwright.md` | web files | Auto-suggest Playwright MCP for web projects |
| `security.md` | always | OWASP Top 10, secret hygiene, frontend security |
| `testing.md` | test files | 80% coverage minimum, env splitting, smoke tests |

Content that only matters at specific moments lives elsewhere, loaded on demand: the SRE reliability reference moved to `skills/plan/references/reliability.md` (used by `/plan`, `reliability-engineer`, `/ansible-audit`), the quality-workflow mental model merged into `config/CLAUDE.md`, and the `/rc` + `/voice` user reference moved to `docs/reference/remote-and-voice.md`.

## Hooks

Scripts in `hooks/` deploy to `~/.claude/hooks/` (made executable on install) and are wired into `config/settings.json`.

| Hook | Trigger | Purpose |
|------|---------|---------|
| `pretooluse-bash.sh` | PreToolUse (Bash) | Dangerous-pattern scan (`rm -rf /`, force-push to main, curl-piped-to-shell, etc.) + the 5-gate commit blocker + autopilot bypass |
| `block-secrets-wrapper.sh` → `block-secrets.py` | PreToolUse (Edit/Write) | Blocks writes to `.env`, `.pem`, `.key`, `secrets/`, `.ssh/`, and other sensitive files |
| `after-edit.sh` | PostToolUse (Edit/Write) | Runs formatters/linters (gofmt, prettier, ruff, etc.) |
| `notify.sh` | Notification | macOS / Linux / WSL desktop notifications |
| `session-start-prune-markers.sh` | SessionStart (startup) | Deletes review markers older than 1h to prevent stale-marker confusion |
| `log-skill-usage.sh` | UserPromptExpansion | One-line TSV log for the long-running workflow skills |
| `pre-compact-snapshot.sh` | PreCompact (manual/auto) | Snapshots branch, HEAD, staged files, and latest plan before compaction |
| `mark-reviewed.sh` | Manual | Sets review markers (called by agents and as escape hatch) |

## Templates

Stack scaffolds and documentation templates under `templates/`.

| Template | Use For |
|----------|---------|
| `nextjs/.claude/` | Next.js 15+ App Router, Tailwind, shadcn/ui |
| `react-native/.claude/` | React Native / Expo, expo-router |
| `go-cli/.claude/` | Go CLI tools and services |
| `cuj-template.md` | Critical User Journey scaffold (use via `/cuj`) |
| `ad-template.md` | Architecture Decision Record scaffold (use via `/ad`) |
| `mcp.json.example` | Recommended MCP server set for new projects |

```bash
cp -r ~/my-claude/templates/nextjs/.claude ~/your-project/
```

## CI & Tests

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and PR:

- **shellcheck** (error severity) on `hooks/`, `scripts/`, and `install.sh`
- **`scripts/check-config.sh`** — settings.json validity + identity placeholders, rules use `paths:` (never `globs:`), skills/agents have required frontmatter, documented agent/skill counts match the filesystem
- **bats** tests in `tests/` for `pretooluse-bash.sh` — dangerous-pattern blocks, autopilot bypass, and all 5 pre-commit gates

Run locally: `bash scripts/check-config.sh` and (with bats installed) `bats tests/`.

## MCP Servers

External integrations are configured per-machine — not deployed by this repo. See [docs/mcp-setup.md](docs/mcp-setup.md) for the recommended set (`github`, `context7`).

A starter `.mcp.json` for new projects lives in `templates/mcp.json.example`.

## Plugins

Plugins are declared in `config/settings.json`, so a fresh machine gets the same set
after `make install` — no manual `/plugin install` steps to remember.

```jsonc
"enabledPlugins": {
  "pyright-lsp@claude-plugins-official": true,   // plugin-id@marketplace-id
  ...
}
```

Currently enabled (10, all first-party `@claude-plugins-official`): four language servers
(`pyright`, `typescript`, `gopls`, `rust-analyzer`), workflow tooling (`skill-creator`,
`plugin-dev`, `pr-review-toolkit`, `code-review`, `claude-md-management`), and `github`.
`anthropics/claude-plugins-community` is registered via `extraKnownMarketplaces` but
nothing is enabled from it yet.

**Versions float — pinning is not available upstream.** Marketplace entries store only
`{source, repo}`, `anthropics/claude-plugins-official` publishes no tags or releases, and
the `"version"` field on a plugin is marketplace metadata rather than a lockfile pin. So a
marketplace refresh can pull new agent and skill markdown that gets injected into
sessions. The trust model is "Anthropic-controlled repo + GitHub account integrity."
Since prevention isn't offered, the available control is detection:
`~/.claude/plugins/installed_plugins.json` records a `gitCommitSha` per plugin — diff it
across installs if you want a change signal. `playwright` is deliberately *not* enabled
for a related reason: it runs `npx @playwright/mcp@latest`, a version resolved fresh at
spawn time, and `config/rules/mcp-playwright.md` already covers per-project setup.

Enabling a plugin does **not** mint or store credentials. The `github` plugin is inert
until `GITHUB_PERSONAL_ACCESS_TOKEN` is exported; it requests no scopes of its own, so use
a fine-grained, repo-scoped PAT.

**Curation rule: prefer capabilities that don't overlap what's already here.** Skill
descriptions share a fixed context budget (see "Skill listing budget" below), and two
skills competing on the same keywords route worse than one. `security-guidance`,
`feature-dev`, `hookify`, and `commit-commands` are deliberately *not* enabled because
this repo's own `security-analyst`, `/implement`, hand-written hooks, and
`/commit-messages` already cover that ground.

To browse and add: `/plugin` (the Discover tab shows each plugin's context cost, and the
Installed tab flags anything unused for 2+ weeks — that's the pruning signal). Add the
chosen id to `enabledPlugins` so it survives a reinstall.

### Skill listing budget

Claude Code injects a listing of skill names + descriptions each turn, capped at
`skillListingBudgetFraction` (we deploy `0.02`; the default is `0.01`) of the context
window. **On overflow, descriptions are silently truncated** — a skill still looks
installed but has lost the keywords it is matched on, so it quietly stops triggering.

`scripts/check-config.sh` enforces a 2000-char ceiling on this repo's own contribution
(1% of a 200k context, so the config stays safe even off a 1M-context model). Two levers
when it's tight:

- `disable-model-invocation: true` on skills that are always typed, never inferred
  (`/autopilot`) — removes the description from the listing entirely, keeps the command.
- `"skillOverrides": {"<skill>": "off" | "name-only"}` for skills you want de-emphasized
  rather than removed.

The installer preserves `skillOverrides` entries for skills this repo doesn't own, so
externally provisioned skills stay configured across a `FORCE_UPDATE=1 make install`.

### Other ecosystem tools

Not installed — suggest when relevant:

| Tool | When relevant |
|------|---------------|
| [TDD Guard](https://github.com/nizos/tdd-guard) | Strict test-first workflow; hooks enforce red-green-refactor |
| [Trail of Bits skills](https://github.com/trailofbits/skills) | Security-critical code: auth, payments, crypto, exposed APIs |
| [claude-rules-doctor](https://github.com/nulone/claude-rules-doctor) | Rules not applying — finds `paths:` that match nothing |

## Updating

```bash
cd ~/my-claude
git pull
make install
```

The installer compares each file by SHA-256 and prompts before overwriting local divergence. Use `FORCE_UPDATE=1` to overwrite all without prompts.

## Modifying This Repo

See [.claude/CLAUDE.md](.claude/CLAUDE.md) for the project-local rules — most importantly: this repo is **public on GitHub**, so never commit secrets, personal project details, or anything from `~/.claude/projects/` (auto-memory).

After editing config:

```bash
make install                # deploy
# Start a new claude session to pick up changes
```

## Related

- [docs/GUIDE.md](docs/GUIDE.md) — Long-form reference: global CLAUDE.md, MCP, commands, skills, hooks
- [docs/mcp-setup.md](docs/mcp-setup.md) — Recommended MCP servers and install commands
- [config/PERMISSIONS-GUIDE.md](config/PERMISSIONS-GUIDE.md) — Sandbox, permissions, allow/deny semantics
