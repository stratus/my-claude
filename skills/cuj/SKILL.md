---
name: cuj
description: Scaffold a new Critical User Journey document. Use when documenting user flows, onboarding journeys, or end-to-end scenarios.
model: haiku
allowed-tools: Read, Write, Glob, Grep
---

# CUJ Scaffolding Skill

Create a new Critical User Journey document in the standard location.

## When to Use This Skill

- User says "cuj", "user journey", "document this flow", "critical path"
- Starting a new feature that introduces a user-facing flow
- Documenting an existing flow that lacks a CUJ

## Process

### 1. Check Opt-Out

Before anything, check if `docs/cujs/.opted-out` exists:

```bash
if [ -f docs/cujs/.opted-out ]; then
  # Tell user: "This project has opted out of CUJ documentation."
  # Ask if they want to remove the opt-out marker, otherwise stop.
fi
```

### 2. Gather Information

Ask the user (skip questions they already answered in their prompt):

1. **Journey name** — short, descriptive (e.g., "signup-flow", "checkout", "api-key-rotation")
2. **Actor** — who performs this journey (e.g., "end user", "admin", "developer")
3. **Brief description** — one sentence of what this journey covers

### 3. Determine File Name

- Slugify the journey name: lowercase, hyphens, no special characters
- Check existing CUJs to avoid duplicates:

```bash
ls docs/cujs/*.md 2>/dev/null
```

- File name: `docs/cujs/{slug}.md`

### 4. Scaffold the Document

Read the template from `templates/cuj-template.md` (if available in the repo) or use the standard CUJ format:

- Fill in frontmatter: `name`, `actor`, `status: draft`, `last-verified: [today]`
- Fill in the journey name in the heading
- Leave Steps, Success Criteria, and Error Paths as placeholders for the user to fill collaboratively

Create the directory if needed: `mkdir -p docs/cujs`

### 5. Collaborate on Content

Walk through each section with the user:

1. **Preconditions** — What must be true before starting?
2. **Steps** — Walk through the journey step by step. Ask clarifying questions.
3. **Success Criteria** — How do you know it worked? What's the observable outcome?
4. **Error Paths** — What can go wrong at each step? What should happen?

Write the completed CUJ to the file.

### 6. Cross-Reference

- If `docs/decisions/` exists, check if any AD is related and mention it
- Suggest updating the project README if this is the first CUJ

## Output

Present the completed CUJ and confirm:
- "CUJ saved to `docs/cujs/{name}.md` with status: draft"
- "Update status to `active` once the flow is implemented and verified"
- If this is the first CUJ: "Consider running `/ad` to document key architectural decisions too"
