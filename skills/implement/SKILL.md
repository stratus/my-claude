---
name: implement
description: Start implementing a feature with user story validation, phased execution, and quality gates. Use after planning is complete.
model: opus
argument-hint: "[feature description or phase number]"
---

# Implementation Skill

Execute a planned feature with quality gates at each step.

## When to Use This Skill

- User says "implement", "build", "start coding"
- After a plan has been approved
- Starting a new phase of an existing plan

## Process

### 1. Pre-flight Check
Before writing code, verify:
- [ ] User story exists: "As a [user type], I can [action] so that [outcome]"
- [ ] Acceptance criteria defined
- [ ] Plan approved (if complex task)
- [ ] Branch created (if not on a feature branch)

If any are missing, ask the user before proceeding.

### 1b. CUJ-Driven Acceptance Criteria

Check if `docs/cujs/` exists and is not opted out. If CUJs exist:

1. Search for CUJs whose content mentions the feature being implemented
2. For each matching CUJ, extract its **Success Criteria** and **Error Paths**
3. Use these as additional acceptance criteria for the implementation:
   - Success Criteria → must-pass assertions in integration tests
   - Error Paths → must-handle error cases with proper UX
4. If implementing a wholly new user flow with no matching CUJ, suggest creating one:
   > "This feature introduces a new user flow that isn't documented as a CUJ. Want me to scaffold one with `/cuj`?"

### 1c. AD Compliance Check

Check if `docs/decisions/` exists and is not opted out. If ADs exist:

1. Search for ADs relevant to the feature (matching technology, component, or pattern)
2. Verify the planned implementation aligns with accepted decisions
3. If the plan contradicts an AD, **stop and flag it** before writing code:
   > "This implementation would use [X], but AD [number] chose [Y] because [reason]. Should we proceed anyway or create a new AD to supersede it?"

### 2. Execute Phase
For each phase:
1. Write the code (follow existing patterns, respect ADs)
2. Write tests alongside implementation (including CUJ-derived acceptance tests)
3. Run tests and linter
4. Verify acceptance criteria (both explicit and CUJ-derived)

While writing code, hold to two rules from `rules/karpathy-principles.md`:
- **Every changed line traces to the request.** If a line in your diff doesn't map to the user story or acceptance criteria, revert it.
- **Match existing style.** Don't "improve" adjacent code or refactor things that aren't broken — if you spot dead code or smells outside scope, mention them and move on.

If the plan's phase steps weren't already in `step → verify: check` format, restate them that way before executing — it makes "phase done" objective instead of vibes.

### 3. Quality Gate
After each phase, check:
- [ ] Tests pass
- [ ] Coverage >= 80%
- [ ] No linter errors
- [ ] No security issues introduced
- [ ] Code follows project conventions

After passing the quality gate, set review markers so the pre-commit gate allows the commit:
```bash
~/.claude/hooks/mark-reviewed.sh --tests
~/.claude/hooks/mark-reviewed.sh --coverage <percentage>
```

### 4. Checkpoint
After passing the quality gate:
- Suggest committing the phase
- Summarize what was done
- Preview next phase (if applicable)

## Output

After implementation:
```
Phase [N] complete:
- [summary of changes]
- Tests: [pass/fail count]
- Coverage: [percentage]
- Next: [what comes next or "ready for review"]
```
