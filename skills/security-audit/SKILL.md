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

## OWASP Reference Loading

After completing initial scans, load detailed OWASP guidance for categories where findings were detected or the tech stack warrants deeper review. Read the reference file relative to this skill's directory.

| Signal (grep/glob patterns in codebase)                  | Read reference file                          |
|----------------------------------------------------------|----------------------------------------------|
| `*auth*`, `*login*`, `*session*`, `*cookie*`, `*password*` | `references/owasp-auth-session.md`         |
| `*input*`, `*sanitiz*`, `*validat*`, `*query*`, `*xss*`, `*csrf*` | `references/owasp-input-validation.md` |
| `*crypt*`, `*hash*`, `*cipher*`, `*tls*`, `*ssl*`, `*secretkey*`, `*apikey*` | `references/owasp-cryptography.md` |
| `*api*`, `*endpoint*`, `*cors*`, `*graphql*`, `*rest*`   | `references/owasp-api-transport.md`          |
| `*upload*`, `*deserializ*`, `*xml*`, `*parse*`, `*pickle*`, `*unserialize*` | `references/owasp-file-deserialization.md` |
| `*logger*`, `*logging*`, `*sentry*`, `*audit_log*`       | `references/owasp-logging-errors.md`         |
| `*fetch*`, `*request*`, `*urllib*`, `*httpClient*`, `*redirect*` | `references/owasp-ssrf-injection.md`  |

Reference files are deployed to `~/.claude/commands/security-audit/references/<name>.md`. Use the Read tool with this absolute path.

Use quantified criteria from loaded references as pass/fail thresholds in findings. Include OWASP cheat sheet URLs in remediation recommendations.

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

**References:** [Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

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

**References:** [Vulnerable Dependency Management](https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html)

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

**References:** [Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html), [SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html), [XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)

### 4. Authentication & Authorization

Check for:
- Passwords hashed with argon2id (preferred), bcrypt (cost ≥10), or scrypt — not MD5/SHA1/plain SHA256
- Session tokens generated with CSPRNG, ≥64 bits entropy
- Session timeouts configured (details in section 9)
- CSRF tokens on all state-changing endpoints (synchronizer token or signed double-submit)
- Rate limiting on auth endpoints
- Account lockout with exponential backoff after repeated failures
- Generic error messages that don't reveal account existence

**References:** [Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html), [Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), [CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)

### 5. HTTPS & Transport Security

Check for:
- HSTS header: `max-age≥63072000; includeSubDomains`
- Secure cookie flags: `Secure`, `HttpOnly`, `SameSite=Strict` or `Lax`
- No mixed content warnings
- TLS 1.2+ required; SSLv3/TLS 1.0/1.1 disabled
- CSP header deployed; no `unsafe-inline` or `unsafe-eval`
- `X-Content-Type-Options: nosniff` on all responses

**References:** [HSTS](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html), [CSP](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html), [TLS](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html)

### 6. Error Handling

Check for:
- Stack traces not exposed in production
- Generic error messages for users
- Detailed errors only in logs
- Sensitive data not in error messages (no connection strings, internal paths, user data)

**References:** [Error Handling](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html), [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)

### 7. File Upload Security

If file uploads exist:
- Validate file type server-side by magic bytes (not just extension)
- Limit file size
- Scan for malware
- Store outside webroot
- Rename uploaded files with server-generated names
- Prohibit dangerous extensions: `.asp`, `.jsp`, `.php`, `.js`, `.html`, `.htaccess`

**References:** [File Upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)

### 8. API Security

- Authentication required on all sensitive endpoints
- Authorization checks per resource
- Rate limiting implemented (429 on excess)
- CORS configured restrictively (exact origins, no wildcard with credentials)
- JWT: validate `iss`, `aud`, `exp`; reject `alg: none`
- Request size limits enforced (413 on excess)
- GraphQL: depth limiting, complexity analysis, introspection disabled in prod

**References:** [REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html), [GraphQL](https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html)

### 9. Session Management

Check for:
- Session ID regenerated after login and privilege changes
- Session IDs generated with CSPRNG (≥64 bits entropy)
- Cookie attributes: `Secure`, `HttpOnly`, `SameSite`, no `Domain` unless needed
- Non-persistent cookies (no Expires/Max-Age on session cookies)
- Idle timeout configured (2-5 min high-value, 15-30 min low-risk)
- Absolute timeout configured (4-8 hours typical)
- `Cache-Control: no-store` on authenticated responses
- Session invalidated on logout (server-side destruction)

**References:** [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)

### 10. SSRF Prevention

If outbound HTTP requests exist:
- User-controlled URLs validated against allowlist of permitted hosts
- Private IP ranges blocked: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`
- Cloud metadata endpoint blocked: `169.254.169.254`
- HTTP redirect following disabled on outbound requests
- DNS resolution results validated (prevent DNS rebinding)

**References:** [SSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)

### 11. Deserialization Safety

Check for unsafe deserialization by language:
- **Java**: `ObjectInputStream.readObject()`, `XMLDecoder`, `XStream.fromXML()`
- **Python**: `pickle.load/loads`, `PyYAML.load()` (use `safe_load`)
- **PHP**: `unserialize()` with user input
- **.NET**: `BinaryFormatter`, uncontrolled `TypeNameHandling`
- If deserialization of untrusted data required: allowlist permitted classes

**References:** [Deserialization](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)

### 12. Logging & Monitoring

Check for:
- Auth events (success + failure) logged with user identity and source IP
- Access control violations logged
- No passwords, tokens, keys, PII in log output
- Log injection prevented (CR/LF stripped from user data in log entries)
- Stack traces not exposed in API/UI responses
- Structured logging format (JSON with timestamp + correlation ID)

**References:** [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)

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
**OWASP Reference:** [Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
**Recommendation:** Move to environment variable or secrets vault

#### 2. [Medium] Missing Rate Limiting

**Location:** `src/routes/auth.js`
**Description:** Login endpoint has no rate limiting
**Risk:** Enables brute force attacks
**OWASP Reference:** [Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
**Recommendation:** Add rate limiting middleware; return 429 on excess

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
