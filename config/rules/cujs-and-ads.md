---
description: Critical User Journeys and Architecture Decisions — ensure projects document CUJs and ADs
---

# Critical User Journeys & Architecture Decisions

Every project documents its CUJs (`docs/cujs/`, one file per journey) and ADs (`docs/decisions/`, Nygard ADR format) unless explicitly opted out.

## Opt-Out

A `.opted-out` sentinel file in either directory means the user chose not to document that type. **Never prompt about opted-out categories.** To opt out: `mkdir -p docs/cujs && touch docs/cujs/.opted-out`

## On First Feature Work

If `docs/cujs/` or `docs/decisions/` is missing with no `.opted-out`: first scan for existing docs in non-standard locations (`docs/adr/`, `docs/architecture.md`, `DECISIONS.md`, `docs/user-journeys/`, `docs/flows/`, etc.) and offer to migrate them. If none found, ask once — create now (scaffold via `/cuj` or `/ad`) or opt out (create the sentinel). Do not nag; ask once per session and respect the answer.

## When Implementing Features

- **CUJs:** Use the touched CUJ's success criteria and error paths as acceptance criteria. A wholly new user flow → suggest creating a CUJ.
- **ADs:** Flag implementations that contradict accepted ADs. A significant architectural choice (new dependency, service, data store, or integration pattern) → suggest creating an AD.

Formats and scaffolding live in the `/cuj` and `/ad` skills. Staleness (`last-verified`/`date` older than 90 days) warns non-blocking at pre-commit; update the date when you re-verify content.
