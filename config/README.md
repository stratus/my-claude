# Claude Code Configuration

This directory contains configuration and customization for Claude Code, the AI-powered terminal assistant.

## Directory Structure

- `CLAUDE.md` - Global development standards applied to all projects
- `PERMISSIONS-GUIDE.md` - Security and permissions guide
- `agents/` - Custom agents for specialized tasks
- `settings.json` - Minimal configuration template
- `config/` - Project-specific configurations (auto-created)
- `plans/` - Implementation plans (auto-created)

## Custom Agents

### code-reviewer

Reviews code for:
- Security vulnerabilities (OWASP Top 10, SQL injection, XSS, etc.)
- Test coverage (80% minimum required)
- Code quality and readability
- Best practices and language conventions

**Usage**: Run after writing code, BEFORE committing

**Critical Reviews**:
- Authentication and authorization code
- Data validation and sanitization
- API endpoints handling user data
- Database queries and ORM usage
- File system operations
- Cryptography and encryption

### debug-specialist

Helps with:
- Test failures and build errors
- Runtime exceptions and crashes
- Performance issues and bottlenecks
- Unexpected behavior
- Root cause analysis

**Usage**: Run when encountering ANY error or unexpected behavior

**Provides**:
- Comprehensive error analysis
- Root cause identification
- Suggested fixes with code examples
- Prevention strategies

### docs-updater

Updates:
- README.md and project documentation
- API documentation and examples
- Architecture diagrams and decisions
- Code examples and usage guides

**Usage**: Run after code review is complete, BEFORE committing

**Updates**:
- User-facing documentation for any code changes
- API docs when endpoints change
- Examples when interfaces change
- Architecture docs when design changes

## Development Workflow

The recommended workflow with Claude Code:

```bash
# 1. Write code and tests
vim myfile.go

# 2. Run tests locally
go test ./...

# 3. Review with code-reviewer agent (MANDATORY)
claude
# > Run code-reviewer agent

# 4. Address feedback (Critical → Important → Suggestions)
vim myfile.go

# 5. Update documentation with docs-updater agent (if user-facing changes)
claude
# > Run docs-updater agent

# 6. Commit changes
git add .
git commit -m "Add feature X"
```

## Development Standards

The `CLAUDE.md` file contains comprehensive development standards:

### Security Standards (Mandatory)
- **Never commit secrets**: No API keys, passwords, tokens
- **Validate all inputs**: User input, API responses, file uploads
- **Use secure defaults**: Secure by default, not opt-in
- **Principle of least privilege**: Minimal permissions required
- **Prevent OWASP Top 10**: SQL injection, XSS, CSRF, etc.

### Testing Standards (Required)
- **Minimum 80% test coverage** for all projects
- 100% coverage for security-critical code
- 100% coverage for data validation logic
- Unit tests, integration tests, edge cases

### Documentation Standards
- README.md (every project)
- Architecture documentation
- API documentation
- Code documentation for complex logic

### Code Readability Standards
- Descriptive naming (no abbreviations)
- Function length < 50 lines (max 100)
- Max 3-4 function parameters
- Cyclomatic complexity < 10
- Max 3-4 nesting levels

### Git Standards
- Atomic commits (one logical unit per commit)
- Present tense commit messages
- Reference issues: "Fixes #123"
- Review diffs before committing
- Never commit secrets or build artifacts

### Language-Specific Standards
- **Go**: go fmt, go vet, golangci-lint, effective Go
- **Python**: PEP 8, black, ruff, type hints
- **JavaScript/TypeScript**: ESLint, Prettier, strict mode
- **HTML/CSS**: Semantic HTML5, WCAG AA accessibility, responsive design
- **Rust**: rustfmt, clippy

### Agent Usage Workflow

Every code change MUST follow this workflow:

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

## Pre-Commit Checklist

Before committing ANY code, verify:

- [ ] Tests written and passing
- [ ] Code reviewed by code-reviewer agent
- [ ] Test coverage meets 80% minimum
- [ ] Documentation updated (use docs-updater agent)
- [ ] No secrets or credentials in code
- [ ] Code follows language conventions
- [ ] Commit message is clear and descriptive
- [ ] No debugging code left (console.log, print statements)
- [ ] No commented-out code
- [ ] Linter passes with no errors

## Configuration Location

When deployed to your system, these files will be copied to:

- **Configuration directory:** `~/.claude/`
- **Global standards:** `~/.claude/CLAUDE.md`
- **Custom agents:** `~/.claude/agents/`
- **Project plans:** `~/.claude/plans/` (auto-created)
- **Settings:** `~/.claude/settings.json`

## Learn More

- **Start Claude Code:** `claude`
- **Official Documentation:** https://claude.com/claude-code
- **Permissions Guide:** `~/.claude/PERMISSIONS-GUIDE.md`
- **Development Standards:** `~/.claude/CLAUDE.md`

## Customization

After bootstrap installation, you can customize:

1. **Machine-specific standards**: Edit `~/.claude/CLAUDE.md`
2. **Custom agents**: Create new `.md` files in `~/.claude/agents/`
3. **Settings**: Modify `~/.claude/settings.json`

Files are copied during bootstrap (not symlinked), so each machine can have different configurations.

## Updates

To update your configuration templates from this repository:

```bash
# Backup your current configuration
cp -r ~/.claude ~/.claude.backup

# Pull latest and reinstall
cd ~/my-claude
git pull
make install
```

The install script compares checksums and prompts before overwriting local changes.
