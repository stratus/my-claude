# Karpathy Principles

Behavioral guidelines that complement other rules. Bias toward caution on non-trivial work; use judgment on simple tasks. Adapted from Andrej Karpathy's observations on common LLM coding pitfalls.

These rules hold the **deltas** that aren't already covered by the global `CLAUDE.md` or other rules. Simplicity ("no features beyond what was asked", "no error handling for impossible scenarios", "no comments for the sake of comments") is already enforced upstream — see the global `CLAUDE.md` "Doing tasks" section. This file does not repeat it.

## Surface Assumptions Explicitly

Don't pick an interpretation silently and run with it. Before implementing anything non-trivial:

- State your assumptions out loud. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

The failure mode this prevents: producing 200 lines that solve the wrong problem because the ambiguity was never named.

## Match Existing Style

When editing existing code:

- Match the file's style even if you'd do it differently in a fresh project.
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- If you notice unrelated dead code or smells, mention them — don't delete them.

The failure mode this prevents: drive-by refactors that bloat the diff and make review harder.

## Every Changed Line Traces to the Request

The test for surgical edits: every line your diff adds or removes should trace directly to what the user asked for.

- Remove imports / variables / functions that **your** changes orphaned.
- Don't remove pre-existing dead code unless asked.
- If you can't justify a changed line by the request, revert it.

The failure mode this prevents: orthogonal edits that change behavior the user didn't ask about.

## Verify-Loop Format for Multi-Step Tasks

For plans or task lists with more than two steps, write each step with an explicit verification:

```
1. [step] → verify: [check]
2. [step] → verify: [check]
3. [step] → verify: [check]
```

Strong success criteria let the loop run independently. Weak criteria ("make it work") force constant clarification.

The `/plan` and `/implement` skills already produce phased output — use this format inside each phase to sharpen the success criteria.

---

Adapted from <https://github.com/forrestchang/andrej-karpathy-skills> (MIT), based on observations from <https://x.com/karpathy/status/2015883857489522876>.
