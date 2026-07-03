#!/usr/bin/env bash
# =============================================================================
# check-config.sh — repo consistency checks, run locally or in CI
# =============================================================================
#
# Validates the parts of this repo that fail silently at runtime:
#   1. settings.json is valid JSON and still ships identity placeholders
#   2. rules use `paths:` (not `globs:`, which Claude Code silently ignores)
#      and every rule has a description
#   3. every skill has name/description/model frontmatter
#   4. every agent has model/tools/maxTurns frontmatter
#   5. documented agent/skill counts match reality (READMEs drift otherwise)
#
# Exit 0 = all checks pass; exit 1 = at least one failure (all are reported).
# =============================================================================

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

FAILURES=0
fail() {
    echo "❌ $1" >&2
    FAILURES=$((FAILURES + 1))
}
ok() {
    echo "✅ $1"
}

# ---------------------------------------------------------------------------
# 1. settings.json — valid JSON, identity placeholders intact (repo is public)
# ---------------------------------------------------------------------------
if python3 -c "import json; json.load(open('config/settings.json'))" 2>/dev/null; then
    ok "settings.json is valid JSON"
else
    fail "settings.json is not valid JSON"
fi

if grep -q -- "--- identity block start" config/settings.json; then
    ok "settings.json ships identity placeholders (identity block markers present)"
else
    fail "settings.json is missing the identity block markers — real identity may have been committed"
fi

# ---------------------------------------------------------------------------
# 2. Rules frontmatter — `paths:` or nothing; never `globs:`
# ---------------------------------------------------------------------------
for rule in config/rules/*.md; do
    if grep -q '^globs:' "$rule"; then
        fail "$rule uses 'globs:' — Claude Code ignores unknown keys and loads the rule unconditionally; use 'paths:'"
    fi
    if ! grep -q '^description:' "$rule"; then
        fail "$rule has no 'description:' frontmatter"
    fi
done
[ "$FAILURES" -eq 0 ] && ok "rules: no globs:, all have descriptions"

# ---------------------------------------------------------------------------
# 3. Skills frontmatter
# ---------------------------------------------------------------------------
SKILL_FAILS=$FAILURES
for skill in skills/*/SKILL.md; do
    for key in name description model; do
        if ! grep -q "^${key}:" "$skill"; then
            fail "$skill missing '${key}:' frontmatter"
        fi
    done
done
[ "$FAILURES" -eq "$SKILL_FAILS" ] && ok "skills: all have name/description/model"

# ---------------------------------------------------------------------------
# 4. Agents frontmatter
# ---------------------------------------------------------------------------
AGENT_FAILS=$FAILURES
for agent in config/agents/*.md; do
    for key in model tools maxTurns; do
        if ! grep -q "^${key}:" "$agent"; then
            fail "$agent missing '${key}:' frontmatter"
        fi
    done
done
[ "$FAILURES" -eq "$AGENT_FAILS" ] && ok "agents: all have model/tools/maxTurns"

# ---------------------------------------------------------------------------
# 5. Count drift — documented counts must match the filesystem
# ---------------------------------------------------------------------------
N_AGENTS=$(find config/agents -name '*.md' | wc -l | tr -d ' ')
N_SKILLS=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

while IFS=: read -r file claim; do
    n=$(echo "$claim" | grep -oE '[0-9]+')
    if [ "$n" != "$N_AGENTS" ]; then
        fail "$file claims '$claim' but there are $N_AGENTS agent files"
    fi
done < <(grep -oHE '[0-9]+ (specialized )?sub-agents' README.md config/README.md 2>/dev/null)

for pattern_file in .claude/CLAUDE.md; do
    [ -f "$pattern_file" ] || continue
    claim=$(grep -oE 'Agents \([0-9]+ total\)' "$pattern_file" | grep -oE '[0-9]+' || true)
    if [ -n "$claim" ] && [ "$claim" != "$N_AGENTS" ]; then
        fail "$pattern_file claims $claim agents but there are $N_AGENTS"
    fi
    claim=$(grep -oE 'Skills \([0-9]+ total\)' "$pattern_file" | grep -oE '[0-9]+' || true)
    if [ -n "$claim" ] && [ "$claim" != "$N_SKILLS" ]; then
        fail "$pattern_file claims $claim skills but there are $N_SKILLS"
    fi
done
ok "counts: $N_AGENTS agents, $N_SKILLS skills (documented claims checked)"

# ---------------------------------------------------------------------------
echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "❌ $FAILURES check(s) failed" >&2
    exit 1
fi
echo "✅ All config checks passed"
