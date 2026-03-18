# Claude Code Permissions Guide

## Safe Auto-Approvals Explained

This document explains the carefully designed permission system that auto-approves **safe operations** while requiring explicit approval for **potentially dangerous operations**.

---

## How Auto-Approval Works

> **Primary mechanism**: `autoAllowBashIfSandboxed: true` in settings.json auto-approves **all** sandboxed Bash commands. The explicit `permissions.allow` list is only needed for non-Bash tools (Edit, Write, MCP) and edge cases that run outside the sandbox (like hook scripts). If you see a Bash command listed in `permissions.allow`, it's redundant — sandbox already covers it.
>
> **Sandbox expansion**: The sandbox is configured with extended filesystem write paths (`~/.cache/uv`, `~/go`, `~/.npm`, etc.) and allowed network domains (`pypi.org`, `proxy.golang.org`, `registry.npmjs.org`, etc.) so that common dev tools (uv, go, npm, git) run *inside* the sandbox without prompts. `allowUnsandboxedCommands: false` prevents the autonomous sandbox escape hatch — if a command needs a path or domain not listed, it fails rather than silently retrying unsandboxed.

---

## Design Philosophy

### Goal
Enable smooth workflow where Claude Code can:
1. ✅ Read, analyze, and modify code freely
2. ✅ Run tests, linters, and build processes automatically
3. ✅ Stage changes with git add (fully reversible)
4. ⚠️  Require approval before making changes permanent (git commit)
5. ⚠️  Require approval before sharing changes (git push)
6. ❌ Block reading secrets and destructive operations

### Key Principle
> **"Changes are safe until committed"**
>
> You can review all modifications with `git diff` before they become permanent with `git commit`.
> The checkpoint is at commit/push, not at file modification.

---

## Permission Categories

### 1. AUTO-APPROVED ✅ (No Permission Prompt)

