# Logging & Error Handling — OWASP Security Reference
<!-- Sources: Logging, Logging Vocabulary, Error Handling Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### What to Log (Security Events)
- Authentication: all successes AND failures
- Authorization: access control violations, privilege changes
- Input validation: rejected inputs, protocol violations
- Administrative: user management, config changes, default account use
- Sensitive operations: key rotation, data export, file uploads
- System events: startup/shutdown, errors, connectivity issues
- Business logic: out-of-order actions, suspicious patterns

### What Never to Log
- Passwords, credentials, access tokens, API keys
- Session identifiers (use salted hash if needed for correlation)
- Encryption keys and secrets
- Database connection strings
- Payment card data (PCI DSS)
- Government IDs, health data, PII (unless legally authorized)
- Application source code

### Log Entry Structure (who/what/when/where)
- **When**: ISO 8601 timestamp, interaction/correlation ID
- **Where**: Application name + version, hostname, service name, URL/page
- **Who**: User identity (authenticated), source IP, device identifier
- **What**: Event type, severity level, description, result status, reason

### Log Injection Prevention
- Sanitize all log data: strip CR (`\r`), LF (`\n`), and delimiter characters
- Validate event data from other trust zones
- Encode data appropriately for log output format
- Use structured logging (JSON) to prevent format injection

### Error Handling
- Generic error messages to users; never expose stack traces in production
- Detailed errors only in server-side logs
- No sensitive data in error messages (connection strings, internal paths, user data)
- Use framework-provided error handlers; don't build custom ones
- Catch specific exceptions; avoid bare `except:` / `catch(Exception e)`

### Monitoring Requirements
- Centralized log management (SIEM integration)
- Real-time alerting on: auth failures, access denied spikes, input validation anomalies
- Tamper detection on log storage
- Secure log transmission (TLS)
- Time synchronization across all logging systems

## Vulnerable Patterns

```python
# BAD: Logging sensitive data
logger.info(f"User {username} logged in with password {password}")
logger.debug(f"DB connection: {conn_string}")

# GOOD: Redact sensitive fields
logger.info(f"User {username} logged in successfully")
logger.debug("DB connection established")
```

```javascript
// BAD: Stack trace in API response
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.stack });
});

// GOOD: Generic response, detailed logging
app.use((err, req, res, next) => {
  logger.error({ err, requestId: req.id }, 'Internal error');
  res.status(500).json({ error: 'An internal error occurred' });
});
```

```python
# BAD: Log injection
logger.info(f"User input: {user_input}")  # user_input contains \nINFO: Admin logged in

# GOOD: Structured logging
logger.info("User input received", extra={"input": user_input.replace('\n', '\\n')})
```

## Checklist
- [ ] Auth events (success + failure) logged with user identity and IP
- [ ] Access control violations logged
- [ ] No passwords, tokens, keys, PII in logs
- [ ] Log entries use structured format (JSON) with timestamp + correlation ID
- [ ] Log data sanitized (no CR/LF injection)
- [ ] Stack traces not exposed in API/UI error responses
- [ ] Error messages don't reveal internal paths, DB details, or user data
- [ ] Centralized log collection configured
- [ ] Log integrity protection (read-only storage or tamper detection)

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Vocabulary_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html
- ASVS: V7 (Error Handling and Logging)
