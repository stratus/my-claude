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
#   6. skill descriptions stay within the shared skill-listing budget
#   7. the statusline script is deployable, parses, renders exactly 2 lines,
#      and is what settings.json actually points at
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

# skillOverrides must name only skills this repo owns. The DEPLOYED settings.json
# accumulates entries for internal/employer tooling; since this repo is public,
# a "sync my settings back" would publish that list. Catch it here rather than in
# review.
if command -v python3 >/dev/null 2>&1; then
    foreign=$(python3 -c '
import json, os
try:
    ov = json.load(open("config/settings.json")).get("skillOverrides", {})
except Exception:
    raise SystemExit(0)
owned = {n for n in os.listdir("skills")
         if os.path.isfile(os.path.join("skills", n, "SKILL.md"))}
print(" ".join(sorted(k for k in ov if k not in owned)))
' 2>/dev/null || true)
    if [ -n "$foreign" ]; then
        fail "settings.json skillOverrides names non-repo skills ($foreign) — deployed settings may have been synced back into this public repo"
    else
        ok "settings.json skillOverrides names only repo-owned skills"
    fi
fi

# ---------------------------------------------------------------------------
# 2. Rules frontmatter — `paths:` or nothing; never `globs:`
# ---------------------------------------------------------------------------
RULE_FAILS=$FAILURES
for rule in config/rules/*.md; do
    if grep -q '^globs:' "$rule"; then
        fail "$rule uses 'globs:' — Claude Code ignores unknown keys and loads the rule unconditionally; use 'paths:'"
    fi
    if ! grep -q '^description:' "$rule"; then
        fail "$rule has no 'description:' frontmatter"
    fi
done
[ "$FAILURES" -eq "$RULE_FAILS" ] && ok "rules: no globs:, all have descriptions"

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
COUNT_FAILS=$FAILURES
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
[ "$FAILURES" -eq "$COUNT_FAILS" ] && ok "counts: $N_AGENTS agents, $N_SKILLS skills (documented claims checked)"

# ---------------------------------------------------------------------------
# 6. Skill-listing budget — the constraint that actually breaks skill routing.
#
# Claude Code injects a listing of skill names + descriptions each turn, capped
# at skillListingBudgetFraction (default 0.01) of the context window. On
# overflow, descriptions are SILENTLY shortened — a skill still looks installed
# but has lost the keywords Claude matches on, so it stops triggering. This
# check keeps the repo's own contribution to that listing bounded.
#
# Threshold: 2000 chars = 1% of a 200k context. We deploy with
# skillListingBudgetFraction=0.02, so this leaves ~2x headroom and keeps the
# config safe even on a 200k model. Skills marked "off" in skillOverrides or
# carrying disable-model-invocation:true cost nothing and are excluded.
# ---------------------------------------------------------------------------
BUDGET_FAILS=$FAILURES
SKILL_BUDGET_MAX=2000

if command -v python3 >/dev/null 2>&1; then
    budget_report=$(python3 - <<'PY'
import glob, json, os, re

# The threshold lives in the shell ($SKILL_BUDGET_MAX) so there is one source of
# truth; this block only measures and reports.
try:
    with open("config/settings.json") as fh:
        overrides = json.load(fh).get("skillOverrides", {})
except Exception:
    overrides = {}

total, counted, skipped = 0, [], []
for path in sorted(glob.glob("skills/*/SKILL.md")):
    slug = os.path.basename(os.path.dirname(path))
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    block = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not block:
        continue
    fm = block.group(1)

    if overrides.get(slug) == "off":
        skipped.append(f"{slug} (off)")
        continue
    if re.search(r"^disable-model-invocation:\s*(true|yes|on|1)\s*$", fm, re.M | re.I):
        skipped.append(f"{slug} (manual-only)")
        continue

    name = re.search(r"^name:\s*(.*)$", fm, re.M)
    desc = re.search(r"^description:\s*(.*)$", fm, re.M)
    name = name.group(1).strip() if name else slug
    desc = desc.group(1).strip().strip("\"'") if desc else ""
    total += len(name) + len(desc)
    counted.append((slug, len(desc)))

worst = ", ".join(
    "%s (%d)" % (slug, n) for slug, n in sorted(counted, key=lambda x: -x[1])[:3]
)
# Single pipe-delimited line; the caller treats any other shape as "unverified".
print("%d|%d|%d|%s" % (total, len(counted), len(skipped), worst))
PY
    )
    # Fail CLOSED. The python block emits a single "total|counted|skipped|worst"
    # line; anything else (crash, unreadable skill, malformed frontmatter) means
    # the budget is UNKNOWN, not zero. Falling back to 0 here would print a green
    # check while descriptions were silently over budget — the exact
    # looks-fine-but-does-nothing failure this check exists to catch.
    if [ -z "$budget_report" ]; then
        fail "skill-listing budget check did not run (python3 error) — budget unverified"
    else
        b_total="${budget_report%%|*}"
        b_rest="${budget_report#*|}"
        b_count="${b_rest%%|*}"
        b_rest="${b_rest#*|}"
        b_skip="${b_rest%%|*}"
        b_worst="${b_rest#*|}"
        if ! [ "$b_total" -eq "$b_total" ] 2>/dev/null; then
            fail "skill-listing budget check returned garbage ('$budget_report') — budget unverified"
        elif [ "$b_count" -eq 0 ]; then
            # Zero measured skills is never a legitimate pass — it means the glob
            # matched nothing (wrong cwd, moved skills/ dir), so the budget went
            # unmeasured rather than measured-as-fine.
            fail "skill-listing budget check found no skills under skills/*/SKILL.md — run from the repo root"
        elif [ "$b_total" -gt "$SKILL_BUDGET_MAX" ]; then
            fail "skill listing is $b_total chars, over the $SKILL_BUDGET_MAX budget — longest: $b_worst"
        fi
    fi
    [ "$FAILURES" -eq "$BUDGET_FAILS" ] && \
        ok "skill listing: $b_total/$SKILL_BUDGET_MAX chars ($b_count listed, $b_skip excluded)"
