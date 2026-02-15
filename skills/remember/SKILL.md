---
name: remember
description: Save learnings, patterns, and preferences to persistent memory. Use when the user says "remember this", encounters a hard-won fix, or wants to preserve context across sessions.
---

# Remember Skill

Save information to persistent auto memory so it's available in future sessions.

## When to Use This Skill

- User says "remember this", "save this for later", "don't forget"
- User states a preference: "always use bun", "never auto-commit", "I prefer tabs"
- After solving a hard bug that others might hit again
- Discovering a project quirk or non-obvious behavior
- Learning an environment-specific gotcha (macOS, shell, tooling)

## Process

1. **Determine what to save**: Extract the key insight, preference, or pattern
2. **Check existing memory**: Read `MEMORY.md` and scan topic files to avoid duplicates
3. **Choose location**:
   - **MEMORY.md**: Quick-reference facts, links to topic files, preferences (keep under 200 lines)
   - **Topic file** (e.g., `debugging.md`, `patterns.md`): Detailed notes, multi-step solutions, extensive context
4. **Write to auto memory path**: `~/.claude/projects/*/memory/` (never to git-tracked files)
5. **Confirm**: Show the user what was written and where

## Memory Path

Auto memory lives at:
```
~/.claude/projects/<project-slug>/memory/MEMORY.md
~/.claude/projects/<project-slug>/memory/<topic>.md
```

The project slug is derived from the working directory path (e.g., `-Users-gfranco-my-project`).

**Important**: This path is local-only and never committed to git. It's safe for project-specific details.

## What to Save

- Stable patterns confirmed through experience
- User preferences for workflow, tools, style
- Solutions to recurring problems
- Key file paths and architecture decisions
- Environment quirks (OS, shell, tooling)
- Build/test commands that differ from README

## What NOT to Save

- Secrets, API keys, tokens, passwords
- Session-specific context (current task, in-progress work)
- Information already in CLAUDE.md or project docs
- Speculative conclusions from a single observation
- Temporary workarounds (note them as temporary if saving)

## MEMORY.md Guidelines

- **200-line limit** (truncated in system prompt beyond that)
- Use as an index: brief facts + links to topic files for details
- Organize by topic with `##` headers
- Keep entries concise: one line per fact when possible
- Review and prune periodically — remove outdated entries

## Output

After saving a memory:

1. Show what was written (quoted)
2. Show the file path
3. Note whether MEMORY.md or a topic file was used
4. If MEMORY.md is approaching 200 lines, suggest moving detail to topic files

## Examples

### User preference
```
User: "Always use pnpm instead of npm in my projects"

Written to MEMORY.md:
## User Preferences
- Package manager: always use pnpm (not npm)
```

### Hard-won debugging insight
```
User: "Remember that neofetch in bashrc breaks limactl shell output"

Written to MEMORY.md:
## Environment Quirks
- neofetch in .bashrc floods `limactl shell` output with ANSI escapes — redirect to file for clean output
```

### Detailed pattern (topic file)
```
User: "Remember how we fixed the test patching issue in notebook-sync"

Written to testing-patterns.md:
# Testing Patterns
## Python Test Patching with Package Re-exports
- When package __init__.py re-exports symbols, patch at `package.Symbol` not `package.module.Symbol`
- Submodules should use `sys.modules["package"]` lookup at call time
- Never change submodule imports to `from .X import Y` for names that tests patch at package level

Added link in MEMORY.md:
- See [testing-patterns.md](testing-patterns.md) for Python test patching with re-exports
```
