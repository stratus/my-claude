---
name: ansible-audit
description: Audit Ansible playbooks, roles, collections, and inventories for production readiness. Use when reviewing an Ansible repo, before merging IaC PRs, before promoting a role to a collection, or when the user mentions ansible-lint, idempotency, vault, or molecule.
model: sonnet
argument-hint: "[path-to-repo-or-playbook]"
paths: "**/playbook*.yml,**/playbook*.yaml,**/site.yml,**/site.yaml,**/inventory/**,**/roles/**,**/collections/**,**/molecule/**,ansible.cfg,requirements.yml,galaxy.yml"
allowed-tools: Read, Grep, Glob, Bash(ansible-lint *), Bash(yamllint *), Bash(molecule *), Bash(ansible-playbook *), Bash(ansible *), Bash(command -v *), Bash(grep *), Bash(git log *), Bash(find *)
---

# Ansible Audit Skill

Perform a structured production-readiness audit on Ansible projects: playbooks, roles, collections, inventories, and molecule scenarios. Strict bar — ansible-lint production profile plus enterprise rules (FQCN, become discipline, idempotency, vault hygiene, test coverage).

**Note:** This skill pairs with the `ansible-engineer` agent for in-depth fixes and rewrites. The skill produces findings; the agent applies them.

## When to Use This Skill

