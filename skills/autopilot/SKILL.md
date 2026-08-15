---
name: autopilot
description: Execute an approved /plan unattended — phases, agents, commits — stopping only on hard safety failures (hook exit 2, sandbox/network deny, repeated test failures). Use after /plan when the user wants hands-off execution.
model: opus
argument-hint: "[plan slug, or omit to use most recent plan]"
# Always dispatched explicitly — by the user typing /autopilot, or by /plan
# emitting the literal text `/autopilot <slug>`. Never inferred from prose, so
# its description is dead weight in the skill listing (see the budget check in
# scripts/check-config.sh). disable-model-invocation drops it from that listing
# entirely while leaving /autopilot typable.
disable-model-invocation: true
---

<!-- ultrathink: keyword trigger required because alwaysThinkingEnabled=false in settings.json -->

# Autopilot Skill

Run an approved plan from end to end without per-phase confirmation. Stops only on real safety failures, never on routine ambiguity.

## When to Use This Skill

- Right after `/plan` is approved and the user wants to step away
- Manually invoked as `/autopilot [slug]` against any existing `~/.claude/plans/*.md` plan
- The plan's phases are well-scoped with `step → verify: check` clauses (autopilot relies on these to know each phase succeeded)

**Do NOT use** when:
- The plan still has ambiguous phases or unresolved interrogation questions — fix the plan first
- The change touches production systems beyond the local repo (autopilot does not auto-deploy)
- The user wants to review each phase before moving on — use `/implement` instead

## Process

> **No mid-run prompting.** This skill exists specifically to avoid `AskUserQuestion` after kickoff. The only acceptable pauses are the hard-stop conditions in section 6. For soft ambiguity, follow the rule in section 7.

### 1. Pre-flight

1. Resolve plan path:
   - If a slug was passed, use `~/.claude/plans/<slug>.md`
   - If no arg, list `~/.claude/plans/*.md` sorted by mtime and use the newest
   - If no plan file is found → **hard stop** with "no plan found"
2. Parse phase headings from the plan (`## Phase N:` regex). If zero phases parse → hard stop.
3. Compute SHA-256 of the plan file and store in the journal header. Re-check before each phase; if it changed → **hard stop** ("plan file mutated mid-run; resume with `/autopilot <slug>` after reviewing changes").
4. Verify `git status` is clean OR the journal exists with a recorded last commit SHA that matches `git rev-parse HEAD` (resume case).
5. Create or open the journal at `~/.claude/plans/<slug>.autopilot.md` and write the run header (see section 8). On open, hold a lockfile at `~/.claude/plans/<slug>.autopilot.lock` (mkdir-based mutex) — if the lock exists and the holder PID is alive → hard stop ("another autopilot run in progress for this plan"). Release on exit.
6. **Export `CLAUDE_AUTOPILOT=1`** for the duration of the run (`export CLAUDE_AUTOPILOT=1` as the first Bash call). `pretooluse-bash.sh` reads it and emits a `permissionDecision: "allow"` for every `git *` invocation other than `git commit`, so destructive git ops (`git push`, `git reset --hard`, `git rebase`, branch deletes, etc.) that would otherwise hit `permissions.ask` and prompt the user instead run silently. **Force-push to protected branches, `rm -rf /`, `mkfs`, and the rest of Phase A's dangerous-pattern list still block under autopilot — the bypass is for `ask` rules, not safety vetoes.** `git commit` deliberately falls through to Phase B so the 5-gate review still runs. Unset the variable on clean exit (`unset CLAUDE_AUTOPILOT`); on hard stop, the variable dies with the shell.

### 2. Per-Phase Loop

For each phase N in the plan:

1. **Execute** — invoke `/implement --phase N <slug>` so the existing implement skill writes the code, runs tests, and sets the `tests-passed` and `coverage-checked` markers. Autopilot does not duplicate this logic.
2. **Verify** — run the phase's verify clause (test command, curl, file check, etc.). On failure, dispatch `debug-specialist` (opus). Retry the verify up to 2 times total. If still failing → **hard stop**, write the journal entry, exit non-zero.
3. **Review agents** (parallel where safe):
   - `code-reviewer` (opus) — always; sets `code-reviewed`
   - `security-analyst` (opus) — if the phase touched any of: `hooks/`, `config/settings.json`, `.env*`, files matching `(auth|login|session|token|password|credential|crypto)` per the same regex `pretooluse-bash.sh` Phase B uses
   - `docs-updater` (haiku) — if the phase touched README, any `SKILL.md`, any `CLAUDE.md`, or other user-facing docs
4. **Marker check** — confirm every required marker file exists in `~/.claude/review-markers/`. If a required agent failed to set its marker, retry that agent once. If still missing → hard stop.
5. **Commit** — `git commit -m "<phase-name>: <one-line summary of changes>"`. The 5-gate hook validates markers; if it blocks, that is itself a hard stop (something genuinely failed).
6. **Journal append** — atomic write (read whole file, modify in memory, write back) with the phase entry.

### 3. Post-Phases

1. Invoke `/polish --non-interactive --journal ~/.claude/plans/<slug>.autopilot.md`. Polish auto-fixes safe items, writes ambiguous findings under a `## Needs Human Review` section in the journal, and never prompts.
2. If polish modified files, commit them as a final phase: `git commit -m "Polish: auto-fix findings"`.
3. Invoke `/learnings` so any surprises from the run land in auto-memory.

### 4. End-of-Run Summary

Print to the user and append to the journal:

