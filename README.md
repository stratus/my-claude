# my-claude

Personal Claude Code configuration repository. Deploys global standards, agents, skills, hooks, and rules to `~/.claude/`.

## Overview

This repo is the source of truth for a Claude Code setup that emphasizes:

- **Quality ratchets** — pre-commit gate with 5 blocking checks (review, security, tests, coverage, docs)
- **Specialized agents** — 10 sub-agents for code review, security, debugging, integration testing, architecture, UX, and more
- **Workflow skills** — `/plan` → `/implement` → `/polish` covers most of a feature lifecycle
- **Auto-loaded rules** — modular guidance under `~/.claude/rules/` instead of one monolithic CLAUDE.md
- **Reusable templates** — Next.js, React Native, Go CLI, plus CUJ/ADR/MCP scaffolds

## Prerequisites

- **macOS or Linux** — installer uses BSD `sed -i ''` on macOS; pre-commit gate handles both BSD and GNU `date`.
- **bash 4+ recommended** (bash 3.2 on macOS works but lacks some features the inner skills assume)
- **`jq`** — required by `block-dangerous-commands.sh`, `pre-commit-gate.sh`, `notify.sh`, `after-edit.sh`
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
git clone git@github.com:stratus/my-claude.git ~/my-claude
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

## Repository Structure

```
my-claude/
├── config/                       # Source of truth — deploys to ~/.claude/
│   ├── CLAUDE.md                 # Global standards (concise, points at rules/)
│   ├── PERMISSIONS-GUIDE.md      # Permissions and sandbox notes
│   ├── settings.json             # Hooks, permissions, sandbox config
│   ├── rules/*.md                # Auto-loaded rule files
│   ├── agents/*.md               # 10 sub-agent definitions
│   └── statusline/               # Statusline wrapper + Config.toml
├── skills/<name>/SKILL.md        # 12 slash-command skills → ~/.claude/commands/
├── hooks/*.sh                    # Event hooks → ~/.claude/hooks/ (chmod +x)
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
├── Makefile                      # install / clean / help
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
| `ux-reviewer` | sonnet | Loading/empty/error states, a11y, responsive design |
| `react-frontend` | sonnet | React 19, Zustand, React Flow, Tailwind v4 |
| `python-backend` | sonnet | FastAPI, async, Temporal, SQLAlchemy, Pydantic |

Most agents dispatch automatically from `/audit` and `/polish`.

## Skills (Slash Commands)

Each skill is a directory under `skills/` with a `SKILL.md`. Deployed to `~/.claude/commands/<name>/`.

| Skill | Model | Purpose |
|-------|-------|---------|
| `/plan` | opus | Interview, design phased approach, produce implementation plan |
| `/egm` | opus | Goldfish Protocol — verify design doc completeness before implementing |
| `/implement` | opus | Phased execution with quality gates after planning |
| `/audit` | sonnet | Read-only health report (code, security, docs, CUJ/AD) |
| `/polish` | opus | Fix audit findings, walk DoD, score 0-100, save learnings |
| `/learnings` | haiku | Capture what went well/wrong after a feature or hard fix |
| `/security-audit` | sonnet | Vulnerability scan with OWASP reference material |
| `/commit-messages` | haiku | Generate conventional commit messages from staged diff |
| `/pr` | haiku | Create PR with title, description, test plan, linked issues |
| `/cuj` | haiku | Scaffold a new Critical User Journey document |
| `/ad` | haiku | Scaffold a new Architecture Decision Record |
| `/remember` | haiku | Save learnings/patterns to persistent memory |

## Rules (Auto-Loaded)

Every file in `config/rules/` deploys to `~/.claude/rules/` and is loaded into every session. Split out from CLAUDE.md to keep the system prompt small while still authoritative on specific topics.

| Rule | Topic |
|------|-------|
| `code-readability.md` | Naming, function size, complexity limits |
| `cujs-and-ads.md` | CUJ/ADR conventions, opt-out, staleness |
| `definition-of-done.md` | Per-project-type DoD checklists |
| `documentation.md` | README requirements, the "litmus test" |
| `ecosystem-tools.md` | When to suggest TDD Guard, Trail of Bits, claude-rules-doctor |
| `git.md` | Commit/branch/PR conventions |
| `design-first.md` | Elephant-Goldfish Model, Goldfish-proof docs, session recovery |
| `karpathy-principles.md` | Surface assumptions, surgical edits, verify-loop format |
| `languages.md` | Per-language linter/test commands |
| `mcp-playwright.md` | Auto-suggest Playwright MCP for web projects |
| `quality-workflow.md` | Mental model: `/plan` → `/implement` → `/polish` |
| `remote-and-voice.md` | `/rc` and `/voice` features |
| `security.md` | OWASP Top 10, secret hygiene, frontend security |
| `testing.md` | 80% coverage minimum, env splitting, smoke tests |

## Hooks

Scripts in `hooks/` deploy to `~/.claude/hooks/` (made executable on install) and are wired into `config/settings.json`.

| Hook | Trigger | Purpose |
|------|---------|---------|
| `block-secrets.py` | PreToolUse (Read/Edit/Write) | Blocks access to `.env`, `.pem`, `.key`, `secrets/`, `.ssh/`, and other sensitive files |
| `block-dangerous-commands.sh` | PreToolUse (Bash) | Blocks `rm -rf /`, force-push to main, curl-piped-to-shell, chmod 777, dd-to-disk, etc. |
| `pre-commit-gate.sh` | PreToolUse (Bash, `git commit`) | Enforces the 5 gates |
| `after-edit.sh` | PostToolUse (Edit/Write) | Runs formatters/linters (gofmt, prettier, ruff, etc.) |
| `end-of-turn.sh` | Stop | Non-blocking quality reminders (lint, typecheck, format, secret-scan) |
| `notify.sh` | Notification | macOS / Linux / WSL desktop notifications |
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

## MCP Servers

External integrations are configured per-machine — not deployed by this repo. See [docs/mcp-setup.md](docs/mcp-setup.md) for the recommended set (`github`, `context7`).

A starter `.mcp.json` for new projects lives in `templates/mcp.json.example`.

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
