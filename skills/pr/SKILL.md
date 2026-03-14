---
name: pr
description: Create a pull request with proper title, description, test plan, and linked issues. Use when ready to submit changes for review.
argument-hint: "[base-branch]"
---

# Pull Request Skill

Create well-structured pull requests following project standards.

## When to Use This Skill

- User says "create PR", "open PR", "submit for review"
- After implementation is complete and tests pass
- When branch is ready to merge

## Process

### 1. Gather Context
```bash
git status
git log --oneline main..HEAD
git diff main...HEAD --stat
```

### 2. Validate Readiness
Before creating PR, verify:
- [ ] All tests pass
- [ ] No linter errors
- [ ] Changes committed and pushed
- [ ] Branch is up to date with base
- [ ] No secrets in diff

### 3. Draft PR

**Title**: Short, descriptive, under 70 characters
- Use imperative mood: "Add", "Fix", "Update", "Remove"
- Include ticket number if applicable: "Fix login timeout (#123)"

**Body**: Use this structure:
```markdown
## Summary
- [1-3 bullet points describing the change]

## Changes
- [List of specific changes made]

## Test plan
- [ ] [How to verify this works]
- [ ] [Edge cases tested]

## Related
- Fixes #[issue]
- Related to #[issue]
```

### 4. Create PR
```bash
gh pr create --title "..." --body "..."
```

### 5. Post-creation
- Share the PR URL with the user
- Suggest reviewers if known

## Output

Return the PR URL and a brief summary of what was submitted.
