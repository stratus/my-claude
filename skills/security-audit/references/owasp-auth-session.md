# Authentication & Session Management — OWASP Security Reference
<!-- Sources: Authentication, Password Storage, Session Management, Credential Stuffing, MFA Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### Password Policy
- Min 8 chars with MFA enabled; min 15 chars without MFA
- Max length at least 64 chars (support passphrases)
- Allow all printable chars including unicode; no composition rules required
- Check against breached password lists (e.g., Have I Been Pwned API)

### Password Hashing
- **Argon2id** (preferred): min m=19MiB, t=2, p=1
- **scrypt**: min N=2^17 (128MiB), r=8, p=1
- **bcrypt**: min cost factor 10; max input 72 bytes
- **PBKDF2** (FIPS only): min 600,000 iterations with HMAC-SHA-256
- **Never use**: MD5, SHA-1, plain SHA-256, unsalted hashes

### Session Management
- Session ID entropy: minimum 64 bits (16 hex chars)
- Must use CSPRNG for ID generation
- Idle timeout: 2-5 min (high-value), 15-30 min (low-risk)
- Absolute timeout: 4-8 hours typical
- Regenerate session ID after: login, privilege change, password change

### Cookie Security
- `Secure` flag: required (HTTPS-only transmission)
- `HttpOnly` flag: required (no JS access)
- `SameSite`: Strict or Lax (CSRF mitigation)
- `Domain`: avoid setting (restrict to origin)
- Use non-persistent cookies (no Expires/Max-Age)

### Account Protection
- Generic error messages: "Login failed; Invalid user ID or password"
- Never reveal whether account exists vs wrong password
- Rate limiting on auth endpoints (no specific threshold — tune per app)
- Account lockout with exponential backoff after repeated failures

## Vulnerable Patterns

```python
# BAD: Weak hashing
hashlib.md5(password.encode()).hexdigest()
hashlib.sha256(password.encode()).hexdigest()

# GOOD: Argon2id
from argon2 import PasswordHasher
ph = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1)
hash = ph.hash(password)
```

```javascript
// BAD: No session regeneration after login
app.post('/login', (req, res) => {
  if (valid) req.session.user = user;  // same session ID!
});

// GOOD: Regenerate session
app.post('/login', (req, res) => {
  req.session.regenerate(() => { req.session.user = user; });
});
```

## Checklist
- [ ] Passwords hashed with argon2id/bcrypt/scrypt (not MD5/SHA)
- [ ] Hashing parameters meet minimum thresholds above
- [ ] Session IDs generated with CSPRNG, ≥64 bits entropy
- [ ] Session regenerated on authentication and privilege changes
- [ ] Cookie flags: Secure, HttpOnly, SameSite set
- [ ] Idle and absolute session timeouts configured
- [ ] Error messages don't leak account existence
- [ ] Rate limiting or lockout on login endpoint
- [ ] Passwords checked against breached-password list
- [ ] MFA available for sensitive operations

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Credential_Stuffing_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html
- ASVS: V2 (Authentication), V3 (Session Management)
