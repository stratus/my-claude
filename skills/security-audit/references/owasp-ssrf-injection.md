# SSRF & Command Injection — OWASP Security Reference
<!-- Sources: SSRF Prevention, OS Command Injection Defense, LDAP Injection Prevention, Injection Prevention Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### SSRF Prevention
- Allowlist permitted outbound hosts/IPs when destination is known
- For dynamic destinations: validate input + blocklist private ranges + verify resolved IPs
- Disable HTTP redirect following in outbound HTTP clients
- Require POST-only with authentication tokens for internal service calls

### IP Ranges to Block (SSRF)

| Range | Purpose |
|-------|---------|
| `127.0.0.0/8`, `::1/128` | Loopback |
| `0.0.0.0/8` | Current network |
| `10.0.0.0/8` | RFC1918 private |
| `172.16.0.0/12` | RFC1918 private |
| `192.168.0.0/16` | RFC1918 private |
| `169.254.169.254` | Cloud metadata (AWS, GCP, Azure) |
| `metadata.google.internal` | GCP metadata |
| `224.0.0.0/4`, `ff00::/8` | Multicast |

- AWS: use IMDSv2 (token-required) to mitigate metadata SSRF
- Validate both A and AAAA DNS records (prevent DNS rebinding)

### Command Injection Prevention
- **Primary defense**: avoid OS commands entirely; use language built-in libraries
- **Secondary**: use parameterized APIs that separate command from arguments
- **Tertiary**: allowlist permitted commands AND validate arguments
- Use `--` delimiter to mark end of options

### Dangerous Functions to Grep For

| Language | Dangerous | Safe Alternative |
|----------|-----------|-----------------|
| Python | `os.system()`, `os.popen()`, `subprocess.run(shell=True)` | `subprocess.run([cmd, arg], shell=False)` |
| Node.js | `child_process.exec()` | `child_process.execFile()`, `child_process.spawn()` |
| Java | `Runtime.exec(string)` | `ProcessBuilder` with argument list |
| PHP | `exec()`, `system()`, `passthru()`, `shell_exec()`, backticks | `escapeshellarg()` + hardcoded command |
| Ruby | `system(string)`, backticks, `exec(string)` | `system(cmd, arg1, arg2)` (array form) |
| Go | `exec.Command` with shell | `exec.Command(cmd, args...)` directly |

### Shell Metacharacters to Block
`` & | ; $ > < ` \ ! ' " ( ) ``

### LDAP Injection
- Escape special characters: `*`, `(`, `)`, `\`, NUL
- Use parameterized LDAP queries where available
- Validate input against allowlist of expected characters

## Vulnerable Patterns

```python
# BAD: SSRF — user controls URL
response = requests.get(user_provided_url)

# GOOD: Allowlist + post-resolution IP check
import ipaddress, socket
from urllib.parse import urlparse

ALLOWED_HOSTS = {'api.example.com', 'cdn.example.com'}
BLOCKED_NETS = [ipaddress.ip_network(n) for n in [
    '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',
    '127.0.0.0/8', '169.254.0.0/16'
]]

parsed = urlparse(user_provided_url)
if parsed.hostname not in ALLOWED_HOSTS:
    raise ValueError("Destination not allowed")
# Verify resolved IP is not private (prevents DNS rebinding)
resolved_ip = ipaddress.ip_address(socket.getaddrinfo(parsed.hostname, None)[0][4][0])
if any(resolved_ip in net for net in BLOCKED_NETS):
    raise ValueError("Resolved to blocked IP range")
response = requests.get(user_provided_url, allow_redirects=False)
```

```python
# BAD: Command injection
os.system(f"convert {user_filename} output.png")

# GOOD: Parameterized subprocess
subprocess.run(["convert", user_filename, "output.png"], check=True)
```

```javascript
// BAD: Command injection via exec
const { exec } = require('child_process');
exec(`grep ${userInput} /var/log/app.log`);

// GOOD: execFile with arguments array
const { execFile } = require('child_process');
execFile('grep', [userInput, '/var/log/app.log']);
```

## Checklist
- [ ] Outbound HTTP requests use allowlist of permitted hosts/IPs
- [ ] Private IP ranges blocked for user-controlled URLs (see table above)
- [ ] Cloud metadata endpoint (169.254.169.254) blocked
- [ ] HTTP redirect following disabled on outbound requests
- [ ] No `os.system()`, `exec()`, `shell=True` with user-controlled input
- [ ] Commands use parameterized APIs (argument arrays, not string concatenation)
- [ ] DNS resolution results validated against blocklist
- [ ] LDAP queries parameterized; special characters escaped
- [ ] Shell metacharacters stripped or rejected from all user input reaching OS

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/LDAP_Injection_Prevention_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html
- ASVS: V5.3 (Output Encoding), V5.2 (Sanitization)
