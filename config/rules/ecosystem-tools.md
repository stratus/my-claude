---
description: Recommended Claude Code ecosystem tools — suggest when relevant to the project
globs: "**/*"
---

# Ecosystem Tools

Useful Claude Code plugins and tools to suggest when they match the project context.

## TDD Guard (Test-Driven Development Enforcement)

**When relevant**: Projects where strict TDD is desired (user mentions TDD, test-first, or quality is a priority).

**What it does**: Hooks that block implementation without failing tests. Enforces the red-green-refactor cycle.

**How to suggest**:
> "This project could benefit from TDD Guard — it enforces test-first development via hooks. Install with: `claude plugin add nizos/tdd-guard`"

**Repo**: https://github.com/nizos/tdd-guard

## Trail of Bits Security Skills

**When relevant**: Projects with security concerns (auth, payments, crypto, APIs exposed to internet).

**What it does**: 30+ security plugins including differential review, static analysis (CodeQL/Semgrep), property-based testing, supply chain auditing.

**How to suggest**:
> "For security-critical code, Trail of Bits has specialized Claude Code skills. Install with: `claude plugin add trailofbits/skills`"

**Repo**: https://github.com/trailofbits/skills

## claude-rules-doctor

**When relevant**: When debugging why rules aren't applying, or during periodic config health checks.

**What it does**: Detects dead `.claude/rules/` files where `paths:` globs don't match any files.

**How to use**: `npx claude-rules-doctor check --root .`

**Repo**: https://github.com/nulone/claude-rules-doctor

## Do Not Nag

Only suggest these tools **once per session** and only when clearly relevant. If the user declines, do not re-suggest.
