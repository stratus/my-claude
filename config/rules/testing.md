---
description: Testing standards — coverage requirements, test types, environment splitting
globs: "**/*.{test,spec}.*"
---

# Testing Standards

- **80% minimum** coverage (100% for security/validation code)
- Unit tests: individual functions, mock dependencies, fast
- Integration tests: component interactions, API contracts
- Edge cases: null, empty, boundaries, errors, concurrency
- **Smoke tests**: For web apps, at least one test that verifies the app starts and serves the main page
- TDD preferred, tests alongside implementation
- **Environment splitting**: Pure logic tests should run in `node` environment, not `jsdom`/`happy-dom`. jsdom init is ~16s overhead — split via vitest `test.projects` or jest `projects` so only component/DOM tests pay it
