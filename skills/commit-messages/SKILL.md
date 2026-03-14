---
name: commit-messages
description: Generate clear commit messages following project conventions. Use when writing commit messages, reviewing staged changes, or preparing releases.
model: haiku
allowed-tools: Bash(git *)
---

# Commit Message Skill

Generate consistent, informative commit messages following project conventions.

## When to Use This Skill

- User asks to "commit", "write a commit message", or "prepare commit"
- User has staged changes and mentions commits
- Before any `git commit` command

## Process

1. **Analyze changes**: Run `git diff --staged` to see what's being committed
2. **Review recent history**: Run `git log --oneline -5` to match existing style
3. **Identify the type**: Determine the primary change category
4. **Find the scope**: Identify the main area affected
5. **Write the message**: Follow the format below

## Commit Message Format

```
Brief summary (50 chars or less)

Detailed explanation if needed (wrap at 72 chars):
- What changed
- Why it changed
- Any breaking changes
- Related issues/tickets

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Subject Line Rules

- **Present tense**: "Add feature" not "Added feature"
- **Imperative mood**: "Fix bug" not "Fixes bug"
- **Start with capital letter**
- **No period at the end**
- **Max 50 characters** (72 absolute max)
- Reference issues: "Fixes #123" or "Related to #456"

## Message Categories

| Action | When to use | Example |
|--------|-------------|---------|
| `Add` | Wholly new feature | `Add user authentication` |
| `Update` | Enhancement to existing | `Update search to include fuzzy matching` |
| `Fix` | Bug fix | `Fix null pointer in cart` |
| `Remove` | Deletion | `Remove deprecated API endpoints` |
| `Refactor` | Code restructure | `Refactor database layer` |
| `Move` | Relocation | `Move utils to shared package` |

## Body (when needed)

- Separate from subject with blank line
- Explain *what* and *why*, not *how*
- Wrap at 72 characters
- Use bullet points for multiple changes

## Footer

- `Fixes #123` to close issues
- `Related to #456` to reference without closing
- **Always include**: `Co-Authored-By: Claude <noreply@anthropic.com>`

## Git Command Format

Use HEREDOC for multi-line messages:

```bash
git commit -m "$(cat <<'EOF'
Brief summary here

Detailed explanation if needed.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Examples

### Simple feature
```
Add dark mode toggle to settings

Implements user preference for dark/light theme with
localStorage persistence.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Bug fix with issue reference
```
Fix cart duplicate items on rapid clicks

Add debounce to add-to-cart button and check for
existing items before insertion.

Fixes #234

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Refactoring
```
Refactor authentication to use middleware pattern

- Extract JWT handling to dedicated service
- Move session management from controller
- Add refresh token rotation

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Output

When generating a commit message:

1. Show the staged changes summary
2. Propose the commit message
3. Explain the category choice if non-obvious
4. Ask if the user wants to proceed or modify
