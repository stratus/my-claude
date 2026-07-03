---
description: Karpathy principles — surface assumptions, surgical edits, verify-loop format
---

# Karpathy Principles

Behavioral guidelines for non-trivial work; use judgment on simple tasks. Adapted from Andrej Karpathy's observations on common LLM coding pitfalls. These hold the deltas not already covered by the global CLAUDE.md or other rules.

## Surface Assumptions Explicitly

Don't pick an interpretation silently and run with it. Before implementing anything non-trivial: state your assumptions out loud; if multiple interpretations exist, present them; if a simpler approach exists, say so and push back when warranted; if something is unclear, stop and ask. This prevents solving the wrong problem because the ambiguity was never named.

## Match Existing Style

Match the file's style even if you'd do it differently in a fresh project. Don't "improve" adjacent code, refactor things that aren't broken, or delete unrelated dead code — mention smells, don't fix them unasked. This prevents drive-by refactors that bloat the diff.

## Every Changed Line Traces to the Request

Every line your diff adds or removes should trace directly to what the user asked for. Remove imports/variables/functions that **your** changes orphaned; leave pre-existing dead code alone unless asked. If you can't justify a changed line by the request, revert it.

## Verify-Loop Format for Multi-Step Tasks

For plans or task lists with more than two steps, write each step as `[step] → verify: [check]`. Strong success criteria let the loop run independently; weak criteria ("make it work") force constant clarification. `/plan` and `/implement` already produce phased output — use this format inside each phase.

---

Adapted from <https://github.com/forrestchang/andrej-karpathy-skills> (MIT), based on <https://x.com/karpathy/status/2015883857489522876>.
