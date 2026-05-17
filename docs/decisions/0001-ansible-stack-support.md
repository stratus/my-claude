---
number: 0001
title: Ansible stack support follows the python-backend + /security-audit pattern
status: accepted
date: 2026-05-16
supersedes: []
superseded-by: []
---

# ADR-0001: Ansible stack support follows the python-backend + /security-audit pattern

## Context

The repo needed first-class support for working with Ansible code — reviewing existing repos, reviewing local configs, and writing or improving playbooks/roles/collections plus their tests. The user surfaced the design question explicitly: should Ansible support be a reviewer, a builder, or both?

The repo already has a working pattern for stack support: a noun-shaped **agent** that carries continuous expertise (e.g., `python-backend`, `react-frontend`) and a verb-shaped **skill** that runs a focused audit workflow (e.g., `/security-audit`). The two compose: agents list compatible skills in their frontmatter; skills can dispatch agents for fixes.

Constraints:

- The user's three use cases ("review existing repos", "review local configs", "write/improve") map to two different verbs — review and build — which are best served by different artifact shapes.
- A single combined `/ansible` skill would either be too vague or duplicate two workflows in one document.
- An agent alone has no slash-command entry point and can't be invoked by `/polish` as a specialized review.
- The strict bar requested (ansible-lint production profile + enterprise rules: FQCN, become discipline, no-shell-when-module-exists, vault hygiene) suits opinionated specialist code more than a generic checklist.

Scope chosen: playbooks/roles + collections + molecule testing. AWX/AAP/Tower deliberately excluded as a narrower audience and significant extra surface — easy to add later as a 13th audit category.

## Decision

Build two artifacts that compose:

1. **`ansible-engineer` agent** (`sonnet`, `config/agents/ansible-engineer.md`) — stack specialist for writing, refactoring, and improving Ansible code. Lists `ansible-audit` and `security-audit` in its `skills:` frontmatter so it knows when to invoke each workflow. Activates on `*.yml` playbooks, `roles/`, `inventory*`, `ansible.cfg`, `requirements.yml`, `galaxy.yml`, `meta/runtime.yml`, and `molecule/` files.

2. **`/ansible-audit` skill** (`sonnet`, `skills/ansible-audit/SKILL.md`) — structured 12-category audit producing findings with severity, location, source (tool-backed vs. heuristic), and recommendation. Mirrors `/security-audit`'s output shape and severity matrix. Auto-detects ansible-lint / yamllint / molecule; falls back to grep heuristics when tools are missing, and surfaces tool availability in the report so users can judge signal quality.

The strict enterprise bar (FQCN, no `ignore_errors`, `loop:` not `with_items:`, `vars/main.yml` only for constants, `meta/argument_specs.yml` for non-trivial roles, `verify.yml` must use `ansible.builtin.assert`) lives inside both artifacts rather than in a separate `references/` file. If the strict rules grow past ~100 lines we revisit and split.

## Consequences

### Positive

- Mirrors an existing, proven repo pattern (`python-backend` + `/security-audit`), so the mental model already exists.
- Clean separation of verbs: review (`/ansible-audit`) vs. build (`ansible-engineer`). Each document stays focused.
- The agent gets dispatched automatically when Ansible files change, like other stack specialists. The skill is explicitly invoked when a structured audit is wanted.
- `/polish` can pick up `ansible-engineer` in its specialized-review fan-out for free.
- Auto-detect tooling makes the audit usable on any repo, including ones where the user can't install ansible-lint.
- Reusing the `/security-audit` output shape means findings flow naturally into existing review/fix workflows.

### Negative

- Two artifacts to keep in sync — if the strict rule set evolves, both files need an update. Pre-commit gate doesn't catch this drift.
- The README's agent count (11→12) and skill count (13→14) are now hand-maintained in three places (root README, `.claude/CLAUDE.md`, `config/CLAUDE.md` table) — same drift risk that already exists. Tracked in project memory under `readme_drift_hazard`.
- Heuristic fallback when ansible-lint is missing produces weaker signal; users could misread a "clean" report as confirmation when only grep ran. Mitigated by the **Tools Detected** block in the audit output.

### Neutral

- AWX / AAP / Tower not covered; users running Tower will get less value. Easy to extend later as a section 3.13 in the audit checklist.
- The strict rule set is opinionated (FQCN required, no play-level `become`); teams with looser conventions will need to override or push back. The agent is instructed to document exceptions in code comments rather than silently relax.