These operations are safe because they are:
- Read-only (can't corrupt anything)
- Fully reviewable (via git diff)
- Fully reversible (via git checkout/reset)
- Verification-only (tests, linters)
- Local-only (dev servers)

#### Read Operations (100% Safe)
```
Read(*)         - Read any file (except secrets)
Glob(*)         - Find files by pattern
Grep(*)         - Search file contents
```

#### Core Editing (Safe - Reviewable & Reversible)
```
Edit(*)         - Modify existing files
Write(*)        - Create new files
```
**Why auto-approve?**
- This is Claude Code's core functionality
- Changes are reviewable with `git diff`
- Changes are reversible with `git checkout <file>`
- Real checkpoint is at `git commit`

#### Git Read-Only (100% Safe)
```
git status      - Show working tree status
git diff        - Show changes
git log         - Show commit history
git show        - Show commit details
git branch      - List branches
git remote      - Show remotes
```

#### Git Staging (Safe - Fully Reversible)
```
git add         - Stage changes (undo: git reset)
git reset       - Unstage changes
git restore     - Discard changes
git checkout    - Switch branches or restore files
```
**Why auto-approve?**
- Staging is 100% reversible with `git reset`
- No changes become permanent until `git commit`

#### Testing (Safe - Verification Only)
```
# Go
go test
go vet

# Python
pytest
python -m unittest
coverage

# JavaScript/TypeScript
npm test
jest
vitest

# Rust
cargo test
```
**Why auto-approve?**
- Tests verify code but don't modify source files
- Essential for development workflow

#### Linting & Formatting (Safe - Auto-fixers are Reviewable)
```
# Go
gofmt, go fmt
golangci-lint

# Python
black, ruff, isort
mypy, pylint, flake8

# JavaScript/TypeScript
eslint, prettier
tsc

# Rust
cargo fmt, cargo clippy
rustfmt
```
**Why auto-approve even with --fix?**
- Auto-fixes follow established standards
- Changes are reviewable with `git diff`
- Can be reverted with `git checkout`

#### Build Commands (Safe - Creates Artifacts)
```
# General
make build
make compile

# Language-specific
go build
npm run build
cargo build
hugo build
python -m build
```
**Why auto-approve?**
- Creates artifacts in dist/build/public directories
- Doesn't modify source code
- Essential for development workflow

#### Local Dev Servers (Safe - Local Only)
```
hugo server
npm run dev
python -m http.server
cargo run
go run main.go
```
**Why auto-approve?**
- Runs locally only
- No persistent changes
- Essential for development

#### GitHub CLI Read-Only (Safe)
```
gh repo view
gh pr list
gh pr view
gh issue list
gh run list
```

### 2. BLOCKED ❌ (Always Denied)

These operations are **never allowed** for security:

#### Reading Secrets
```
.env, .env.local, .env.production, .env.staging, .env.*.local
secrets/, credentials/ (directory-level match)
*.key, *.pem, *.p12, *.pfx, *.jks, *.keystore
SSH keys (id_rsa, id_ed25519)
AWS credentials
Service account keys

NOT blocked (safe reference files):
.env.example, .env.template, .env.sample, .env.schema
```
**Why blocked?**
- Prevents accidental secret exposure
- Security best practice

#### Destructive Operations
```
rm -rf
sudo
git reset --hard
git push --force
git push -f
```
**Why blocked?**
- Can cause irreversible data loss
- Can affect team members (force push)
- Requires explicit user action

### 3. REQUIRES APPROVAL ⚠️ (Permission Prompt Each Time)

Operations NOT in allow/deny lists will prompt for approval.

#### Git Operations That Make Changes Permanent
```
git commit      - Makes changes permanent in history
git push        - Shares changes with team
git pull        - Pulls remote changes
git rebase      - Rewrites history
git merge       - Merges branches
```
**Why require approval?**
- Makes changes permanent or affects others
- User should explicitly approve each commit
- Checkpoint for reviewing changes

#### Package Installation (Changes Project State)
```
npm install
pip install
go get
cargo add
composer install
```
**Why require approval?**
- Modifies dependencies
- Changes project state
- Can introduce security risks
- User should review what's being installed

#### GitHub CLI Write Operations
```
gh pr create
gh pr merge
gh issue create
gh workflow run
```
**Why require approval?**
- Affects remote repository
- Visible to team

---

## How the Workflow Works

### Typical Development Flow

```
1. User: "Add user authentication feature"

2. Claude Code (AUTO-APPROVED):
   - Reads existing files
   - Writes/Edits auth files
   - Runs tests
   - Runs linters
   - Builds project
   - Runs git diff

3. User reviews changes with git diff

4. User: "Use code-reviewer agent to review"
   - Agent reviews (AUTO-APPROVED reads)
   - Agent provides feedback

5. Claude Code (AUTO-APPROVED):
   - Fixes critical issues
   - Runs tests again
   - Updates documentation

6. User: "Commit the changes"

7. Claude Code (REQUIRES APPROVAL):
   - Prompts: "Approve git commit?"
   - Shows checklist

8. User approves commit

9. User: "Push to remote"

10. Claude Code (REQUIRES APPROVAL):
    - Prompts: "Approve git push?"
    - Shows checklist

11. User approves push
```

**Checkpoints:**
- Before commit: Review with `git diff`
- At commit: Explicit approval required
- At push: Explicit approval required

---

## Security Boundaries

### What CAN'T Claude Code Do (Blocked)?
1. ❌ Read .env files or secrets
2. ❌ Read SSH keys or credentials
3. ❌ Run sudo or system-level commands
4. ❌ Force push to remote
5. ❌ Hard reset (destructive)
6. ❌ WebFetch arbitrary URLs

### What CAN Claude Code Do (Auto-Approved)?
1. ✅ Read all source code (except secrets)
2. ✅ Edit/Write source files (reviewable)
3. ✅ Run tests, linters, formatters
4. ✅ Build project
5. ✅ Stage changes (git add)
6. ✅ Start local dev servers

### What Requires Your Approval?
1. ⚠️  git commit (checkpoint)
2. ⚠️  git push (affects team)
3. ⚠️  Package installation (changes dependencies)
4. ⚠️  Creating PRs/issues (affects remote)

---

## Examples by Language

### Go Project
```
AUTO-APPROVED:
- Read .go files
- Edit .go files
- go test ./...
- go build
- go fmt
- golangci-lint
- git add

REQUIRES APPROVAL:
- git commit
- git push
- go get (installs dependencies)
```

### Python Project
```
AUTO-APPROVED:
- Read .py files
- Edit .py files
- pytest
- black
- ruff
- git add

REQUIRES APPROVAL:
- git commit
- git push
- pip install (installs dependencies)
```

### JavaScript/TypeScript Project
```
AUTO-APPROVED:
- Read .js/.ts files
- Edit .js/.ts files
- npm test
- eslint
- prettier
- git add

REQUIRES APPROVAL:
- git commit
- git push
- npm install (installs dependencies)
```

### HTML/CSS Project
```
AUTO-APPROVED:
- Read .html/.css files
- Edit .html/.css files
- hugo build
- hugo server
- git add

REQUIRES APPROVAL:
- git commit
- git push
```

---

## Customizing Permissions Per Project

### For This Project
Copy the template to your project:
```bash
cp ~/.claude/settings.json.template /path/to/project/.claude/settings.json
```

### Add Project-Specific Auto-Approvals
Edit `.claude/settings.json`:
```json
{
  "permissions": {
    "allow": [
      "comment": "Project-specific safe commands",
      "Bash(docker-compose up:*)",
      "Bash(kubectl get:*)",
      "Bash(terraform plan:*)"
    ]
  }
}
```

### Add Project-Specific Blocks
```json
{
  "permissions": {
    "deny": [
      "comment": "Block production operations in this project",
      "Bash(kubectl delete:*)",
      "Bash(terraform apply:*)"
    ]
  }
}
```

---

## FAQs

### Q: Why auto-approve Edit and Write?
**A:** Because:
1. This is Claude Code's core functionality
2. Changes are fully reviewable with `git diff`
3. Changes are fully reversible with `git checkout`
4. The real checkpoint is at `git commit`, not at file modification
5. Requiring approval for every file edit would make Claude Code unusable

### Q: What if Claude Code makes a mistake?
**A:** Before committing:
```bash
# Review changes
git diff

# Revert specific file
git checkout path/to/file

# Revert all changes
git checkout .
```

### Q: Can I make git commit auto-approve too?
**A:** You can, but it's NOT recommended because:
1. Commits are permanent in git history
2. You lose the checkpoint to review changes
3. It's harder to undo committed changes

If you really want to:
```json
{
  "permissions": {
    "allow": [
      "Bash(git commit:*)"
    ]
  }
}
```

### Q: Why is package installation not auto-approved?
**A:** Because:
1. It modifies project dependencies
2. Can introduce security vulnerabilities
3. Can break builds
4. User should explicitly approve what's being installed

### Q: Can I auto-approve package installation?
**A:** Not recommended, but if needed:
```json
{
  "permissions": {
    "allow": [
      "Bash(npm install:*)",
      "Bash(pip install:*)",
      "Bash(go get:*)"
    ]
  }
}
```

---

## Summary

### Safe Auto-Approvals Work Because:
1. ✅ **Read operations**: Can't corrupt anything
2. ✅ **Edit/Write**: Reviewable (git diff), reversible (git checkout)
3. ✅ **Tests/Linters**: Verification only, don't modify source permanently
4. ✅ **Builds**: Create artifacts, don't modify source
5. ✅ **git add**: Fully reversible with git reset

### Explicit Approval Required For:
1. ⚠️  **git commit**: Makes changes permanent
2. ⚠️  **git push**: Shares with team
3. ⚠️  **Package installation**: Changes dependencies

### Always Blocked:
1. ❌ **Secrets**: Security risk
2. ❌ **Destructive operations**: Data loss risk

---

## The Checkpoint Philosophy

```
[Claude Code makes changes]
        ↓
    git diff     ← You review here
        ↓
   git commit    ← Explicit approval required (Checkpoint 1)
        ↓
    git push     ← Explicit approval required (Checkpoint 2)
```

This design:
- ✅ Enables smooth development workflow
- ✅ Prevents data corruption outside projects
- ✅ Prevents accidental commits without review
- ✅ Blocks security risks (secrets, sudo)
- ✅ Balances safety with productivity

---

**For more details, see:**
- Global standards: `~/.claude/CLAUDE.md`
- Project template: `~/.claude/settings.json.template`
- Usage guide: `~/.claude/README.md`