else
    ok "skill listing: skipped (python3 not found)"
fi

# ---------------------------------------------------------------------------
# 7. statusline — deployable, syntactically valid, and wired in settings.json.
# Nothing else validates this: a broken statusline fails silently (Claude Code
# just renders nothing), and a settings.json pointing at a path we no longer
# ship would leave every new install with no bar at all.
# ---------------------------------------------------------------------------
SL="config/statusline/statusline.sh"
if [ ! -f "$SL" ]; then
    fail "$SL is missing — settings.json statusLine points at a file this repo does not ship"
else
    if [ -x "$SL" ]; then
        ok "statusline script is executable"
    else
        fail "$SL is not executable (chmod +x)"
    fi

    if bash -n "$SL" 2>/dev/null; then
        ok "statusline script parses"
    else
        fail "$SL has a syntax error"
    fi

    # The bar must be exactly two lines for ANY payload, including the degenerate
    # ones (`{}` early in a session, null context_window right after /compact).
    # Height regression is the specific failure that motivated this script.
    if command -v jq >/dev/null 2>&1; then
        sl_bad=""
        for probe in '{}' '{"context_window":null,"rate_limits":null}' 'not json'; do
            n=$(printf '%s' "$probe" | bash "$SL" 2>/dev/null | wc -l | tr -d ' ')
            [ "$n" = "2" ] || sl_bad="$sl_bad '$probe'->${n}L"
        done
        if [ -n "$sl_bad" ]; then
            fail "statusline must emit exactly 2 lines for every payload; got:$sl_bad"
        else
            ok "statusline emits exactly 2 lines (including empty/null/malformed payloads)"
        fi
    else
        ok "statusline line-count check: skipped (jq not found)"
    fi
fi

if command -v python3 >/dev/null 2>&1; then
    sl_cmd=$(python3 -c "
import json
print(json.load(open('config/settings.json')).get('statusLine', {}).get('command', ''))
" 2>/dev/null)
    case "$sl_cmd" in
        *statusline/statusline.sh) ok "settings.json statusLine points at the shipped script" ;;
        "") fail "settings.json has no statusLine.command (or python3 could not read it)" ;;
        *)  fail "settings.json statusLine.command ('$sl_cmd') does not point at statusline/statusline.sh" ;;
    esac
else
    ok "settings.json statusLine wiring: skipped (python3 not found)"
fi

# ---------------------------------------------------------------------------
echo ""
if [ "$FAILURES" -gt 0 ]; then
    echo "❌ $FAILURES check(s) failed" >&2
    exit 1
fi
echo "✅ All config checks passed"
