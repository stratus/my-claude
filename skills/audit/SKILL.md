---
name: audit
description: Run a full read-only audit of the current project — code review, security analysis, and documentation freshness check. Use to assess project health without making changes.
model: sonnet
argument-hint: "[focus-area]"
---

# Project Audit Skill

Run all quality agents in read-only mode against the current project. Produces a consolidated report covering code quality, security posture, and documentation freshness.

## When to Use This Skill

- Periodic health check on a project (e.g. before a release)
- Onboarding to a new codebase — understand its current state
- After merging a large PR or completing a feature branch
- User says "audit", "review the project", "check health", "assess quality"

## Process

### 1. Project Reconnaissance

Before running agents, gather context:

```bash
# Understand the project
git log --oneline -10
git diff --stat HEAD~10..HEAD 2>/dev/null || git diff --stat --cached
```

Identify:
- Primary language(s) and framework(s)
- Number of recent contributors
- Velocity of recent changes
- Whether a `.claude/CLAUDE.md` exists

If an optional `[focus-area]` argument was provided (e.g. "auth", "api", "frontend"), narrow the scope of all three agents to that area.

### 2. Code Quality Review

Run the **code-reviewer** agent in read-only mode:

> Review the current codebase for code quality issues. Focus on the most-recently changed files. Do NOT modify any files — report findings only. Check for: long functions, code duplication, poor naming, missing error handling, dead code, and test coverage gaps.

Capture the output.

### 3. Security Analysis

Run the **security-analyst** agent in read-only mode:

> Perform a security assessment of this project. Do NOT modify any files — report findings only. Check for: hardcoded secrets, dependency vulnerabilities, injection risks, auth/session issues, and OWASP Top 10 patterns. Run `npm audit` / `pip-audit` / `govulncheck` / `cargo audit` as appropriate for the project type.

Capture the output.

### 4. Documentation Freshness Check

Run the **docs-updater** agent in read-only mode:

> Audit the documentation in this project for staleness. Do NOT modify any files — report findings only. Compare README, docs/, and inline documentation against the current code. Flag: missing setup instructions, outdated examples, undocumented features, broken links, and stale architecture docs.

Capture the output.

### 5. CUJ & Architecture Decision Coverage

Check the project's Critical User Journeys and Architecture Decisions:

**Existence:**
- Check if `docs/cujs/` exists. If `.opted-out` sentinel present, report "Opted out" (neutral). If missing with no sentinel, flag as "Missing — not documented and not explicitly opted out".
- Check if `docs/decisions/` exists. Same logic.
- Scan for non-standard locations (`docs/architecture.md`, `docs/adr/`, `docs/adrs/`, `docs/architecture-decisions/`, `DECISIONS.md`, `docs/user-journeys/`, `docs/flows/`, `docs/use-cases/`) and flag with migration suggestion.

**Freshness:**
- For each CUJ file: check `last-verified` in frontmatter. Flag if older than 90 days.
- For each AD file: check `date` in frontmatter. Flag if older than 90 days.
- Note any with `status: deprecated` or `status: superseded` (informational, not a finding).

**Coverage:**
- Do major code modules/features have at least one CUJ? Look at route handlers, pages, CLI commands — these suggest user flows.
- Are there ADs with `status: accepted` that reference components no longer in the codebase?
- Are there recent architectural changes (new dependencies, new services, new integration patterns) without a corresponding AD?

Capture findings for the consolidated report.

### 6. Consolidated Report

Combine findings into a single structured report:

```markdown
# Project Audit Report

**Project:** [name]
**Date:** [date]
**Scope:** [full project or focus-area]

## Executive Summary

[2-3 sentences: overall health, biggest risks, top priorities]

## Code Quality

| Severity | Count |
|----------|-------|
| Critical | N |
| Important | N |
| Suggestions | N |

[Top findings with file:line references]

## Security

| Severity | Count |
|----------|-------|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |

[Top findings with remediation steps]

## Documentation

| Status | Area |
|--------|------|
| Current / Stale / Missing | README |
| Current / Stale / Missing | API docs |
| Current / Stale / Missing | Setup guide |
| Current / Stale / Missing | Architecture |
| Current / Stale / Missing / Opted-out | Critical User Journeys |
| Current / Stale / Missing / Opted-out | Architecture Decisions |

[Specific gaps and recommendations]

## CUJ & AD Coverage

| Type | Count | Fresh | Stale (>90d) | Deprecated |
|------|-------|-------|-------------|------------|
| CUJs | N | N | N | N |
| ADs  | N | N | N | N |

[Specific findings: uncovered flows, stale entries, superseded-but-not-replaced ADs, non-standard locations detected]

## Priority Actions

1. [Highest priority item — what, where, why]
2. [Second priority]
3. [Third priority]
```

## Output

Present the consolidated report. End with:
- The top 3 priority actions
- Whether any findings would block a release
- Suggested next step (e.g. "run `/implement` to address finding #1")
