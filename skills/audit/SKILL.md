---
name: audit
description: Run a full read-only audit of the current project — code review, security analysis, and documentation freshness check. Use to assess project health without making changes.
model: sonnet
argument-hint: "[focus-area]"
---

# Project Audit Skill

Run all quality agents in read-only mode against the current project. Produces a consolidated report covering code quality, security, documentation, CUJ/AD coverage, architecture, and (for web projects) UX quality.

## When to Use This Skill

- Periodic health check on a project (e.g. before a release)
- Onboarding to a new codebase — understand its current state
- After merging a large PR or completing a feature branch
- User says "audit", "review the project", "check health", "assess quality"
- Before running `/polish` (which builds on audit findings)

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

Detect project type for agent selection:
- **All projects**: code-reviewer, security-analyst, docs-updater, architect-reviewer
- **Projects with CUJs**: cuj-verifier
- **Web projects** (has package.json with frontend deps, HTML/JSX/TSX): ux-reviewer
- **Projects with test gaps**: integration-tester

If an optional `[focus-area]` argument was provided (e.g. "auth", "api", "frontend"), narrow the scope of all agents to that area.

### 2. Code Quality Review

Run the **code-reviewer** agent in read-only mode:

> Review the current codebase for code quality issues. Focus on the most-recently changed files. Do NOT modify any files — report findings only. Check for: long functions, code duplication, poor naming, missing error handling, dead code, and test coverage gaps.

Capture the output.

### 3. Security Analysis

Run the **security-analyst** agent in read-only mode:

> Perform a security assessment of this project. Do NOT modify any files — report findings only. Check for: hardcoded secrets, dependency vulnerabilities, injection risks, auth/session issues, and OWASP Top 10 patterns. Run `npm audit` / `pip-audit` / `govulncheck` / `cargo audit` as appropriate for the project type.

Capture the output.

### 3b. Architecture Review (if ADs exist)

Run the **architect-reviewer** agent in read-only mode:

> Review this project's architecture against its documented Architecture Decisions. Do NOT modify any files — report findings only. Check for: AD violations, undocumented architectural choices (new dependencies, new services, new patterns), coupling/cohesion issues, and layer violations.

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

### 5b. CUJ Verification (if CUJs exist)

Run the **cuj-verifier** agent in read-only mode:

> Walk through each documented CUJ step-by-step. Do NOT modify any files — report findings only. For each CUJ: verify the code implementing each step exists, check for matching tests, flag drift between documentation and implementation.

Capture the output.

### 5c. Integration Test Coverage

Run the **integration-tester** agent in read-only mode:

> Assess integration test coverage for this project. Do NOT modify any files — report findings only. Identify user flows, API endpoints, and cross-component interactions that lack integration or E2E tests. Cross-reference with CUJs if they exist.

Capture the output.

### 5d. UX Review (web projects only)

If the project has frontend files (JSX, TSX, Vue, Svelte, HTML), run the **ux-reviewer** agent in read-only mode:

> Review the UI quality of this web project. Do NOT modify any files — report findings only. Check for: missing loading/empty/error states, accessibility issues (WCAG 2.1 AA), responsive design gaps, form validation quality, and navigation completeness.

Capture the output.

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

## Architecture (if ADs exist)

| AD | Status | Findings |
|----|--------|----------|
| [title] | ✅ Compliant / ⚠️ Drift / ❌ Violated | [detail] |

[Structural health: coupling, cohesion, layering]
[Missing ADs for undocumented decisions]

## CUJ & AD Coverage

| Type | Count | Fresh | Stale (>90d) | Deprecated |
|------|-------|-------|-------------|------------|
| CUJs | N | N | N | N |
| ADs  | N | N | N | N |

### CUJ Verification (if verified)

| CUJ | Status | Steps Verified | Test Coverage |
|-----|--------|---------------|---------------|
| [name] | ✅/⚠️/❌ | N/total | Has tests: ✅/❌ |

[Specific findings: uncovered flows, stale entries, doc/code drift]

## Integration Test Coverage

| Flow | Type | Has Tests | Gap |
|------|------|-----------|-----|
| [flow] | E2E/API/Component | ✅/❌ | [what's missing] |

## UX Quality (web projects only)

| Area | Quality | Issues |
|------|---------|--------|
| UI States | 🟢/🟡/🔴 | [count] |
| Accessibility | 🟢/🟡/🔴 | [count] |
| Responsive | 🟢/🟡/🔴 | [count] |
| Forms | 🟢/🟡/🔴 | [count] |

## Priority Actions

1. [Highest priority item — what, where, why]
2. [Second priority]
3. [Third priority]
```

## Output

Present the consolidated report. End with:
- The top 3 priority actions
- Whether any findings would block a release
- Suggested next step (e.g. "run `/polish` to fix findings" or "run `/implement` to address #1")
