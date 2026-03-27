---
name: polish
description: Take a project from "it works" to "it's shippable." Runs audit, fixes findings, walks the Definition of Done checklist, and generates a release readiness score. Use before releasing, after feature-complete, or when quality feels prototype-y.
model: opus
argument-hint: "[project-type: web|cli|infra]"
---

# Polish Skill

The opposite of `/plan`. Instead of "what should we build?", this asks "is this actually done?" Takes a working project and brings it to v1 quality.

## When to Use This Skill

- Before a release or demo
- After feature-complete, when the project "works but feels rough"
- User says "polish", "ship it", "are we done?", "make this production-ready"
- After multiple sessions where quality may have drifted

## Process

### 1. Run Project Audit + Specialized Reviews

First, get a comprehensive health report using multiple specialized agents:

> Run the `/audit` skill to produce a full project health report covering code quality, security, documentation, and CUJ/AD coverage. Capture all findings.

Then dispatch specialized agents as appropriate:
- **`cuj-verifier`** — Walk through every documented CUJ step-by-step and verify it works
- **`architect-reviewer`** — Check AD compliance and structural health
- **`integration-tester`** — Identify flows lacking integration/E2E tests and write them
- **`ux-reviewer`** (web projects only) — Check loading/empty/error states, accessibility, responsive design

These agents run in addition to the audit's code-reviewer, security-analyst, and docs-updater.

### 2. Fix Findings (Not Just Report)

For each finding from the audit, categorize and act:

**Auto-fix** (do these without asking):
- Code quality issues → refactor (long functions, dead code, poor naming)
- Missing tests for existing code → write them
- Stale documentation → update to match current code
- Missing CUJs for obvious user flows → scaffold via `/cuj` and fill in
- Missing ADs for significant dependencies → scaffold via `/ad` and fill in
- Linter/formatter issues → fix and format
- Missing error handling → add appropriate handling

**Requires human decision** (present these, don't auto-fix):
- Architectural changes or breaking changes
- Ambiguous requirements or unclear user flows
- Security findings that need design decisions
- Trade-offs between competing approaches

### 3. Walk the Definition of Done

Load the Definition of Done checklist and evaluate **every applicable item**:

**All Projects** (always check):
- [ ] README enables clone-to-running in <5 minutes
- [ ] A new engineer can understand what it does and how to use it
- [ ] All documented commands/steps actually work
- [ ] Error messages are actionable

**Web Applications** (if project has package.json with frontend deps, HTML/CSS/JSX/TSX files):
- [ ] Core user flows work end-to-end
- [ ] Basic UI states handled: loading, empty, error, success
- [ ] Can demonstrate the happy path manually in browser
- [ ] Forms have validation with user-visible feedback
- [ ] Navigation between features works

**CLI Tools / Libraries** (if project has a CLI entry point or is a library):
- [ ] `--help` output is accurate and useful
- [ ] At least one realistic usage example in README
- [ ] Exit codes are meaningful (0 = success, non-zero = failure)
- [ ] Errors print to stderr, output to stdout

**Infrastructure / Automation** (if project has IaC, CI/CD, or automation scripts):
- [ ] Runbook or operational doc exists for non-obvious operations
- [ ] Failure modes documented
- [ ] Dependencies and prerequisites explicitly listed

For each failing item, **fix it** if auto-fixable, or flag it for human decision.

### 4. Verify CUJ Integration Test Coverage

For each CUJ in `docs/cujs/`:
1. Read the CUJ's Steps and Success Criteria
2. Search for test files that exercise the described flow (grep for key terms, route names, component names)
3. If no matching test exists → write an integration or E2E test that covers the CUJ's happy path
4. If a test exists but doesn't cover error paths from the CUJ → extend it

The goal: every documented user journey should have at least one test proving it works.

### 5. Verify AD Consistency

For each accepted AD in `docs/decisions/`:
1. Read the Decision section
2. Verify the decision is reflected in the current codebase:
   - If AD says "use library X" → check it's in dependencies
   - If AD says "use pattern Y" → check the pattern is followed
   - If AD says "avoid Z" → check Z isn't used
3. Flag contradictions where code has drifted from the decision
4. For superseded ADs, verify the replacement AD exists

### 6. README Clone-to-Running Verification

Walk through the README setup steps mentally (or actually):
1. Are prerequisites listed and correct?
2. Do installation commands work?
3. Are environment variables documented?
4. Is there a working "quick start" example?
5. Does the development setup section work?

Fix any issues found. If a step is unclear or broken, rewrite it.

### 7. Set All Review Markers

After all fixes are applied and verified:

```bash
~/.claude/hooks/mark-reviewed.sh --all
```

This clears all pre-commit gates so the polished code can be committed.

### 8. Generate Release Readiness Score

Score the project 0-100 based on these weighted criteria:

| Criteria | Points | How to Score |
|----------|--------|-------------|
| Tests pass | 20 | All tests green = 20, some failures = 0 |
| Coverage >= 80% | 15 | >=80% = 15, 60-79% = 8, <60% = 0 |
| No critical security findings | 20 | None = 20, medium only = 10, critical = 0 |
| Documentation current | 15 | README + API docs current = 15, partially = 8, stale = 0 |
| CUJs documented + tested | 10 | All CUJs have tests = 10, some = 5, none = 0 |
| ADs documented + consistent | 10 | All ADs match code = 10, some drift = 5, contradictions = 0 |
| Definition of Done checklist | 10 | All items pass = 10, most pass = 5, many fail = 0 |

## Output

Present a structured release readiness report:

```markdown
## Release Readiness: [SCORE]/100

### Recommendation
[🟢 Ship it | 🟡 Fix N items first | 🔴 Not ready — significant gaps]

### Fixes Applied
- [List each auto-fix made with file:line references]

### Remaining (Requires Human Decision)
- [Items that need human judgment, with context for the decision]

### Definition of Done
| Item | Status | Notes |
|------|--------|-------|
| [each checklist item] | ✅/❌ | [detail if failing] |

### CUJ Coverage
| CUJ | Has Tests | Coverage |
|-----|-----------|----------|
| [name] | ✅/❌ | [test file reference or "MISSING"] |

### AD Consistency
| AD | Consistent | Notes |
|----|-----------|-------|
| [title] | ✅/❌ | [drift description if any] |

### Score Breakdown
| Criteria | Points | Max |
|----------|--------|-----|
| Tests pass | N | 20 |
| Coverage | N | 15 |
| Security | N | 20 |
| Documentation | N | 15 |
| CUJ coverage | N | 10 |
| AD consistency | N | 10 |
| Definition of Done | N | 10 |
| **Total** | **N** | **100** |
```

End with the top 3 priority items if the score is below 80, or "Ready to ship!" if >= 80.
