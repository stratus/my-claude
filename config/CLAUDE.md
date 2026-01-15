# Global Development Standards

This file defines development standards applied to ALL my projects unless overridden by project-specific CLAUDE.md.

## Core Principles

1. **Security First** - Security is non-negotiable
2. **Test Everything** - Code without tests is incomplete
3. **Document Changes** - Keep documentation current
4. **Readable Code** - Code is read more than written
5. **Track Everything** - Use git to track all changes

---

## 1. Security Standards

### Mandatory Reviews
- **ALWAYS** use the `code-reviewer` agent after writing or modifying code
- Security review is REQUIRED for:
  - Authentication and authorization code
  - Data validation and sanitization
  - API endpoints handling user data
  - Database queries and ORM usage
  - File system operations
  - Cryptography and encryption
  - Session management
  - CORS and security headers

### Security Best Practices
- **Never commit secrets**: No API keys, passwords, tokens, or credentials in code
- **Validate all inputs**: User input, API responses, file uploads, environment variables
- **Use secure defaults**: Secure by default, not opt-in
- **Principle of least privilege**: Minimal permissions required
- **Defense in depth**: Multiple layers of security
- **Fail securely**: Errors should not expose sensitive information

### Common Vulnerabilities to Prevent
- SQL injection (use parameterized queries)
- Cross-Site Scripting (XSS) - sanitize outputs
- Cross-Site Request Forgery (CSRF) - use tokens
- Insecure deserialization
- XML External Entities (XXE)
- Server-Side Request Forgery (SSRF)
- Command injection
- Path traversal
- Insecure direct object references

---

## 2. Testing Standards

### Coverage Requirements
- **Minimum 80% test coverage** for all projects
- 100% coverage for security-critical code
- 100% coverage for data validation logic
- New code must include tests before merging

### Test Types Required
1. **Unit Tests**
   - Test individual functions and methods
   - Mock external dependencies
   - Fast execution (milliseconds)
   - Run on every commit

2. **Integration Tests**
   - Test component interactions
   - Use test databases/services
   - Verify API contracts
   - Run before PR creation

3. **Edge Cases**
   - Null/nil values
   - Empty collections
   - Boundary conditions
   - Error conditions
   - Concurrent access (where applicable)

### Testing Workflow
1. Write tests alongside implementation (TDD preferred)
2. Run tests locally before committing
3. Use `code-reviewer` agent to verify test quality
4. Ensure tests are deterministic and isolated
5. Keep tests maintainable and readable

### Test Quality Criteria
- Tests should be easy to understand
- One assertion concept per test
- Clear test names describing what is tested
- Arrange-Act-Assert pattern
- No test interdependencies
- Fast execution

---

## 3. Documentation Standards

### Required Documentation
1. **README.md** (every project)
   - Project purpose and overview
   - Installation instructions
   - Usage examples
   - Development setup
   - Testing instructions
   - Deployment process

2. **Architecture Documentation**
   - System architecture diagrams
   - Data flow diagrams
   - Key design decisions
   - Technology choices and rationale

3. **API Documentation**
   - Endpoint descriptions
   - Request/response examples
   - Authentication requirements
   - Error codes and handling

4. **Code Documentation**
   - Complex logic explained
   - Non-obvious decisions documented
   - Public APIs documented
   - Examples for library functions

### Documentation Workflow
1. Update documentation when changing code
2. Use `docs-updater` agent after code review
3. Keep docs in version control
4. Review docs during code review

### Documentation Anti-Patterns to Avoid
- Outdated documentation (worse than none)
- Documenting obvious code
- Copy-pasting code into comments
- TODO comments without tickets
- Commented-out code (delete it)

---

## 4. Code Readability Standards

### Naming Conventions
- **Variables**: Descriptive, avoid abbreviations
  - Good: `user_count`, `customerEmail`, `isAuthenticated`
  - Bad: `uc`, `cstEmail`, `auth`
- **Functions**: Verb phrases describing action
  - Good: `calculateTotal()`, `fetchUserData()`, `validateEmail()`
  - Bad: `calc()`, `data()`, `check()`
- **Classes**: Nouns, singular
  - Good: `UserRepository`, `PaymentProcessor`, `EmailValidator`
  - Bad: `Users`, `DoPayment`, `Validate`
- **Constants**: UPPER_SNAKE_CASE or language convention
- **Files**: Match primary class/module name

