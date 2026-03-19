---
name: ad
description: Scaffold a new Architecture Decision Record (ADR). Use when documenting architectural choices, technology selections, or significant design trade-offs.
model: haiku
allowed-tools: Read, Write, Glob, Grep
---

# Architecture Decision Skill

Create a new Architecture Decision Record (ADR) in the standard location using the Michael Nygard format.

## When to Use This Skill

- User says "ad", "adr", "architecture decision", "document this decision"
- A significant architectural choice was just made (new dependency, new service, new pattern)
- Revisiting or superseding an existing decision

## Process

### 1. Check Opt-Out

Before anything, check if `docs/decisions/.opted-out` exists:

```bash
if [ -f docs/decisions/.opted-out ]; then
  # Tell user: "This project has opted out of architecture decision documentation."
  # Ask if they want to remove the opt-out marker, otherwise stop.
fi
```

### 2. Determine Next Number

Scan existing ADRs to auto-assign the next number:

```bash
ls docs/decisions/*.md 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1
```

- If no existing ADRs: start at 001
- Otherwise: increment the highest number by 1
- Zero-pad to 3 digits (001, 002, ..., 010, ..., 100)

### 3. Gather Information

Ask the user (skip questions they already answered in their prompt):

1. **Title** — concise decision name (e.g., "Use PostgreSQL for persistence", "Event-driven architecture for ingest pipeline")
2. **Context** — What problem or situation motivates this decision?
3. **Does this supersede an existing AD?** — Check against existing ADRs

### 4. Scaffold the Document

Read the template from `templates/ad-template.md` (if available in the repo) or use the standard ADR format:

- Fill in frontmatter: `number`, `title`, `status: proposed`, `date: [today]`
- If superseding: populate `supersedes` field and update the old AD's `superseded-by` and `status: superseded`
- File name: `docs/decisions/{NNN}-{slug}.md`

Create the directory if needed: `mkdir -p docs/decisions`

### 5. Collaborate on Content

Walk through each section with the user:

1. **Context** — Expand on the problem. What forces are at play? What constraints exist?
2. **Decision** — State the decision clearly. What are we doing and why this option?
3. **Consequences** — Work through positive, negative, and neutral outcomes together

Write the completed ADR to the file.

### 6. Cross-Reference

- If superseding another AD, update the old file's frontmatter automatically
- If `docs/cujs/` exists, check if any CUJ is affected by this decision and mention it
- Suggest updating the project README if this is the first AD

## Output

Present the completed ADR and confirm:
- "ADR saved to `docs/decisions/{NNN}-{slug}.md` with status: proposed"
- "Update status to `accepted` once the team agrees on this decision"
- If superseding: "Updated ADR-{old} status to `superseded`"
