---
description: Git standards — commit format, branch naming, PR guidelines
globs: "**/*"
---

# Git Standards

## Commits
```
Brief summary (50 chars)

- What changed
- Why it changed
- Breaking changes / Related issues
```
Atomic, frequent, tested before commit. Present tense, imperative mood.

## Branches
- `main`: always deployable
- `feature/desc`, `fix/issue-num`, `docs/topic`
- Short-lived, delete after merge

## Never Commit
Secrets, build artifacts, dependencies (node_modules), IDE files, OS files, large binaries

## PRs
<400 lines, self-review first, link issues, include doc updates, all CI passing
