---
description: Documentation standards — README requirements, litmus test, update policy
globs: "**/*.md"
---

# Documentation Standards

**Required**: README.md with:
- Purpose (one paragraph: what it does, who it's for)
- Prerequisites (runtime versions, system deps)
- Installation (copy-paste commands that work)
- Usage (realistic examples, not just API signatures)
- Development setup (how to run locally)
- Testing (how to run tests)
- Deployment (if applicable, or link to deployment docs)

## README Litmus Test
Would a new team member be able to:
1. Understand what this does in 30 seconds?
2. Get it running locally in 5 minutes?
3. Know where to look for more detail?

If no to any, README is incomplete.

Update docs when changing code. Use `docs-updater` agent for user-facing changes.

**Avoid**: Outdated docs, obvious comments, commented-out code, TODOs without tickets
