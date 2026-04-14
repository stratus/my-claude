# API & Transport Security — OWASP Security Reference
<!-- Sources: REST Security, GraphQL, HTTP Headers, HSTS, Content Security Policy Cheat Sheets -->
<!-- Last synced: 2026-04-14 -->

## Quantified Criteria

### HSTS (HTTP Strict Transport Security)
- `max-age=63072000` (2 years) for production; `86400` (1 day) during rollout
- Include `includeSubDomains` directive
- Add `preload` only if you're certain you won't revert to HTTP (permanent)

### Content Security Policy
- Strict policy: `script-src 'nonce-{RANDOM}' 'strict-dynamic'`
- Basic policy minimum: `default-src 'self'`
- `frame-ancestors 'none'` (prevents clickjacking)
- `base-uri 'none'` (prevents base tag hijacking)
- `form-action 'self'` (restricts form submissions)
- **Never use**: `unsafe-inline`, `unsafe-eval`

### Security Headers (all responses)
- `Strict-Transport-Security: max-age=63072000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `Content-Security-Policy: <strict policy>`
- `X-Frame-Options: DENY` (legacy; prefer CSP frame-ancestors)
- `Cache-Control: no-store` on sensitive responses

### REST API Security
- HTTPS on all endpoints — no exceptions
- Validate JWT claims: `iss`, `aud`, `exp`, `nbf`; reject `{"alg":"none"}`
- Set request size limits; reject oversized with HTTP 413
- Return 405 for disallowed HTTP methods
- Return 429 on rate limit exceeded
- Return generic errors; no stack traces or internal details
- Keep credentials/tokens/keys out of URLs — use headers or body

### GraphQL Security
- **Depth limiting**: set max nesting (use graphql-depth-limit or equivalent)
- **Complexity analysis**: assign costs to field resolution; reject expensive queries
- **Batching limits**: restrict queries per request to prevent brute-force
- **Timeouts**: 10s query timeout typical; configure at app and infrastructure level
- **Disable introspection** in production
- **Disable GraphiQL/playground** in production
- **Disable field suggestions** (did-you-mean) when introspection is off
- Authorize both edges and nodes; field-level access control
- Set `debug: false` / `NODE_ENV=production`

### CORS
- Disable CORS headers if cross-origin requests not needed
- Never reflect `Origin` header as `Access-Control-Allow-Origin`
- Never use `Access-Control-Allow-Origin: *` with credentials
- Specify exact origins in allowlist

## Vulnerable Patterns

```javascript
// BAD: Permissive CORS
app.use(cors({ origin: true, credentials: true }));

// GOOD: Strict CORS
app.use(cors({
  origin: ['https://app.example.com'],
  credentials: true,
  methods: ['GET', 'POST']
}));
```

```python
# BAD: No JWT algorithm validation
payload = jwt.decode(token, SECRET, algorithms=["HS256", "none"])

# GOOD: Strict algorithm
payload = jwt.decode(token, SECRET, algorithms=["HS256"])
```

```javascript
// BAD: GraphQL with no limits
const server = new ApolloServer({ typeDefs, resolvers });

// GOOD: Depth + complexity limits
import depthLimit from 'graphql-depth-limit';
import { createComplexityLimitRule } from 'graphql-validation-complexity';
const server = new ApolloServer({
  typeDefs, resolvers,
  validationRules: [depthLimit(10), createComplexityLimitRule(1000)]
});
```

## Checklist
- [ ] HSTS header with max-age ≥63072000 and includeSubDomains
- [ ] CSP header deployed; no unsafe-inline/unsafe-eval
- [ ] X-Content-Type-Options: nosniff on all responses
- [ ] CORS configured restrictively (exact origins, not wildcard)
- [ ] JWT algorithm validated server-side; "none" rejected
- [ ] Request size limits enforced (HTTP 413 on excess)
- [ ] Rate limiting returns 429; API keys revoked on abuse
- [ ] GraphQL: depth limiting, complexity analysis, introspection disabled in prod
- [ ] No sensitive data in URLs (use headers/body)
- [ ] Generic error responses; no stack traces in production

## Remediation References
- https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Strict_Transport_Security_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html
- https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html
- ASVS: V14 (Configuration), V13 (API)
