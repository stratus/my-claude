# Global Development Standards

Standards for ALL projects unless overridden by project-specific `.claude/CLAUDE.md`.
Detailed rules auto-load from `~/.claude/rules/`.

---

## Workflow After Code Changes

For changes **>20 lines or touching security/validation**:
1. Run `code-reviewer` agent (sonnet) — marks code review + tests + coverage done
2. If security-sensitive files changed: run `security-analyst` agent — marks security done
3. Run `docs-updater` agent (haiku) → For user-facing changes — marks docs done
4. Commit — the **pre-commit gate enforces all 5 gates**

For **small changes (<20 lines, non-security)**: Run tests and linter, set markers manually.

**Pre-commit gate** (5 blocking gates):
1. Code review (>20 lines changed)
2. Security review (sensitive files)
3. Tests must pass
4. Coverage must meet 80%
5. Docs review (user-facing changes)

Markers expire after 10 minutes. If blocked, follow the error message instructions.
Use `~/.claude/hooks/mark-reviewed.sh --all` as escape hatch when consciously skipping.

## New Project Setup

If project lacks `.claude/CLAUDE.md`: **ASK** user to create one before coding.

Before implementing any feature, confirm:
- User story exists: "As a [user type], I can [action] so that [outcome]"
- Acceptance criteria are defined (how to manually verify it works)
- CUJs and ADs are documented (or explicitly opted out) — see `cujs-and-ads` rule
- **Web projects**: Playwright MCP is configured in `.mcp.json` — see `mcp-playwright` rule

## Core Principles

1. **Security First** - Non-negotiable
2. **Test Everything** - 80% minimum coverage
3. **Document Changes** - Keep docs current
4. **User-Verifiable** - If you can't demo it, it's not done
5. **Readable Code** - Self-documenting preferred
6. **Track with Git** - Atomic commits, clear messages
7. **Behavioral Discipline** - Surface assumptions, match existing style, every changed line traces to the request, plans use `step → verify: check`. See `rules/karpathy-principles.md`.

## Token Optimization

- **Use `model: "haiku"`** for simple agent tasks (searches, formatting, straightforward generation)
- **Prefer Glob/Grep** over Explore agent for simple file/code searches
- **Use `/clear`** between unrelated tasks
- **Use `/compact`** when context grows large but continuity needed
- Suggest these commands proactively when appropriate

## Agent Usage

| Agent | When to Use | Model |
|-------|-------------|-------|
| `code-reviewer` | After code changes >20 lines or security-related | sonnet |
| `docs-updater` | After code review, for user-facing changes | haiku |
| `debug-specialist` | Errors, test failures, unexpected behavior | sonnet |
| `integration-tester` | When unit tests aren't enough — E2E, API, cross-component tests | sonnet |
| `cuj-verifier` | Verify documented CUJs actually work, catch doc/code drift | sonnet |
| `architect-reviewer` | Cross-component changes, new deps, AD compliance | opus |
| `ux-reviewer` | Web projects: loading/empty/error states, a11y, responsive | sonnet |

**Skip agents** for trivial changes (<20 lines, non-security, no user-facing impact).

Most agents are dispatched automatically by `/audit` and `/polish` — you rarely need to invoke them directly.

**Simple workflow**: `/plan` → `/implement` → `/polish`. Everything else is automatic.

## Memory & Learning

Claude Code has persistent auto memory at `~/.claude/projects/*/memory/`.

- **Proactively** write memories after solving hard bugs, discovering project quirks, or learning environment gotchas
- **On request** when user says "remember this" (use `/remember` skill)
- **After repeated patterns** — if you've seen the same issue twice, write it down
- MEMORY.md is the index (200-line limit), use topic files for detail
- Never store secrets, session-specific context, or info already in docs

## Pre-Completion Review

Before declaring any feature/task complete:
1. **User perspective**: How would someone who's never seen this verify it works?
2. **Docs check**: Are all new/changed features reflected in documentation?
3. **CUJ/AD check**: Are Critical User Journeys and Architecture Decisions still current?
4. **Demo ready**: Can you walk through the primary use case right now?

If uncertain on any point, **ask the user** rather than assuming complete.

## Context Hygiene

**Proactively suggest**:
- `/clear` - When task complete or switching to unrelated task
- `/compact` - When context large but need continuity

**Describe** what would be preserved when suggesting `/compact`.

## Project Overrides

- `./.claude/CLAUDE.md` - Project-specific guidelines
- `./CLAUDE.local.md` - Personal preferences (gitignored)

## Shell Execution Gotchas

- **Never pipe Node.js CLI output** (vitest, tsc, eslint) through `tail`, `head`, or `tee` — they hang due to SIGPIPE/buffer issues. Redirect to files instead
- **Never run multiple vitest/jest instances concurrently** — they share cache directories and can deadlock
- When a long-running command seems stuck, check for stale background processes before retrying