### Code Structure
- **Function length**: Aim for < 50 lines, max 100 lines
- **Function parameters**: Max 3-4 parameters, use objects for more
- **Cyclomatic complexity**: Keep below 10
- **Nesting depth**: Max 3-4 levels
- **Single Responsibility**: Each function does one thing well

### Language-Specific Guidelines
- **Go**: Follow effective Go, use gofmt, golangci-lint
- **Python**: PEP 8, use black/ruff, type hints
- **JavaScript/TypeScript**: ESLint, Prettier, TypeScript strict mode
- **HTML**: Semantic HTML5, WCAG accessibility, valid markup
- **CSS**: Responsive design, maintainable architecture, performance-focused
- **Rust**: rustfmt, clippy
- **Java**: Google Java Style Guide

### Code Organization
- Group related functionality
- Order from public to private
- Keep files focused (< 500 lines)
- Use meaningful file and directory structure
- Separate concerns (business logic, data access, presentation)

### Comments and Clarity
- **Write self-documenting code first**
- Add comments for "why", not "what"
- Explain non-obvious decisions
- Document assumptions and constraints
- Remove commented-out code
- Keep comments up to date

---

## 5. Git and Version Control

### Commit Standards
- **Commit message format**:
  ```
  Brief summary (50 chars or less)

  Detailed explanation if needed (wrap at 72 chars):
  - What changed
  - Why it changed
  - Any breaking changes
  - Related issues/tickets
  ```

- **Commit message style**:
  - Present tense: "Add feature" not "Added feature"
  - Imperative mood: "Fix bug" not "Fixes bug"
  - Start with capital letter
  - No period at end of subject line
  - Reference issues: "Fixes #123" or "Related to #456"

### Commit Best Practices
- **Atomic commits**: Each commit is a logical unit
- **Commit frequently**: Small, focused commits
- **Test before committing**: Ensure builds and tests pass
- **Review diffs**: Use `git diff` before committing
- **Clean history**: Rebase/squash before merging (project-dependent)

### Branching Strategy
- **Main/master**: Always deployable
- **Feature branches**: One branch per feature
- **Branch naming**: `feature/description`, `fix/issue-number`, `docs/topic`
- **Keep branches short-lived**: Merge frequently
- **Delete merged branches**: Keep repository clean

### What NOT to Commit
- Secrets and credentials (.env files, API keys, passwords)
- Build artifacts (compiled binaries, dist folders)
- Dependencies (node_modules, vendor, .venv)
- IDE-specific files (.vscode, .idea - use global .gitignore)
- OS-specific files (.DS_Store, Thumbs.db)
- Large binary files (use Git LFS if needed)
- Sensitive data (PII, customer data, logs with secrets)

### Pull Request Standards
- **PR description**: What, why, how to test
- **Small PRs**: Easier to review (< 400 lines changed)
- **Self-review first**: Review your own PR before requesting review
- **Link issues**: Reference related tickets
- **Update docs**: Include documentation changes
- **Passing tests**: All CI checks must pass

---

## 6. Agent Usage (Anthropic Recommended)

### Mandatory Agent Usage

1. **code-reviewer** - Use AFTER writing or modifying code
   - Invoke BEFORE committing
   - Reviews for security, quality, tests, readability
   - Provides actionable feedback
   - Severity: Critical → Important → Suggestions

2. **debug-specialist** - Use when encountering ANY error
   - Test failures
   - Build errors
   - Runtime exceptions
   - Unexpected behavior
   - Performance issues
   - Provides root cause analysis and fixes

3. **docs-updater** - Use AFTER code review is complete
   - Updates project documentation
   - Keeps README current
   - Updates API docs
   - Adds examples where needed

### Agent Workflow
```
Write/Modify Code
    ↓
Run Tests Locally
    ↓
Use code-reviewer agent ← MANDATORY
    ↓
Address feedback (Critical first, then Important)
    ↓
Use docs-updater agent ← MANDATORY for user-facing changes
    ↓
Commit with descriptive message
    ↓
Push and create PR
```

### When to Use Each Agent
- **code-reviewer**: Every code change, before commit
- **debug-specialist**: Every error, test failure, unexpected behavior
- **docs-updater**: After code review, before commit (for user-facing changes)

---

## 7. Pre-Commit Checklist

Before committing ANY code, verify:

