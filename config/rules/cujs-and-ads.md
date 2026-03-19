---
description: Critical User Journeys and Architecture Decisions — ensure projects document CUJs and ADs
globs: "**/*"
---

# Critical User Journeys & Architecture Decisions

Every project should document its **Critical User Journeys (CUJs)** and **Architecture Decisions (ADs)** unless explicitly opted out.

## Standard Locations

- `docs/cujs/` — One markdown file per critical user journey
- `docs/decisions/` — One markdown file per architecture decision (ADR format)

## Opt-Out

A `.opted-out` sentinel file in either directory signals the user explicitly chose not to document that type. **Never prompt about opted-out categories.**

```
docs/cujs/.opted-out      # User opted out of CUJ documentation
docs/decisions/.opted-out  # User opted out of AD documentation
```

To opt out, create the sentinel: `mkdir -p docs/cujs && touch docs/cujs/.opted-out`

## On Session Start (First Feature Work)

Check for `docs/cujs/` and `docs/decisions/`. If either is missing and has no `.opted-out`:

1. **Scan for existing docs in non-standard locations:**
   - Architecture: `docs/architecture.md`, `docs/adr/`, `docs/adrs/`, `docs/architecture-decisions/`, `DECISIONS.md`, `ADR.md`, `architecture.md`
   - User journeys: `docs/user-journeys/`, `docs/flows/`, `docs/use-cases/`, `docs/journeys/`, `user-stories.md`

2. **If found:** Suggest migrating to the standard location. Offer to help move files.

3. **If not found:** Ask the user:
   > "This project doesn't have [CUJs/ADs] documented. Would you like to:
   > 1. Create them now (I can scaffold from templates)
   > 2. Opt out (I'll create a `.opted-out` marker so I won't ask again)"

**Do not nag.** Ask once per session, respect the answer.

## When Implementing Features

- **CUJs:** Check if the feature touches a documented journey. Use the CUJ's success criteria and error paths as acceptance criteria. If implementing a wholly new user flow, suggest creating a CUJ.
- **ADs:** Check if the implementation aligns with accepted decisions. If proposing something that contradicts an AD, flag it. If making a significant architectural choice (new dependency, new service, new data store, new integration pattern), suggest creating an AD.

## CUJ Format

Each CUJ file should have frontmatter with `name`, `actor`, `status` (active/deprecated/draft), and `last-verified` date. Body includes: Preconditions, Steps, Success Criteria, Error Paths.

Use `/cuj` skill to scaffold new entries.

## AD Format (Michael Nygard ADR)

Each AD file should have frontmatter with `number`, `title`, `status` (proposed/accepted/deprecated/superseded), `date`, `supersedes`, and `superseded-by`. Body includes: Context, Decision, Consequences (positive/negative/neutral).

Use `/ad` skill to scaffold new entries.

## Staleness

CUJs and ADs are checked for staleness at pre-commit time (non-blocking warning). A CUJ or AD is considered stale if `last-verified` or `date` is older than 90 days. Update the date when you verify content is still accurate.
