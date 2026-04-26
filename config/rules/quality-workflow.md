---
description: Quality workflow decision tree — guides which skills and agents to use at each stage
globs: "**/*"
---

# Quality Workflow

Simple mental model — **you invoke 3 things max**, the system handles the rest:

```
/plan → /implement → /polish
```

Everything else (agents, markers, gates, learnings) is automatic.

## When to Use What

| You want to... | Use | What happens automatically |
|----------------|-----|--------------------------|
| Design a feature | `/plan` | Checks CUJs/ADs, designs phases |
| Build the feature | `/implement` | Writes code + tests, sets markers per phase |
| Check health (quick, read-only) | `/audit` | Dispatches up to 7 agents, produces report |
| Ship it (active fixes) | `/polish` | Fixes findings, walks DoD, scores 0-100, saves learnings |

**You don't need to remember**: running agents (code-reviewer runs automatically for >20 lines), setting markers (agents set them), capturing learnings (`/polish` does it), or checking CUJs/ADs (`/plan` and `/implement` do it).

## What Runs Automatically

**Pre-commit gate** (5 blocking gates — runs on every `git commit`):
1. Code review for >20 lines
2. Security review for sensitive files
3. Tests must pass
4. Coverage must meet 80%
5. Docs review for user-facing changes

**Code-reviewer agent** checks project memory for past lessons before reviewing.

**Escape hatch**: `mark-reviewed.sh --all` when you consciously choose to skip gates.

## Agent Selection Guide

Most agents are dispatched automatically by `/audit` and `/polish`. If you need one directly:

| Situation | Agent | Model |
|-----------|-------|-------|
| Code changed | `code-reviewer` | opus |
| Security files changed | `security-analyst` | opus |
| Docs need updating | `docs-updater` | haiku |
| Something is broken | `debug-specialist` | opus |
| Need integration/E2E tests | `integration-tester` | sonnet |
| Verify CUJs still work | `cuj-verifier` | sonnet |
| Cross-component changes | `architect-reviewer` | opus |
| Web UI quality check | `ux-reviewer` | sonnet |
| React/frontend work | `react-frontend` | sonnet |
| Python/FastAPI work | `python-backend` | sonnet |
