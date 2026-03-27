---
name: learnings
description: Document what went well, what went wrong, and what to do differently after completing a feature or fixing a hard bug. Compounds knowledge across sessions.
model: haiku
argument-hint: "[feature or topic]"
---

# Learnings Skill

After completing a feature, fixing a hard bug, or finishing a session, capture what you learned so future sessions benefit.

## When to Use This Skill

- After completing a feature (especially multi-session ones)
- After fixing a bug that took significant debugging
- After a `/polish` run reveals systemic issues
- User says "what did we learn?", "document learnings", "retrospective"
- Proactively when you notice a pattern worth preserving

## Process

### 1. Reflect on the Work

Review what just happened:
```bash
git log --oneline -20
git diff --stat HEAD~5..HEAD
```

Ask yourself (and the user):
- What took longer than expected? Why?
- What went surprisingly smoothly? Why?
- What would you do differently next time?
- Were there any "aha moments" about the codebase?
- Did any tools, patterns, or approaches prove especially useful or harmful?

### 2. Categorize Learnings

Sort findings into categories:

**Project quirks** — Non-obvious things about this specific codebase:
- "The auth middleware silently swallows 401s — always check the response interceptor"
- "Vitest config requires `test.projects` split for jsdom vs node environments"

**Process improvements** — Better ways to work:
- "Running /audit before starting implementation saves rework"
- "For this stack, writing E2E tests before unit tests catches more bugs"

**Tool discoveries** — Things about Claude Code, MCP, or ecosystem tools:
- "The coverage gate catches more than expected — set it early"
- "The architect-reviewer agent finds AD drift that code review misses"

**Anti-patterns** — Mistakes to avoid:
- "Don't mock the database in integration tests for this project"
- "The old API client is deprecated — always use v2"

### 3. Save to Memory

For each learning worth preserving across sessions, save it:

- **Project quirks** → save as `feedback` or `project` memory
- **Process improvements** → save as `feedback` memory
- **Tool discoveries** → save as `feedback` memory
- **Anti-patterns** → save as `feedback` memory with **Why** and **How to apply**

Use the memory system at `~/.claude/projects/*/memory/` following the standard format.

### 4. Check for Patterns

If this is the second time you've seen the same issue:
- Escalate from memory to a rule (suggest adding to `.claude/CLAUDE.md` or `config/rules/`)
- Consider if a hook could prevent it automatically
- Consider if an agent could catch it during review

## Output

```markdown
## Session Learnings

### What Went Well
- [Things that worked, with why]

### What Was Hard
- [Things that took longer, with root cause]

### Key Takeaways
- [Actionable insights for future sessions]

### Saved to Memory
- [List of memories created/updated]

### Suggested Improvements
- [Rules, hooks, or agents that could prevent issues]
```

## Examples

After a multi-session feature:
> "We spent 3 sessions on the dashboard feature. The first session was mostly debugging CORS — saved a memory about the proxy config. The second session went smoothly because we ran /plan first. The third session found 4 stale CUJs — now running /polish earlier."

After a hard bug:
> "The flaky test was caused by shared test state — the database wasn't being reset between tests. Saved anti-pattern memory: always use transaction rollback for test isolation in this project."
