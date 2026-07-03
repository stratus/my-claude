# Reliability Standards

A change isn't done when it works on the happy path. It's done when you know how it
fails, how you'll see the failure, and how you'll get back to working. This reference
distills Google's SRE Book / SRE Workbook, Nygard's *Release It!*, and Beyer's
*Implementing Service Level Objectives* into a planning lens applied at `/plan` time.
It loads on demand (from the `/plan` skill, the `reliability-engineer` agent, and
`/ansible-audit`) rather than into every session.

See also: `rules/security.md` (security review areas), `rules/testing.md` (test
pyramid and integration tests at real boundaries), `rules/definition-of-done.md`
(operational doc / failure mode requirements for infra projects).

---

## Core Concepts

- **SLI** — what you measure (request latency, error rate, freshness)
- **SLO** — the threshold the SLI must stay within over a window (e.g., p99 < 300ms over 30 days)
- **Error budget** — `1 − SLO`. The acceptable amount of unreliability before you stop shipping features and pay down risk
- **Four golden signals** — latency, traffic, errors, saturation. Every production service needs all four
- **Blast radius** — the fraction of users / requests / data affected when this change misbehaves
- **Graceful degradation** — partial functionality during dependency failure beats total outage

A change with no SLO is unmeasurable; a change with no observability is undebuggable;
a change with no rollback is unrecoverable. All three matter at planning time.

---

## Failure Modes (think before you ship)

Every external call, every async boundary, every shared resource is a failure mode:

- **Timeouts** — every network call has an explicit timeout. No timeout = infinite hang.
- **Retries** — only retry idempotent operations. Always use exponential backoff *with jitter*. Cap retry budget.
- **Circuit breakers** — when a dependency is failing, stop calling it. Fail fast > pile up.
- **Bulkheads** — isolate resource pools so one slow dependency doesn't starve everything.
- **Retry storms** — synchronized retries amplify outages. Jitter, backoff, and budget caps prevent thundering herd.
- **Cold caches / cold starts** — performance after restart is not steady-state performance. Plan for it.
- **Partial failures** — distributed systems fail partially far more than totally. Code must handle "some succeeded, some didn't".
- **Poison pills** — one bad message must not stop the queue. Dead-letter or skip after N retries.

---

## Observability

You can't fix what you can't see. For any production-impacting change:

- **Metrics**: latency (histogram, not avg), traffic (rps), errors (rate + classification), saturation (CPU/mem/queue depth)
- **Logs**: structured (JSON), include trace ID + request ID, no PII, log at decision points not in tight loops
- **Traces**: propagate trace context across every async boundary; without it, distributed bugs are unsolvable
- **Alerts**: alert on symptoms (SLO burn rate) not causes (CPU spike). Page humans only when human action is required.

Dashboards are for debugging; alerts are for paging. Don't conflate them.

---

## Rollback & Blast Radius

- **Reversibility** — can this change be rolled back with one command/flag/click?
- **DB migrations** — additive first (add column nullable, deploy, backfill, deploy code, drop old). Never destructive in a single deploy.
- **Feature flags** — gate risky changes behind flags so rollback is a config change, not a redeploy
- **Canary / progressive rollout** — 1% → 10% → 50% → 100%, each step gated on SLO health
- **Kill switch** — for any new external integration, have a way to disable it without a deploy

---

## Capacity & Load

- **Headroom** — services should run at <50% of their saturation point at peak; 50–80% is yellow; >80% is red
- **Load tested** — at minimum 2× expected peak. Untested capacity is theoretical capacity.
- **Graceful degradation under load** — shed load (return 503), don't let queues grow unbounded
- **Autoscaling** — scales on the right signal (queue depth or saturation, not CPU alone); has minimum floor for cold-start protection

---

## Reliability Checklist for Plans

Apply during `/plan` Step 4. A plan that can't tick these doesn't go to `/implement`:

- [ ] **SLI/SLO defined** — what does "working" mean as a number?
- [ ] **Error budget impact** — does this burn budget faster than it earns it?
- [ ] **Failure modes enumerated** — top 3 ways this fails in production are listed with mitigations
- [ ] **Idempotency & retry safety** — retries are safe; backoff + jitter; retry budget capped
- [ ] **Timeouts on every external call** — no infinite waits anywhere in the design
- [ ] **Observability** — golden signals instrumented; trace IDs propagated; structured logs
- [ ] **Alerting** — SLO-burn alert (or equivalent) defined; no symptom-free silent failures
- [ ] **Rollback** — single command/flag rollback; DB migrations reversible; feature-flagged
- [ ] **Blast radius** — failure affects the smallest possible audience; canary plan exists
- [ ] **Capacity** — load tested at 2× peak; saturation point known; degradation path defined
- [ ] **Runbook** — top 2 failure modes have a written recovery procedure
- [ ] **Dependencies** — every external call has timeout + retry policy + fallback

---

## When This Doesn't Apply

Reliability is judgment-heavy, not binary. For internal tools, prototypes, scripts,
and config repos with no production runtime, most of this is overkill. The
`reliability-engineer` agent and `/plan` Step 3b explicitly allow skipping with a
written reason. Don't perform reliability theater on a Makefile change.
