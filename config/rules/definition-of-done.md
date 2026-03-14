---
description: Definition of Done checklists — verify before marking any task complete
globs: "**/*"
---

# Definition of Done

**Nothing is "done" until these are verified.** Check applicable items before marking complete.

## All Projects
- [ ] README enables clone-to-running in <5 minutes (test mentally or actually)
- [ ] A new engineer unfamiliar with the project can understand what it does and how to use it
- [ ] All documented commands/steps actually work (no stale instructions)
- [ ] Error messages are actionable (user knows what went wrong and how to fix)

## Web Applications
- [ ] Core user flows work end-to-end (not just API endpoints)
- [ ] Basic UI states handled: loading, empty, error, success
- [ ] Can demonstrate the happy path manually in browser
- [ ] Forms have validation with user-visible feedback
- [ ] Navigation between features works

## CLI Tools / Libraries
- [ ] `--help` output is accurate and useful
- [ ] At least one realistic usage example in README
- [ ] Exit codes are meaningful (0 = success, non-zero = failure)
- [ ] Errors print to stderr, output to stdout

## Infrastructure / Automation
- [ ] Runbook or operational doc exists for non-obvious operations
- [ ] Failure modes documented (what breaks, how to recover)
- [ ] Dependencies and prerequisites explicitly listed
