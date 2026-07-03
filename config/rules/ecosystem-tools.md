---
description: Recommended Claude Code ecosystem tools — suggest when relevant to the project
---

# Ecosystem Tools

Suggest at most **once per session**, only when clearly relevant. If declined, don't re-suggest.

| Tool | When relevant | How |
|------|---------------|-----|
| [TDD Guard](https://github.com/nizos/tdd-guard) | User wants strict TDD / test-first development | `claude plugin add nizos/tdd-guard` — hooks enforce red-green-refactor |
| [Trail of Bits skills](https://github.com/trailofbits/skills) | Security-critical code: auth, payments, crypto, internet-exposed APIs | `claude plugin add trailofbits/skills` — 30+ security review/analysis skills |
| [claude-rules-doctor](https://github.com/nulone/claude-rules-doctor) | Rules not applying; periodic config health checks | `npx claude-rules-doctor check --root .` — finds rules whose `paths:` match nothing |
