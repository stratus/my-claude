---
description: Design-First principle — Elephant-Goldfish Model for AI-assisted development
globs: "**/*"
---

# Design First: The Elephant-Goldfish Model

Adapted from Dave Rensin's "Elephants, Goldfish and the New Golden Age of Software Engineering."

See also: `rules/karpathy-principles.md` for the complementary "Surface Assumptions Explicitly"
principle. Where Karpathy's rule is self-skeptical ("ask if I'm solving the wrong problem"),
Rensin's Interrogation Phase is adversarial ("actively challenge the approach").

---

## The Core Idea

Two types of AI sessions exist in any project:

**The Elephant** — a richly-contextualized session that has accumulated all design discussions,
rejected alternatives, clarified constraints, and implementation intent. It knows why decisions
were made, not just what was decided.

**The Goldfish** — a blank-slate fresh session that can only work from what is written down.
It has no memory of any prior conversation. It cannot reconstruct intent from code alone.

**The test for a good design document**: can a Goldfish session read it and produce the same
implementation the Elephant would?

---

## Design is the New Code

When AI generates the implementation, humans stop making the micro-decisions embedded in every
line of logic. Those decisions don't disappear — they must happen *before* implementation, in
the design document. The design doc is no longer just documentation; it is the primary artifact
that carries human judgment into the codebase.

A design doc is done when:
- It lists every file to be created or modified
- It explains every rejected alternative and why it was rejected
- It defines acceptance criteria a fresh session could verify independently
- It contains a **Session Recovery** block (see below)

Run `/egm` to test whether a doc meets this bar before starting `/implement`.

---

## Session Recovery

Every design doc should end with a **Session Recovery** block:

```
## Session Recovery
- Design doc / plan file: [path]
- Key decisions: [2-3 bullets]
- Rejected alternatives: [brief list]
- Resume by: running /implement with this doc
```

If a session crashes mid-implementation, feed this block (not the conversation history)
to a new session. The Goldfish recovers exactly where the Elephant left off — but only if
the doc was Goldfish-proof.

---

## Interrogation Before Research

Before searching the codebase, interrogate the problem:
- What could go wrong with the assumed approach?
- What alternatives were not considered?
- What would a skeptical peer say about this plan?

Do not let AI agreement substitute for clarity. Push back on convenient answers.
Surface blind spots *before* committing to an approach.

---

## Practical Rules

1. No code until the design doc passes the Goldfish test (`/egm`)
2. Rejected alternatives must be documented — "we considered X but chose Y because Z"
3. Every plan must include a Session Recovery block
4. The design doc is the commit artifact; the code follows from it
