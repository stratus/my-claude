# Input Validation & Injection Prevention — OWASP Security Reference
<!-- Sources: Input Validation, SQL Injection Prevention, XSS Prevention, CSRF Prevention, Unvalidated Redirects Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### Input Validation
- Server-side validation is mandatory; client-side is UX only
- Allowlist approach primary; denylist supplementary only
- Syntactic validation (format) AND semantic validation (business logic)
- Anchor regex with `^...$`; specify min/max length; avoid `.` and `\S` wildcards
- Check for ReDoS in all regex patterns (nested quantifiers, overlapping alternations)
- Email: local part ≤63 chars, total ≤254 chars, confirmation token ≥32 chars

### SQL Injection Prevention
- Parameterized queries / prepared statements: mandatory for all DB interaction
- Stored procedures: safe only without internal dynamic SQL
- Allowlist validation for dynamic elements (table names, sort order)
- Escaping: last resort only, fragile and DB-specific
- Least privilege: separate DB accounts per application, no admin credentials

### XSS Prevention
- Output encode all user data based on context (HTML body, attribute, JS, CSS, URL)
- Use framework auto-escaping (React JSX, Angular templates, Go html/template)
- Sanitize HTML with allowlist libraries (DOMPurify, Bleach) — never regex
- Set `Content-Type` and `X-Content-Type-Options: nosniff` on all responses
- CSP with nonces or hashes; avoid `unsafe-inline` and `unsafe-eval`

### CSRF Prevention
- Synchronizer token pattern for stateful apps (token per session, unpredictable)
- Signed double-submit cookie (HMAC with server secret) for stateless apps
- `SameSite=Strict` or `Lax` on all session cookies as defense-in-depth
- Never use GET for state-changing operations
- Verify `Origin`/`Referer` headers as secondary defense
- Framework built-in CSRF protection preferred (Django, Rails, Spring)

### Redirect Validation
- Allowlist valid redirect destinations server-side
- Never use user input directly in redirect target
- Map redirect targets to indices/keys, not URLs

## Vulnerable Patterns

```java
// BAD: SQL injection
String query = "SELECT * FROM users WHERE id = " + userId;
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery(query);

// GOOD: Parameterized query
PreparedStatement pstmt = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
pstmt.setString(1, userId);
ResultSet rs = pstmt.executeQuery();
```

```python
# BAD: Template injection / XSS
return f"<div>Welcome {username}</div>"

# GOOD: Use framework escaping
from markupsafe import escape
return f"<div>Welcome {escape(username)}</div>"
```

```javascript
// BAD: Open redirect
res.redirect(req.query.returnUrl);

// GOOD: Allowlist redirect
const ALLOWED = ['/dashboard', '/profile', '/settings'];
const target = ALLOWED.includes(req.query.returnUrl) ? req.query.returnUrl : '/';
res.redirect(target);
```

## Checklist
- [ ] All DB queries use parameterized statements (no string concatenation)
- [ ] All user output is context-encoded (HTML, JS, URL, CSS)
- [ ] Server-side input validation on all endpoints (not just client-side)
- [ ] Allowlist validation preferred over denylist
- [ ] CSRF tokens on all state-changing forms/endpoints
- [ ] SameSite cookie attribute set on session cookies
- [ ] No open redirects (user input in redirect targets validated)
- [ ] Regex patterns checked for ReDoS vulnerability
- [ ] innerHTML/dangerouslySetInnerHTML only with sanitized content
- [ ] Content-Security-Policy header deployed

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html
- ASVS: V5 (Validation), V13 (API)
