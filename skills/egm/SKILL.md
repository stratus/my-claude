---
name: egm
description: Run the Goldfish Protocol — test a design doc's completeness by verifying a fresh session can reconstruct the plan from it alone. Use after /plan, before /implement, on any complex feature.
model: opus
argument-hint: "[path/to/design-doc.md or inline description]"
---

# EGM Skill — The Goldfish Protocol

Implements the Elephant-Goldfish Model Goldfish check from Dave Rensin's
"Elephants, Goldfish and the New Golden Age of Software Engineering."

A design doc is Goldfish-proof when a blank-slate session — with no conversation
history, no context, only the written document — can reconstruct the plan accurately.
This skill runs that check before implementation begins.

## When to Use

- After `/plan` produces a design doc or plan file
- Before `/implement` on any feature touching >3 files
- When resuming a project after a break (the Goldfish test doubles as a sanity check)
- Any time you're unsure whether the design doc is complete enough

## Process

### Step 1 — Locate the Design Doc

If an argument was passed, use it. Otherwise look for:
- The most recent plan file in `~/.claude-corp/plans/`
- A `DESIGN.md` or `PLAN.md` in the project root or `docs/`
- Ask the user to paste or point to the document

### Step 2 — Comprehension Test (Sub-Agent 1)

Spawn a sub-agent with **only the design doc text** as context. No codebase access.
Ask it to answer:
1. What is being built and why?
2. Which files will be created or modified?
3. What are the acceptance criteria — how would you verify it's done?
4. What alternatives were considered and rejected?

Record what it gets right, what it gets wrong or vague, and what it had to guess.

### Step 3 — Critic Review (Sub-Agent 2)

Spawn a second independent sub-agent with only the design doc text.
Ask it to act as a skeptical peer reviewer:
- What is unclear or ambiguous?
- What edge cases are unaddressed?
- What decisions appear to have been made but are not explained?
- What would a fresh engineer need that isn't in this doc?

### Step 4 — Gap Report

Synthesize both sub-agent results into a structured report:

```
EGM Check — [doc name or feature]

Comprehension Test:
  ✓ or ✗  What to build          [pass / gaps found: ...]
  ✓ or ✗  Files affected         [pass / gaps found: ...]
  ✓ or ✗  Acceptance criteria    [pass / gaps found: ...]
  ✓ or ✗  Rejected alternatives  [pass / gaps found: ...]

Critic Findings:
  - [gap or ambiguity 1]
  - [gap or ambiguity 2]
  (empty = no issues found)

Session Recovery block present? yes / no

Verdict: GOLDFISH-PROOF ✓ — ready for /implement
      or NEEDS REVISION ✗ — return to /plan to address gaps above
```

### Step 5 — Next Step

- If GOLDFISH-PROOF: report the verdict — if this is part of a plan-implement cycle, the user can proceed to `/implement`
- If NEEDS REVISION: list the specific gaps and suggest returning to `/plan`

## Notes

- Sub-agents rely on prompt discipline, not tool restriction — explicitly tell each agent
  "answer only from the text below; do not read any files" and paste the doc in the prompt
- Issue both Task calls in a single message to run them in parallel
- The critic and comprehension roles must be separate agents; one agent cannot do both
  objectively (it will rationalize gaps it introduced in the first pass)
