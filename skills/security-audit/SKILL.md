---
name: security-audit
description: Audit code and dependencies for security vulnerabilities. Use when reviewing PRs, checking dependencies, preparing for deployment, or when user mentions security, vulnerabilities, or audit.
model: sonnet
argument-hint: "[file-or-directory]"
allowed-tools: Read, Grep, Glob, Bash(grep *), Bash(npm audit), Bash(pip-audit), Bash(govulncheck *), Bash(cargo audit), Bash(git log *)
---

# Security Audit Skill

Perform comprehensive security audits on codebases to identify vulnerabilities before they reach production.

**Note**: This skill integrates with the `code-reviewer` agent for detailed code analysis.

## When to Use This Skill

- User mentions "security", "audit", "vulnerability", "CVE"
- Before deployment commands
- During PR reviews (alongside code-reviewer agent)
- User asks about dependencies
- Periodic security checks

## Integration with code-reviewer Agent

For comprehensive security reviews, use both:
1. This skill for systematic vulnerability scanning
2. `code-reviewer` agent for in-depth code analysis

## Audit Checklist

### 1. Secrets Exposure

**Check for hardcoded secrets:**
```bash
# Search for common secret patterns
grep -rn "API_KEY\|SECRET\|TOKEN\|PASSWORD" --include="*.{js,ts,py,go,rb,java}" .
grep -rn "sk-\|pk_\|api_\|secret_" --include="*.{js,ts,py,go,rb,java}" .
```

**Verify .gitignore:**
```bash
# Ensure sensitive files are ignored
cat .gitignore | grep -E "\.env|secret|credential|\.pem|\.key"
```

**Check git history for leaked secrets:**
```bash
# Search recent commits
git log -p --all -S "API_KEY" --since="30 days ago"
```

Pass criteria:
- No hardcoded API keys, tokens, or passwords
- `.env` files in `.gitignore`
- No secrets in git history

### 2. Dependency Vulnerabilities

**Node.js:**
```bash
npm audit
```

**Python:**
```bash
pip-audit
# or
safety check
```

**Go:**
```bash
govulncheck ./...
```

**Rust:**
```bash
cargo audit
```

Pass criteria:
- No critical vulnerabilities
- No high vulnerabilities > 30 days old
- Dependencies updated within last 90 days

### 3. Input Validation (OWASP Top 10)

Check for:
- User inputs sanitized before use
- SQL queries use parameterized statements
- File paths validated and sandboxed
- HTML content escaped before rendering
- Command injection prevention

**Vulnerable patterns to find:**

```javascript
// BAD: SQL injection
db.query(`SELECT * FROM users WHERE id = ${userId}`)

// GOOD: Parameterized query
db.query('SELECT * FROM users WHERE id = ?', [userId])
```

```python
# BAD: Command injection
os.system(f"convert {user_file}")

# GOOD: Use subprocess with list
subprocess.run(["convert", user_file], check=True)
```

### 4. Authentication & Authorization

Check for:
- Passwords hashed with bcrypt/argon2 (not MD5/SHA1)
- Session tokens are cryptographically random
- Sessions expire appropriately
- CSRF protection on state-changing endpoints
- Rate limiting on auth endpoints
- Account lockout after failed attempts

### 5. HTTPS & Transport Security

Check for:
- HTTPS enforced (HSTS header)
- Secure cookie flags (`Secure`, `HttpOnly`, `SameSite`)
- No mixed content warnings
- TLS 1.2+ required

### 6. Error Handling

Check for:
- Stack traces not exposed in production
- Generic error messages for users
- Detailed errors only in logs
- Sensitive data not in error messages

### 7. File Upload Security

If file uploads exist:
- Validate file type server-side (not just extension)
- Limit file size
- Scan for malware
- Store outside webroot
- Rename uploaded files

### 8. API Security

- Authentication required on all sensitive endpoints
- Authorization checks per resource
- Rate limiting implemented
- CORS configured restrictively
- API versioning in place

## Severity Levels

| Level | Description | Action Required |
|-------|-------------|-----------------|
| Critical | Actively exploitable | Block deployment |
| High | Exploitable with effort | Fix within 7 days |
| Medium | Requires conditions | Fix within 30 days |
| Low | Minimal impact | Fix when convenient |

## Output Format

```markdown
## Security Audit Results

**Project:** [name]
**Date:** [date]
**Auditor:** Claude (automated)

### Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 1 |
| Medium | 2 |
| Low | 3 |

### Findings

#### 1. [High] Hardcoded API Key

**Location:** `src/config.js:15`
**Description:** API key for payment provider is hardcoded
**Risk:** If source code is leaked, attackers gain API access
**Recommendation:** Move to environment variable

#### 2. [Medium] Missing Rate Limiting

**Location:** `src/routes/auth.js`
**Description:** Login endpoint has no rate limiting
**Risk:** Enables brute force attacks
**Recommendation:** Add rate limiting middleware

### Recommendations

1. [ ] Fix critical and high issues before next deployment
2. [ ] Schedule medium issues for next sprint
3. [ ] Add low issues to backlog
4. [ ] Re-run audit after fixes
```

## Follow-up Actions

After completing the audit:

1. Summary of findings
2. Prioritized fix list
3. Commands to address each issue
4. Use `code-reviewer` agent for detailed fix review