```
Autopilot complete: <slug>
- Total elapsed: <m>
- Phases completed: N/M
- Commits: <list of SHAs>
- Agents invoked: <count>
- Auto-resolved decisions: <count> (see journal)
- Needs human review: <count> (see journal §Needs Human Review)
- Hard stops: <0 expected; list with reasons if any>
```

### 5. Resume After Hard Stop

If the user fixes the underlying issue and re-invokes `/autopilot <slug>`:
- Read the journal; find the last successfully committed phase
- Skip phases ≤ that index, resume from the next
- Append a `## Resume` block to the journal with timestamp and reason

### 6. Hard Stop Conditions

These are the **only** paths that pause for the user:

- Bash exit code 2 from any PreToolUse hook (Phase A dangerous-command, Phase B 5-gate, secrets blocker, sandbox network deny). **Phase B exit 2 means "your phase didn't actually pass review"** — that is the intended hard stop, not a UX gap.
- Same test/verify command fails twice consecutively after `debug-specialist`
- Plan parser yields zero phases or unresolvable file references
- Plan file SHA-256 changed mid-run (see section 1 step 3)
- Required agent fails to set its marker after one retry, or marker expired (10 min) before commit could land — re-run agent and retry once, then hard stop
- Lockfile collision: another autopilot run holds the plan's lock
- Journal write fails (filesystem issue)
- `git status` is dirty at start and there is no recoverable journal

On hard stop: write the reason to the journal, print the failing command + hook stderr, exit. Do NOT auto-`mark-reviewed.sh --all` — the marker bypass is a conscious human override, not an autopilot capability.

**Note on the `CLAUDE_AUTOPILOT=1` bypass (section 1, step 6)**: It downgrades `permissions.ask` to `allow` for safe `git *` only. It does NOT loosen Phase A's dangerous-pattern checks, does NOT loosen Phase B's 5-gate commit blocker, and does NOT silence `block-secrets-wrapper.sh`. A commit that fails the 5-gate under autopilot is still a hard stop.

### 7. Soft Ambiguity Rule

**Pick the most defensible option based on existing repo patterns. Log `DECISION: chose X over Y because Z` to the journal under the current phase. Continue. Do not ask the user mid-run.**

Examples of soft ambiguity (keep going):
- "Two valid library options" → pick the one already imported elsewhere in the repo
- "Variable name unclear" → match the closest analogous name in adjacent files
- "Test should live in `__tests__` or alongside?" → match the rest of the package

Examples that are **not** soft ambiguity (these are hard stops via section 6):
- A test fails twice — that is a real bug, not a preference
- A hook blocks the commit — that is a real safety boundary, not a UX choice

### 8. Journal Format

Atomic, append-only Markdown at `~/.claude/plans/<slug>.autopilot.md`:

```markdown
# Autopilot Run: <slug>
- Plan: ~/.claude/plans/<slug>.md
- Started: <ISO timestamp>
- Mode: autopilot (hands-off)
- Stop policy: hard failures only
- Commit cadence: per-phase

## Phase 1: <name>
- Started: <timestamp>
- Files touched: path/a.ts, path/b.ts
- Agents:
  - code-reviewer: PASS (markers: code-reviewed, tests-passed, coverage-checked@86%)
  - security-analyst: PASS — "no auth surface changes"
  - docs-updater: PASS — README updated
- Decisions:
  - DECISION: chose tsx over jsx because repo has 47 .tsx vs 0 .jsx
- Verify: `npm test -- phase1` PASS (1 attempt)
- Commit: abc1234 "Phase 1: scaffold autopilot loop"
- Elapsed: 4m12s

<details><summary>Phase 2: ...</summary>
...
</details>

## Needs Human Review
- (populated by /polish --non-interactive)
- Consider extracting helper in path/x.ts:42 — borderline DRY violation, design call

## End of Run
- Total elapsed: 38m
- Commits: abc1234, def5678, ...
- Agents invoked: 14
- Auto-resolved decisions: 6
- Hard stops: none
```

## Why This Is Safe

The interactive pause is **not** the safety boundary — these are:

- **Hooks**: `pretooluse-bash.sh` Phase A (dangerous patterns: `rm -rf /`, force push, `curl|sh`, etc.) and Phase B (the 5-gate commit blocker) still run on every Bash call. Autopilot cannot bypass them.
- **Marker expiry (10 min)**: Markers cannot be pre-stamped and reused. Each phase must actually trigger its review agents.
- **Secret blocker**: `block-secrets-wrapper.sh` blocks any Edit/Write to `.env`, `*.pem`, `*.key`, etc. regardless of caller.
- **Sandbox network deny**: Only the allowed domains (github.com, npm/PyPI/Go registries, etc.) are reachable. Out-of-scope exfiltration → hard stop.
- **Per-phase commits**: Bisectable; rollback is `git reset --hard <phase-N-sha>`.
- **Journal**: Full audit trail the user reviews after the run.

What autopilot **removes** is the per-phase pause, the soft-ambiguity prompt, and the per-`git push`/`git reset --hard`/`git rebase`/... prompt — all UX choices, not safety features. The dangerous-pattern hook, the 5-gate commit blocker, the secret blocker, and the sandbox network deny all remain active.

## Output

After the run completes (success or hard stop), print:

```
✅ Autopilot complete — <slug>
   <N> phases · <M> commits · <T> elapsed · <K> needs review
   Journal: ~/.claude/plans/<slug>.autopilot.md
   Last commit: <sha>
```

or, on hard stop:

```
🛑 Autopilot stopped — <slug>
   Phase <N> failed: <reason>
   Stderr: <hook or test output>
   Journal: ~/.claude/plans/<slug>.autopilot.md
   Resume after fixing: /autopilot <slug>
```
