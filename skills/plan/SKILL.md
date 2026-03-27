---
name: plan
description: Enter planning mode — interview the user, design a phased approach, and produce an implementation plan before writing code.
model: sonnet
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

### 2. Research the Codebase
- Explore relevant files and dependencies
- Identify existing patterns to follow
- Note potential conflicts or breaking changes
- Check for existing tests and documentation

### 3. Design the Approach
Break into **phases** with clear boundaries:

```
## Phase 1: [Foundation]
- What to build
- Files to create/modify
- Tests to add
- Acceptance criteria

## Phase 2: [Core Feature]
...

## Phase 3: [Polish & Docs]
...
```

### 4. Review Checklist
For each phase, verify:
- [ ] Tests defined (unit + integration)
- [ ] No security concerns
- [ ] Follows existing code patterns
- [ ] Documentation updates identified
- [ ] Can be demoed/verified independently

## Output

Present the plan and ask: "Does this plan look right? Should I adjust anything before we start Phase 1?"

Do NOT start implementation until the user approves.