- User mentions "ansible", "playbook", "role", "molecule", "ansible-lint", "vault", "idempotency"
- Reviewing an Ansible repo (your own or someone else's)
- Before merging an Ansible PR
- Before promoting a role to a collection
- Before running an unfamiliar playbook in production
- Periodic health check on existing automation

## Integration with `ansible-engineer` Agent

For end-to-end review-and-fix:
1. This skill produces structured findings with severity and locations
2. Dispatch `ansible-engineer` agent to apply the fixes
3. Re-run this skill to verify findings are resolved

## Process

### 1. Detect Ansible Target

Locate the audit scope. If `$ARGUMENTS` is provided, use it. Otherwise scan the current working directory.

```bash
# Detect what kind of Ansible project this is
find . -maxdepth 3 \( \
  -name "ansible.cfg" -o \
  -name "galaxy.yml" -o \
  -name "requirements.yml" -o \
  -name "site.yml" -o \
  -name "playbook.yml" -o \
  -path "*/roles/*/tasks/main.yml" -o \
  -path "*/molecule/*/molecule.yml" \
\) 2>/dev/null
```

Classify the project:
- **Playbook repo** — has `*.yml` playbooks at root and/or `roles/`
- **Role** — has `tasks/main.yml`, `defaults/main.yml`, `meta/main.yml` at root
- **Collection** — has `galaxy.yml` + `plugins/` and/or `roles/` underneath
- **Mixed** — multiple of the above

If no Ansible files are found, stop and tell the user. Don't fabricate findings.

### 2. Detect Available Tooling

Run once, up front, so the final report can distinguish tool-backed findings from grep heuristics:

```bash
for tool in ansible-lint yamllint molecule ansible-playbook ansible-vault; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "$tool: available ($("$tool" --version 2>/dev/null | head -1))"
  else
    echo "$tool: MISSING"
  fi
done
```

Capture this output verbatim for the report. Missing tools mean the corresponding category falls back to grep-based heuristics, which is weaker signal — say so in the output.

### 3. Run the 12-Category Audit

For each category, attempt the tool-backed check first; fall back to grep if the tool is missing. Record findings with `severity`, `location` (`file:line` where possible), `description`, `risk`, `recommendation`, and a `source` field that is either `ansible-lint`, `yamllint`, `molecule`, or `heuristic`.

#### 3.1 Project Structure

**Pass criteria:**
- Standard layout: `roles/`, `inventories/` (or top-level `inventory*`), `group_vars/`, `host_vars/`, `playbooks/` or root-level playbooks
- Collections have `galaxy.yml` + `plugins/` + `meta/runtime.yml`
- Roles have `tasks/`, `defaults/`, `meta/`, `README.md`
- No mixed playbook+collection roots without clear separation

**Detection:**
```bash
ls -la roles/ inventories/ group_vars/ host_vars/ 2>/dev/null
find . -name "galaxy.yml" -maxdepth 2
find . -path "*/roles/*/tasks/main.yml" | head -20
```

#### 3.2 Linting

**Pass criteria:**
- `ansible-lint --profile=production` exits 0
- `yamllint .` exits 0 (or only emits `warning`)
- FQCN usage >95% (count `ansible.builtin.*` / `<ns>.<col>.*` vs bare module names)

**Detection:**
```bash
ansible-lint --profile=production --format=pep8 2>&1
yamllint . 2>&1
# FQCN heuristic
grep -rE '^\s+- name:' --include='*.yml' -A1 . | grep -E '^\s+[a-z_]+:\s' | wc -l
grep -rE '^\s+(ansible\.builtin\.|community\.|ansible\.posix\.)' --include='*.yml' . | wc -l
```

**Severity:** Production-profile failures = **High**. yamllint errors = **Medium**. FQCN <95% = **Medium**.

#### 3.3 Idempotency

**Pass criteria:**
- Every `shell:` / `command:` / `raw:` task has `creates:`, `removes:`, or `changed_when:`
- `register:` tasks that participate in later `when:` have explicit `changed_when:`
- Molecule scenarios run idempotency check (second converge = zero changes)

**Detection:**
```bash
# shell/command tasks without idempotency guards
grep -rE -B2 -A5 '^\s+(ansible\.builtin\.)?(shell|command|raw):' --include='*.yml' . \
  | grep -v -E '(creates|removes|changed_when):'
```
If molecule is installed and a scenario exists:
```bash
molecule converge 2>&1 | tail -20  # then re-run; expect "changed=0"
```

**Severity:** Non-idempotent task with side effects = **High**. Missing `changed_when` on `register` chain = **Medium**.

#### 3.4 Secrets & Vault

**Pass criteria:**
- No plaintext `password`, `token`, `secret`, `api_key`, or `private_key` values in YAML outside `vault.yml` files
- `.vault_pass`, `vault_password*`, `*.vault_pass*` are in `.gitignore`
- Every task referencing `vault_*` / `*_password` / `*_token` variables has `no_log: true`
- `group_vars/<group>/vault.yml` is encrypted (starts with `$ANSIBLE_VAULT;`)

**Detection:**
```bash
# Plaintext secrets outside vault files
grep -rnE '(password|token|secret|api_key|private_key)\s*:\s*["'\'']?[^{][^"\s]{4,}' \
  --include='*.yml' . | grep -v 'vault\.yml'

# .gitignore check
grep -E 'vault.?pass' .gitignore 2>/dev/null

# Encrypted vault files
find . -name 'vault.yml' -exec head -1 {} \; -print

# no_log missing on secret consumers
grep -rE -B2 -A4 '\{\{\s*(vault_|.+_password|.+_token)' --include='*.yml' . \
  | grep -v 'no_log:'
```

**Severity:** Plaintext secret in repo = **Critical**. Missing `no_log` on secret consumer = **High**. Unencrypted `vault.yml` = **Critical**.

#### 3.5 Privilege & Become

**Pass criteria:**
- `become: true` not at play level unless every task in the play needs it (manual review)
- `become_user: root` justified per occurrence
- `ansible.cfg` does **not** set `host_key_checking = False` for production inventories
- No SSH private keys (`id_rsa`, `*.pem`, `*.key`) committed

**Detection:**
```bash
# Play-level become
grep -rE -B5 '^\s+become:\s+(true|yes)' --include='*.yml' . \
  | grep -B5 'hosts:'

# host_key_checking
grep -nE 'host_key_checking\s*=\s*(False|false|no)' ansible.cfg

# Committed keys
git ls-files | grep -E '(id_rsa|\.pem|\.key|\.p12|\.pfx)$'
```

**Severity:** Committed private key = **Critical**. `host_key_checking = False` in prod = **High**. Play-level become without justification = **Medium**.

#### 3.6 Module Hygiene

**Pass criteria:**
- `shell:` / `command:` / `raw:` usage justified per occurrence (no module exists, or shell expansion needed)
- Deprecated modules absent: `include:`, `sudo:`, `with_items:`, `local_action:`
- `ignore_errors: true` count is zero

**Detection:**
```bash
grep -rnE '^\s+(shell|command|raw):' --include='*.yml' .  # count + locations
grep -rnE '^\s+(include|sudo|local_action):' --include='*.yml' .
grep -rnE '^\s+with_items:' --include='*.yml' .
grep -rnE '^\s+ignore_errors:\s+(true|yes)' --include='*.yml' .
```

**Severity:** Each `ignore_errors: true` = **Medium**. Deprecated `include:` / `sudo:` / `with_items:` = **Medium**. Unjustified `shell:` = **Low** (note + recommend).

#### 3.7 Variable Discipline

**Pass criteria:**
- Each role has `defaults/main.yml` documenting tunables (one variable per line with a comment)
- `vars/main.yml` holds only internal constants, never user-facing tunables
- Roles with >3 variables have `meta/argument_specs.yml`

**Detection:**
```bash
# Roles without defaults/main.yml
find . -path '*/roles/*/tasks/main.yml' -print0 \
  | while IFS= read -r -d '' f; do
      role=$(dirname "$(dirname "$f")")
      [ -f "$role/defaults/main.yml" ] || echo "MISSING defaults: $role"
    done

# Roles without argument_specs
find . -path '*/roles/*/meta/main.yml' -print0 \
  | while IFS= read -r -d '' f; do
      role=$(dirname "$(dirname "$f")")
      [ -f "$role/meta/argument_specs.yml" ] || echo "MISSING argument_specs: $role"
    done
```

**Severity:** Role with no `defaults/main.yml` = **Medium**. Role with >3 vars but no `argument_specs` = **Low**.

#### 3.8 Collections Packaging (only if collection detected)

**Pass criteria:**
- `galaxy.yml` has all required keys: `namespace`, `name`, `version` (semver), `readme`, `authors`, `description`, `license`, `tags`, `repository`, `issues`
- `meta/runtime.yml` present with `requires_ansible:` set
- `changelogs/changelog.yaml` updated within last release
- No cross-collection role imports (roles inside `collections/<ns>/<col>/roles/` don't import from outside)

**Detection:**
```bash
cat galaxy.yml 2>/dev/null
cat meta/runtime.yml 2>/dev/null
ls changelogs/ 2>/dev/null
grep -rE '^\s+- (role|name): [a-z_]+\.' --include='*.yml' roles/ 2>/dev/null
```

**Severity:** Missing required `galaxy.yml` key = **High**. No `meta/runtime.yml` = **Medium**. Stale changelog = **Low**.

#### 3.9 Testing (Molecule)

**Pass criteria:**
- Every role has at least `molecule/default/molecule.yml` + `converge.yml` + `verify.yml`
- `verify.yml` uses `ansible.builtin.assert` (not just running `command:` and trusting exit codes)
- Idempotency check enabled (the default; flag if disabled)
- Lint stage runs `ansible-lint` at production profile

**Detection:**
```bash
# Roles without molecule
find . -path '*/roles/*/tasks/main.yml' -print0 \
  | while IFS= read -r -d '' f; do
      role=$(dirname "$(dirname "$f")")
      [ -d "$role/molecule" ] || echo "MISSING molecule: $role"
    done

# verify.yml without assert
grep -rL 'ansible.builtin.assert\|assert:' --include='verify.yml' molecule/ 2>/dev/null
find . -name 'verify.yml' -path '*/molecule/*' -exec grep -L 'assert' {} \;
```

**Severity:** Role with no molecule scenario = **High** (for production roles). `verify.yml` without `assert` = **High**. Idempotency check disabled = **High**.

#### 3.10 CI Integration

**Pass criteria:**
- `.github/workflows/`, `.gitlab-ci.yml`, or equivalent runs ansible-lint, yamllint, and molecule on PRs
- Matrix covers supported Ansible versions (at minimum `stable-2.16` + `devel`)

**Detection:**
```bash
ls .github/workflows/ .gitlab-ci.yml 2>/dev/null
grep -rE '(ansible-lint|molecule test|yamllint)' .github/ .gitlab-ci.yml 2>/dev/null
```

**Severity:** No CI invoking ansible-lint = **High**. No molecule in CI = **High**. No version matrix = **Medium**.

#### 3.11 Documentation

**Pass criteria:**
- Repo `README.md` explains how to run (inventory, playbook entry point, required vars)
- `requirements.yml` lists roles and collections with pinned versions
- Each role has its own `README.md` with: purpose, requirements, variables, example playbook, license
- Inventory has comments or a `README.md` explaining group structure

**Detection:**
```bash
test -f README.md && head -50 README.md
test -f requirements.yml && cat requirements.yml

find . -path '*/roles/*' -maxdepth 3 -type d -print0 \
  | while IFS= read -r -d '' d; do
      [ -f "$d/README.md" ] || echo "Role missing README: $d"
    done
```

**Severity:** Repo without README explaining run = **High**. Role without README = **Medium**. Missing `requirements.yml` when roles depend on external collections = **High**.

#### 3.12 Reliability (light pass — see `~/.claude/rules/reliability.md`)

**Pass criteria:**
- Long-running tasks (`shell` running >30s, `package` install loops, service waits) use `async:` + `poll:` or have `timeout:` set
- External-service tasks (`uri`, `get_url`, package installs from network) have `retries:`/`delay:`/`until:`
- `wait_for:` always has explicit `timeout:`
- Rolling deploys set `serial:` and `max_fail_percentage:`

**Detection:**
```bash
grep -rnE -B2 'wait_for:' --include='*.yml' . | grep -v 'timeout:'
grep -rnE '^\s+(uri|get_url|package|yum|apt|dnf):' --include='*.yml' . \
  | xargs -I{} grep -L 'retries:\|until:' {} 2>/dev/null
```

**Severity:** `wait_for` without `timeout` = **Medium**. External call without retry policy = **Medium**. Rolling deploy without `max_fail_percentage` = **Medium**.

### 4. Compose the Output

Use the format below verbatim. Always include the **Tools Detected** block so the user understands signal quality.

```markdown
## Ansible Audit Results

**Target:** [path]
**Date:** [YYYY-MM-DD]
**Classification:** [playbook repo | role | collection | mixed]
**Auditor:** Claude (automated)

### Tools Detected

| Tool | Available | Version |
|------|-----------|---------|
| ansible-lint | ✅/❌ | [version or "MISSING — heuristic only"] |
| yamllint | ✅/❌ | [...] |
| molecule | ✅/❌ | [...] |
| ansible-playbook | ✅/❌ | [...] |
| ansible-vault | ✅/❌ | [...] |

*Categories backed by missing tools fell back to grep heuristics; signal is weaker.*

### Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |

### Findings

#### 1. [Critical] Plaintext database password in group_vars/db/main.yml

- **Location:** `group_vars/db/main.yml:14`
- **Source:** heuristic (grep)
- **Description:** `db_password: "supersecret"` is committed in plaintext
- **Risk:** Credential leak — anyone with repo read access has prod DB password
- **Recommendation:** Move to `group_vars/db/vault.yml`, encrypt with `ansible-vault encrypt`, add `no_log: true` to any task that consumes it
- **Reference:** [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)

#### 2. [High] Role 'webserver' has no molecule scenario

- **Location:** `roles/webserver/`
- **Source:** heuristic
- **Description:** `roles/webserver/` has `tasks/main.yml` but no `molecule/` directory
- **Risk:** Role has no automated test; idempotency unverified; regressions undetectable
- **Recommendation:** Run `molecule init scenario -r webserver` inside the role directory; write `verify.yml` with `ansible.builtin.assert` on observable state
- **Reference:** [Molecule docs](https://ansible.readthedocs.io/projects/molecule/)

[... continue for each finding ...]

### Recommendations (prioritized)

1. [ ] Fix all Critical findings before next deploy
2. [ ] Fix High findings within the sprint
3. [ ] Schedule Medium findings for the next maintenance window
4. [ ] Address Low findings opportunistically
5. [ ] Re-run `/ansible-audit` after fixes; dispatch `ansible-engineer` agent for the rewrite work
```

### 5. Severity Matrix

| Level | Description | Examples | Action |
|-------|-------------|----------|--------|
| **Critical** | Active risk to secrets, privilege, or production stability | Plaintext secret, committed private key, unencrypted `vault.yml`, `host_key_checking=False` in prod | Block deploy |
| **High** | Production hazard or significant test gap | ansible-lint production-profile failure, missing molecule on a production role, missing `no_log` on secret consumer, no CI lint, idempotency check disabled | Fix within sprint |
| **Medium** | Quality / maintainability erosion | `ignore_errors: true`, deprecated `with_items:`, role with no `README.md`, FQCN <95%, `wait_for` without timeout | Fix within 30 days |
| **Low** | Style / hygiene | yamllint warning, unjustified `shell:` where module exists, role with >3 vars and no `argument_specs.yml` | Fix opportunistically |

### 6. Follow-up

After presenting findings:

1. Offer to dispatch the `ansible-engineer` agent to apply the recommended fixes
2. Suggest re-running `/ansible-audit` after fixes to verify clean state
3. If findings include Critical items, recommend the user halt any in-progress deploy until those are resolved
