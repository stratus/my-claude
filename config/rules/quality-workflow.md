---
description: Quality workflow decision tree — guides which skills and agents to use at each stage
globs: "**/*"
---

# Quality Workflow

Decision tree for maintaining quality throughout the development lifecycle.

## Before Starting Work

```
Is this a new feature or significant change?
├── Yes → /plan (sonnet) — design phases, check CUJs/ADs
│   └── Does it need a new CUJ? → /cuj to scaffold
│   └── Does it need a new AD? → /ad to scaffold
└── No (bug fix, small change) → proceed directly
```

## During Implementation

```
Use /implement after plan is approved
├── Each phase: write code + tests together
├── Quality gate after each phase (tests, coverage, lint)
└── Set markers: mark-reviewed.sh --tests --coverage <pct>
```

## Before Committing

```
How big is the change?
├── >20 lines or security-sensitive → run code-reviewer agent
│   ├── Security files? → also run security-analyst agent
│   └── User-facing? → also run docs-updater agent
├── <20 lines, non-security → run tests and linter only
│   └── Set markers manually: mark-reviewed.sh --tests --coverage <pct>
└── Pre-commit gate enforces all 5 gates automatically
```

## Before Releasing

```
Run /polish (opus) — the quality ceiling
├── Dispatches: audit + cuj-verifier + architect-reviewer + integration-tester + ux-reviewer
├── Actively fixes findings
├── Walks Definition of Done checklist
├── Generates readiness score 0-100
└── Score >= 80? Ship it. Score < 80? Fix priority items first.
```

## After Completing Work

```
Run /learnings — compound knowledge
├── What went well?
├── What was hard?
├── Save to memory for future sessions
└── Suggest process improvements (new rules, hooks, agents)
```

## Agent Selection Guide

| Situation | Agent | Model |
|-----------|-------|-------|
| Code changed | `code-reviewer` | sonnet |
| Security files changed | `security-analyst` | sonnet |
| Docs need updating | `docs-updater` | haiku |
| Something is broken | `debug-specialist` | sonnet |
| Need integration/E2E tests | `integration-tester` | sonnet |
| Verify CUJs still work | `cuj-verifier` | sonnet |
| Cross-component changes | `architect-reviewer` | opus |
| Web UI quality check | `ux-reviewer` | sonnet |
| React/frontend work | `react-frontend` | sonnet |
| Python/FastAPI work | `python-backend` | sonnet |
