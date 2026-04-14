---
description: Security standards — mandatory review areas, OWASP prevention, best practices
globs: "**/*"
---

# Security Standards

## Mandatory Review Areas
Auth, validation, APIs, database queries, file operations, crypto, sessions, CORS

## Best Practices
- Never commit secrets (.env, API keys, credentials)
- Validate all inputs (user, API, files, env vars)
- Use secure defaults, least privilege, defense in depth
- Fail securely (no sensitive info in errors)

## Prevent OWASP Top 10
SQL injection, XSS, CSRF, insecure deserialization, XXE, SSRF, command injection, path traversal

## Frontend Security
CSP headers, sanitize HTML (DOMPurify), no innerHTML with user data, HTTPS only

## OWASP Detailed Guidance
Quantified security criteria in `~/.claude/commands/security-audit/references/` — loaded automatically by the `/security-audit` skill based on detected tech stack.
