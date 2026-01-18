# Global Development Standards

Standards for ALL projects unless overridden by project-specific `.claude/CLAUDE.md`.

---

## ⚠️ MANDATORY - READ FIRST

### Workflow After Code Changes

For changes **>20 lines or touching security/validation**:
1. Run `code-reviewer` agent → BEFORE commit
2. Run `docs-updater` agent → For user-facing changes
3. Verify 80%+ test coverage, linter passes, all tests pass

For **small changes (<20 lines, non-security)**: Run tests and linter only.

### New Project Setup

If project lacks `.claude/CLAUDE.md`: **ASK** user to create one before coding.

### Token Optimization

- **Use `model: "haiku"`** for simple agent tasks (searches, formatting, straightforward generation)
- **Prefer Glob/Grep** over Explore agent for simple file/code searches
- **Use `/clear`** between unrelated tasks
- **Use `/compact`** when context grows large but continuity needed
- Suggest these commands proactively when appropriate

---

## Core Principles

1. **Security First** - Non-negotiable
2. **Test Everything** - 80% minimum coverage
3. **Document Changes** - Keep docs current
4. **Readable Code** - Self-documenting preferred
5. **Track with Git** - Atomic commits, clear messages

---

## Security Standards

### Mandatory Review Areas
Auth, validation, APIs, database queries, file operations, crypto, sessions, CORS

### Best Practices
- Never commit secrets (.env, API keys, credentials)
- Validate all inputs (user, API, files, env vars)
- Use secure defaults, least privilege, defense in depth
- Fail securely (no sensitive info in errors)

### Prevent OWASP Top 10
SQL injection, XSS, CSRF, insecure deserialization, XXE, SSRF, command injection, path traversal

---

## Testing Standards

- **80% minimum** coverage (100% for security/validation code)
- Unit tests: individual functions, mock dependencies, fast
- Integration tests: component interactions, API contracts
- Edge cases: null, empty, boundaries, errors, concurrency
- TDD preferred, tests alongside implementation

---

## Documentation

**Required**: README.md (purpose, install, usage, dev setup, testing, deploy)

Update docs when changing code. Use `docs-updater` agent for user-facing changes.

**Avoid**: Outdated docs, obvious comments, commented-out code, TODOs without tickets

---

## Code Readability

### Naming
- Variables: descriptive (`userCount` not `uc`)
- Functions: verb phrases (`calculateTotal()` not `calc()`)
- Classes: singular nouns (`UserRepository`)

### Structure
- Functions: <50 lines ideal, <100 max, 3-4 params max
- Complexity: <10 cyclomatic, <4 nesting levels
- Files: <500 lines, single responsibility

### Comments
Write self-documenting code. Comment "why" not "what". No dead code.

---

## Git Standards

### Commits
```
Brief summary (50 chars)

- What changed
- Why it changed
- Breaking changes / Related issues
```
Atomic, frequent, tested before commit. Present tense, imperative mood.

### Branches
- `main`: always deployable
- `feature/desc`, `fix/issue-num`, `docs/topic`
- Short-lived, delete after merge

### Never Commit
Secrets, build artifacts, dependencies (node_modules), IDE files, OS files, large binaries

### PRs
<400 lines, self-review first, link issues, include doc updates, all CI passing

---

## Agent Usage

| Agent | When to Use | Model |
|-------|-------------|-------|
| `code-reviewer` | After code changes >20 lines or security-related | sonnet |
| `docs-updater` | After code review, for user-facing changes | haiku |
| `debug-specialist` | Errors, test failures, unexpected behavior | sonnet |

**Skip agents** for trivial changes (<20 lines, non-security, no user-facing impact).

---

## Language Quick Reference

| Language | Linter/Formatter | Test Command | Notes |
|----------|------------------|--------------|-------|
| Go | gofmt, golangci-lint | `go test ./... -race -cover` | Follow effective Go |
| Python | black, ruff, mypy | `pytest --cov` | PEP 8, type hints |
| JS/TS | ESLint, Prettier | `npm test` | Strict mode, no `any` |
| Rust | rustfmt, clippy | `cargo test` | API guidelines |
| HTML/CSS | W3C validator | Lighthouse, axe | WCAG 2.1 AA, semantic |

**Frontend security**: CSP headers, sanitize HTML (DOMPurify), no innerHTML with user data, HTTPS only

---

## CI Requirements

All projects: run on push, run tests, check coverage, run linters, build, block merge on failure

---

## Project Overrides

- `./.claude/CLAUDE.md` - Project-specific guidelines
- `./CLAUDE.local.md` - Personal preferences (gitignored)

---

## Context Hygiene

**Proactively suggest**:
- `/clear` - When task complete or switching to unrelated task
- `/compact` - When context large but need continuity

**Describe** what would be preserved when suggesting `/compact`.
