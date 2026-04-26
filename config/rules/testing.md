---
description: Testing standards — coverage requirements, test types, quality gates, anti-patterns, advanced techniques
globs: "**/*.{test,spec}.*"
---

# Testing Standards

## Coverage Requirements
- **80% minimum** coverage (100% for security/validation code)
- Coverage measures *execution*, not correctness — a test without assertions still counts. Pair coverage numbers with quality checks below.

## Test Types & Pyramid
- **Unit tests**: individual functions, mock external dependencies, fast (<10ms each)
- **Integration tests**: component interactions, API contracts, real boundaries (no mocked DBs)
- **Smoke tests**: For web apps, at least one test that verifies the app starts and serves the main page
- **Pyramid balance**: many unit → some integration → few E2E. If 80%+ coverage comes from E2E alone, the suite will be slow and fragile.

## Test Quality Standards

### Naming — tests are specifications
Name tests after *behavior*, not implementation:
- ✅ `should_reject_negative_amount_when_withdrawing`
- ✅ `returns_empty_list_when_no_matching_records`
- ❌ `test_withdraw`, `test_1`, `testFunctionWorks`

### Assertions
- Every test must have at least one meaningful assertion. Assertion-free tests always pass and catch nothing.
- Assert on *observable outcomes* (return values, state changes, side effects) — not internal implementation details.
- One behavior per test. A test asserting 10 unrelated things pinpoints nothing when it fails.

### Anti-Patterns to Avoid
- **Testing internals**: asserting on private state or internal method calls — tests break on safe refactors, not real regressions
- **Over-mocked tests**: if every dependency is mocked, you're testing mock configuration, not code behavior
- **Shared mutable state**: tests depending on execution order fail randomly (flakiness)
- **Time bombs**: hardcoded `Date.now()` / `datetime.now()` without time mocking will fail eventually
- **Magic data**: use realistic values (`user@example.com`, `$99.99`) not `"abc"` and `123`

### Test Doubles — when to use what
- **Mock** external services (HTTP calls, email, payment APIs) — real costs and side effects
- **Fake** (in-memory implementation) for stateful dependencies (DB, cache) in unit tests — more maintainable than mocks
- **Don't mock** the subject under test, internal business logic, or the database in integration tests
- **Stub** for read-only dependencies where return value matters but verification doesn't

## TDD
- TDD preferred: write the failing test first, make it pass, then refactor
- Install `claude plugin add nizos/tdd-guard` to enforce the red-green-refactor cycle via hooks

## Advanced Techniques (especially for 100%-coverage security/validation code)
- **Mutation testing**: Stryker (JS/TS), mutmut (Python), cargo-mutants (Rust) — mutates source to verify tests actually catch bugs, not just execute lines
- **Property-based testing**: fast-check (TS/JS), Hypothesis (Python) — generates adversarial inputs automatically; far more thorough than hand-written examples for boundary and validation logic

## Flakiness
- A flaky test is worse than no test — it trains the team to ignore red CI
- Isolate time with `jest.useFakeTimers()` / `freezegun` / `time-machine`; never use `sleep()` in tests
- Use await-driven assertions or retries with exponential backoff, never fixed waits
- Track flaky tests; fix or delete within one sprint

## Environment Splitting
- Pure logic tests should run in `node` environment, not `jsdom`/`happy-dom`. jsdom init is ~16s overhead.
- Split via vitest `test.projects` or jest `projects` so only component/DOM tests pay it
