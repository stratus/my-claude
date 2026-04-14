# Cryptography — OWASP Security Reference
<!-- Sources: Cryptographic Storage, Key Management, TLS Cipher String Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### Symmetric Encryption
- **Use**: AES with at least 128-bit key (256-bit preferred)
- **Modes**: GCM or CCM (authenticated encryption, first choice)
- **Acceptable**: CTR or CBC with Encrypt-then-MAC
- **Never use**: ECB mode (leaks patterns in plaintext)

### Asymmetric Encryption
- **Preferred**: ECC with Curve25519 or P-256
- **RSA**: minimum 2048-bit key length
- **Ed25519** for digital signatures

### Key Management
- Generate keys with CSPRNG — never from keyboard input or dictionary words
- Separate Data Encryption Key (DEK) from Key Encryption Key (KEK)
- Store KEK separately from DEK; KEK strength ≥ DEK strength
- Rotate keys on: compromise, end of cryptoperiod, algorithm weakness discovered
- Use HSM or cloud vault (AWS KMS, Azure Key Vault, HashiCorp Vault) when possible
- Never hardcode keys in source; never commit to version control

### Secure Random Generation
| Language | Use | Avoid |
|----------|-----|-------|
| Java | `SecureRandom`, `UUID.randomUUID()` | `Random`, `Math.random()` |
| Python | `secrets` module | `random` module |
| Node.js | `crypto.randomBytes()`, `crypto.randomInt()` | `Math.random()` |
| Go | `crypto/rand` | `math/rand` |
| PHP | `random_bytes()` (7.0+) | `rand()`, `mt_rand()` |
| Ruby | `SecureRandom` | `rand` |

### TLS Configuration
- TLS 1.2 minimum; TLS 1.3 preferred
- Disable SSLv3, TLS 1.0, TLS 1.1
- Forward secrecy: prefer ECDHE key exchange
- Certificate: RSA ≥2048 or ECC ≥256 bit

## Vulnerable Patterns

```python
# BAD: ECB mode
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_ECB)

# GOOD: GCM mode (authenticated encryption)
cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
ciphertext, tag = cipher.encrypt_and_digest(plaintext)
```

```javascript
// BAD: Insecure random for tokens
const token = Math.random().toString(36);

// GOOD: Cryptographically secure
const token = crypto.randomBytes(32).toString('hex');
```

```go
// BAD: math/rand for secrets
import "math/rand"
token := rand.Int63()

// GOOD: crypto/rand
import crand "crypto/rand"
b := make([]byte, 32)
crand.Read(b)
```

## Checklist
- [ ] AES-128+ with GCM/CCM mode (no ECB)
- [ ] RSA ≥2048 bits or ECC with secure curve
- [ ] All random values for security use CSPRNG
- [ ] No hardcoded keys/secrets in source code
- [ ] Keys stored in vault/HSM or at minimum env vars with restricted access
- [ ] TLS 1.2+ enforced; older protocols disabled
- [ ] Key rotation policy exists and is followed
- [ ] DEK/KEK separation for stored encrypted data

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/TLS_Cipher_String_Cheat_Sheet.html
- ASVS: V6 (Cryptography)
