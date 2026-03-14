---
name: implement
description: Start implementing a feature with user story validation, phased execution, and quality gates. Use after planning is complete.
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

### 2. Execute Phase
For each phase:
1. Write the code (follow existing patterns)
2. Write tests alongside implementation
3. Run tests and linter
4. Verify acceptance criteria

### 3. Quality Gate
After each phase, check:
- [ ] Tests pass
- [ ] Coverage >= 80%
- [ ] No linter errors
- [ ] No security issues introduced
- [ ] Code follows project conventions

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
