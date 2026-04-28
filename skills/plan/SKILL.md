---
name: plan
description: Enter planning mode — interview the user, design a phased approach, and produce an implementation plan before writing code.
model: opus
argument-hint: "[feature or task description]"
---

# Planning Skill

Create a structured implementation plan before writing any code.

## When to Use This Skill

- Starting a new feature or significant change
- User says "plan", "design", "how should we", "think through"
- Complex tasks requiring multiple files or components
- Before any change touching >3 files

## Process

### 1. Understand the Goal
If the task description is vague, interview the user using questions:
- What problem does this solve?
- Who is the user/consumer?
- What does "done" look like?
- Are there constraints (performance, compatibility, deadlines)?

### 1b. Interrogation Phase

Before researching the codebase, interrogate the problem as an adversarial peer reviewer.
This is the "Victory Loves Preparation" step from Dave Rensin's Elephant-Goldfish Model:

- What could go wrong with the obvious approach?
- What assumptions are embedded in the problem statement?
- What alternatives exist, and why might they be better?
- What would a skeptical colleague say about this plan?

The goal is to surface blind spots *before* committing to an approach. Do not let AI
agreement substitute for clarity. Push back on convenient answers. If the request is
genuinely unambiguous and the approach clear, this step is brief — but always ask once.

### 2. Research the Codebase
- Explore relevant files and dependencies
- Identify existing patterns to follow
- Note potential conflicts or breaking changes
- Check for existing tests and documentation

### 2b. Check CUJs and ADs

Before designing, check if existing documentation constrains or informs the plan:

**CUJs** (`docs/cujs/`):
- Does this feature touch an existing CUJ? If so, the CUJ's Success Criteria become acceptance criteria.
- Does this feature create a new user flow? If so, plan to create a CUJ in the Polish phase.

**ADs** (`docs/decisions/`):
- Does this feature involve a technology choice covered by an accepted AD? If so, follow the decision.
- Does this feature require a new architectural decision (new dependency, new service, new pattern)? If so, plan to create an AD in Phase 1 before implementation.

If the feature contradicts an accepted AD, flag it immediately:
> "This plan would use [X], but AD [number] chose [Y] because [reason]. Should we create a new AD to supersede it?"

### 3. Design the Approach
Break into **phases** with clear boundaries. Inside each phase, write steps in **verify-loop format** (`step → verify: check`) so success is checkable, not aspirational. See `rules/karpathy-principles.md`.

```
## Phase 1: [Foundation]
- What to build
- Files to create/modify
- Steps:
  1. [step] → verify: [check]
  2. [step] → verify: [check]
- Tests to add
- Acceptance criteria

## Phase 2: [Core Feature]
...

## Phase 3: [Polish & Docs]
...
```

Weak verify clauses ("make it work") are a smell — replace them with concrete checks (a passing test, a curl response, a screenshot, a log line).

### 4. Review Checklist
For each phase, verify:
- [ ] Tests defined (unit + integration)
- [ ] No security concerns
- [ ] Follows existing code patterns
- [ ] Respects accepted Architecture Decisions
- [ ] Documentation updates identified
- [ ] CUJ impacts assessed (new CUJ needed? existing CUJ to update?)
- [ ] Can be demoed/verified independently

### 5. Session Recovery Block

Every plan must end with a **Session Recovery** block so a fresh session can resume without
reconstructing intent from conversation history:

```
## Session Recovery
- Design doc / plan file: [path]
- Key decisions: [2-3 bullets]
- Rejected alternatives: [brief list]
- Resume by: running /implement with this doc
```

### 6. Goldfish Test

After writing the plan, instruct the user to run `/egm` to verify the document is
Goldfish-proof — that a blank-slate session reading only this doc could reconstruct and
execute the plan. `/egm` is a separate skill the user runs; this step does not invoke it.

Do not start `/implement` until the user confirms `/egm` passed, or explicitly waives
the check for a simple task.

## Output

Present the plan and ask: "Does this plan look right? Should I adjust anything before we start Phase 1?"

Do NOT start implementation until the user approves.