- [ ] Tests written and passing
- [ ] Code reviewed by `code-reviewer` agent
- [ ] Test coverage meets 80% minimum
- [ ] Documentation updated (use `docs-updater` agent)
- [ ] No secrets or credentials in code
- [ ] Code follows language conventions
- [ ] Commit message is clear and descriptive
- [ ] No debugging code left (console.log, print statements, etc.)
- [ ] No commented-out code
- [ ] Linter passes with no errors

---

## 8. Language-Specific Configurations

### Go Projects
- Use `go fmt`, `go vet`, `golangci-lint`
- Follow effective Go guidelines
- Use Go modules for dependencies
- Test command: `go test ./... -race -cover`
- Build command: `go build`
- Minimum coverage: 80%

### Python Projects
- Use `black`, `ruff`, `mypy`
- Follow PEP 8
- Use type hints (Python 3.7+)
- Use virtual environments
- Test command: `pytest --cov --cov-report=term-missing`
- Minimum coverage: 80%

### JavaScript/TypeScript Projects
- Use ESLint, Prettier
- Use TypeScript strict mode
- Test command: `npm test` or `yarn test`
- Use Jest or Vitest for testing
- Minimum coverage: 80%
- Async/await over callbacks
- Proper error handling (try/catch, promise rejection)
- No `any` types in TypeScript
- Use const/let, never var

### HTML/CSS/Frontend Projects
**HTML Best Practices:**
- Use semantic HTML5 elements (`<article>`, `<section>`, `<nav>`, `<header>`, `<footer>`)
- Accessibility: WCAG 2.1 AA minimum
  - Alt text for images
  - ARIA labels where needed
  - Keyboard navigation support
  - Proper heading hierarchy (h1-h6)
  - Form labels and fieldsets
- Valid HTML (validate with W3C validator)
- Meta tags for SEO (title, description, Open Graph)
- Responsive images (`srcset`, `picture` element)
- Performance: lazy loading, preload critical resources

**CSS Best Practices:**
- Mobile-first responsive design
- Use CSS custom properties (variables)
- BEM or consistent naming methodology
- Avoid `!important` (use specificity correctly)
- Performance: minimize repaints/reflows, use transforms for animations
- Accessibility: sufficient color contrast (WCAG AA: 4.5:1)
- Cross-browser compatibility
- Use CSS Grid and Flexbox appropriately
- Organize: variables, resets, base, components, utilities
- Build command: compile Sass/Less if used

**Frontend Testing:**
- Component tests (Jest, Testing Library, Vitest)
- E2E tests (Playwright, Cypress) for critical paths
- Accessibility tests (axe, pa11y)
- Visual regression tests (optional)
- Browser compatibility testing
- Performance testing (Lighthouse, WebPageTest)

**Frontend Security:**
- Content Security Policy (CSP) headers
- Sanitize user-generated HTML (DOMPurify)
- Avoid `innerHTML` with user data (use `textContent`)
- HTTPS only, secure cookies (HttpOnly, Secure, SameSite)
- Subresource Integrity (SRI) for CDN resources

### Rust Projects
- Use `rustfmt`, `clippy`
- Test command: `cargo test`
- Build command: `cargo build --release`
- Follow Rust API guidelines

---

## 9. Continuous Integration Expectations

All projects should have CI that:
- Runs on every push
- Runs all tests
- Checks code coverage
- Runs linters
- Builds the project
- Blocks merge if checks fail

---

## 10. Project-Specific Overrides

Individual projects can override these standards by creating:
- `./.claude/CLAUDE.md` - Project-specific guidelines
- `./CLAUDE.local.md` - Personal project preferences (gitignored)

To reference these global standards from a project:
```markdown
# Project-Specific CLAUDE.md

See @~/.claude/CLAUDE.md for global development standards.

## Project-Specific Additions
[Add project-specific guidelines here]
```

---

## Summary

**Every code change must:**
1. Include tests (80%+ coverage)
2. Be reviewed by `code-reviewer` agent
3. Update documentation (use `docs-updater` agent)
4. Follow language conventions
5. Be committed with clear message
6. Have no secrets or sensitive data

**Every error must:**
1. Be investigated with `debug-specialist` agent
2. Be fixed with tests preventing recurrence
3. Be documented if architectural

**Security is mandatory, not optional.**

---

## Context hygiene

If the current task is complete, or if a new task appears unrelated to the previous one,
explicitly suggest that the user run `/clear` before continuing.

If context has grown large and only a small subset is still relevant,
suggest `/compact` and describe what would be preserved.
