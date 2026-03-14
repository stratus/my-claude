---
description: Architecture documentation — required for projects with >2 components
globs: "**/*"
---

# Architecture Documentation

**Required** for any project with >2 components, services, or external integrations.

## What to Document
Create `docs/architecture.md` (or section in README for simple projects) with a diagram showing:
- Component/service boundaries
- Data flow direction (arrows)
- External dependencies (APIs, databases, queues)
- Key interfaces between components

## When to Update
- Adding new component or service
- Changing integration patterns
- Adding external dependencies
- Modifying data flow

**Before implementing multi-component features**: Create/update diagram first, then code.
