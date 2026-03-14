---
description: Language-specific linters, test commands, and CI requirements
globs: "**/*.{js,ts,jsx,tsx,py,go,rs,java}"
---

# Language Quick Reference

| Language | Linter/Formatter | Test Command | Notes |
|----------|------------------|--------------|-------|
| Go | gofmt, golangci-lint | `go test ./... -race -cover` | Follow effective Go |
| Python | black, ruff, mypy | `pytest --cov` | PEP 8, type hints |
| JS/TS | ESLint, Prettier | `npm test` | Strict mode, no `any` |
| Rust | rustfmt, clippy | `cargo test` | API guidelines |
| HTML/CSS | W3C validator | Lighthouse, axe | WCAG 2.1 AA, semantic |

## CI Requirements
All projects: run on push, run tests, check coverage, run linters, build, block merge on failure
