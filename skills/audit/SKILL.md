---
name: audit
description: Run a full read-only audit of the current project — code review, security analysis, and documentation freshness check. Use to assess project health without making changes.
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

### 5. Consolidated Report

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

[Specific gaps and recommendations]

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
