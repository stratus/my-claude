#!/usr/bin/env bash
# =============================================================================
# PreCompact Hook: Recovery Snapshot
# =============================================================================
#
# Fires right before Claude Code compacts conversation context. Writes a
# small Markdown summary of the current session state so that, after
# compaction, the user (or a fresh session resuming via /loop or RC) can
# see what was happening immediately before the squash.
#
# What we capture (intentionally minimal — this file should be a punch list,
# not a transcript):
#   - timestamp + compaction trigger (matcher: manual|auto)
#   - current working directory
#   - git branch + HEAD SHA + dirty? (if inside a git repo)
#   - last 10 commits (oneline)
#   - staged file names (not diff content)
#   - most recent plan file under ~/.claude/plans/ (slug + mtime)
#
# Output path: ~/.claude/projects/<cwd-slug>/last-pre-compact.md
# The file is overwritten each compaction — we want "most recent state,"
# not history. (Pre-existing auto-memory at the same location is left
# untouched; we only write our specific filename.)
#
# Exit code: always 0. A recovery snapshot must never block compaction.
# =============================================================================

set -euo pipefail

INPUT=$(cat)
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // .matcher // "unknown"')

CWD="$(pwd)"
# cwd-slug: same scheme as ~/.claude/projects/ uses (slashes → dashes, leading dash kept).
SLUG="${CWD//\//-}"
SNAPSHOT_DIR="$HOME/.claude/projects/$SLUG"
mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || true

SNAP="$SNAPSHOT_DIR/last-pre-compact.md"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Collect git facts (silently no-op outside a repo).
GIT_BLOCK=""
if git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "(detached)")
    HEAD_SHA=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null || echo "")
    DIRTY=$(git -C "$CWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    RECENT=$(git -C "$CWD" log --oneline -10 2>/dev/null || echo "")
    STAGED=$(git -C "$CWD" diff --cached --name-only 2>/dev/null || echo "")
    GIT_BLOCK=$(cat <<EOF

## Git
- Branch: \`$BRANCH\`
- HEAD: \`$HEAD_SHA\`
- Dirty files: $DIRTY

### Recent commits (last 10)
\`\`\`
$RECENT
\`\`\`

### Staged files
\`\`\`
${STAGED:-(none)}
\`\`\`
EOF
)
fi

# Locate the most recently modified plan file (if any).
PLAN_BLOCK=""
PLAN_DIR="$HOME/.claude/plans"
if [[ -d "$PLAN_DIR" ]]; then
    LATEST_PLAN=$(ls -1t "$PLAN_DIR"/*.md 2>/dev/null | head -1 || true)
    if [[ -n "$LATEST_PLAN" ]]; then
        PLAN_MTIME=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ" "$LATEST_PLAN" 2>/dev/null \
                   || stat -c "%y" "$LATEST_PLAN" 2>/dev/null \
                   || echo "unknown")
        PLAN_BLOCK=$(cat <<EOF

## Most recent plan
- File: \`$LATEST_PLAN\`
- Modified: $PLAN_MTIME
EOF
)
    fi
fi

# Atomic write (temp file + rename) so a concurrent reader never sees a
# partial file.
TMP_SNAP="$SNAP.tmp.$$"
{
    cat <<EOF
# Pre-Compact Snapshot

- Timestamp: $TS
- Trigger: $TRIGGER
- Working directory: \`$CWD\`
$GIT_BLOCK
$PLAN_BLOCK

## Recovery hint
After compaction, read this file to recover the immediate prior state.
If a plan is listed above, \`/loop\` or \`/autopilot <slug>\` can resume work
from that plan without needing to re-derive the goal from the transcript.
EOF
} > "$TMP_SNAP"
mv "$TMP_SNAP" "$SNAP"

exit 0
