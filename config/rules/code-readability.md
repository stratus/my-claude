---
description: Code readability — naming conventions, structure limits, comment policy
globs: "**/*.{js,ts,jsx,tsx,py,go,rs,java}"
---

# Code Readability

## Naming
- Variables: descriptive (`userCount` not `uc`)
- Functions: verb phrases (`calculateTotal()` not `calc()`)
- Classes: singular nouns (`UserRepository`)

## Structure
- Functions: <50 lines ideal, <100 max, 3-4 params max
- Complexity: <10 cyclomatic, <4 nesting levels
- Files: <500 lines, single responsibility

## Comments
Write self-documenting code. Comment "why" not "what". No dead code.
