---
description: Design-First principle — Elephant-Goldfish Model for AI-assisted development
---

# Design First: The Elephant-Goldfish Model

From Dave Rensin's "Elephants, Goldfish and the New Golden Age of Software Engineering": the **Elephant** is the context-rich session that made the design decisions; the **Goldfish** is a blank-slate fresh session that only knows what is written down. **A design doc is good when a Goldfish can read it and produce the same implementation the Elephant would.** Run `/egm` to test this before `/implement`.

A design doc is done when it:

1. Lists every file to be created or modified
2. Documents every rejected alternative and why — "we considered X but chose Y because Z"
3. Defines acceptance criteria a fresh session could verify independently
4. Ends with a **Session Recovery** block:

```
## Session Recovery
- Design doc / plan file: [path]
- Key decisions: [2-3 bullets]
- Rejected alternatives: [brief list]
- Resume by: running /implement with this doc
```

If a session crashes mid-implementation, feed the Session Recovery block — not conversation history — to a new session.

Interrogate before researching: what could go wrong with the assumed approach? What would a skeptical peer say? Don't let AI agreement substitute for clarity. (Complementary to `rules/karpathy-principles.md` "Surface Assumptions Explicitly" — Karpathy is self-skeptical, Rensin is adversarial.)
