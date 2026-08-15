#!/usr/bin/env bash
#
# Install my-claude configuration to ~/.claude/
#
# Usage: ./install.sh
#        CLAUDE_DIR=~/.claude-corp ./install.sh   (install to alternate dir)
#        FORCE_UPDATE=1 ./install.sh               (skip prompts, overwrite all)
#
# This script deploys Claude Code configuration files to the user's
# home directory. New files are copied in; existing files are compared
# by SHA-256 checksum. On mismatch, the user is shown a diff and
# prompted to overwrite or keep the local version.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CONFIG_SOURCE="$SCRIPT_DIR/config"

# Tildified form of $CLAUDE_DIR used by the settings.json sed rewrite and the
# statusLine Python splicer. Computed once here so both code paths share
# the value and the path-rewrite logic stays consistent.
if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
    CLAUDE_DIR_TILDE="~/.claude"
else
    CLAUDE_DIR_TILDE="${CLAUDE_DIR/#$HOME/\~}"
fi

echo "🤖 Installing my-claude configuration..."
echo ""

# Create .claude directory structure
mkdir -p "$CLAUDE_DIR"/{agents,config,plans,hooks,commands,rules}

# Copy if missing or diverged — prompts user on content mismatch
copy_if_missing() {
    local src="$1"
    local dest="$2"
    local name="$(basename "$src")"

    if [ ! -f "$dest" ]; then
        echo "  📄 Copying $name"
        cp "$src" "$dest"
        return
    fi

    # File exists — compare checksums
    local src_hash dest_hash
    src_hash="$(shasum -a 256 "$src" | cut -d' ' -f1)"
    dest_hash="$(shasum -a 256 "$dest" | cut -d' ' -f1)"

    if [ "$src_hash" = "$dest_hash" ]; then
        echo "  ✅ $name up to date"
        return
    fi

    # Content diverged — show diff and ask
    echo ""
    echo "  ⚠️  $name differs from repo version:"
    echo "  ────────────────────────────────────"
    diff --color=auto -u "$dest" "$src" | head -40 || true
    echo "  ────────────────────────────────────"
    echo ""

    if [ "${FORCE_UPDATE:-}" = "1" ]; then
        echo "  🔄 Overwriting $name (FORCE_UPDATE=1)"
        cp "$src" "$dest"
        return
    fi

    read -rp "  Overwrite local $name with repo version? [y/N/d(iff)] " choice
    case "$choice" in
        y|Y)
            echo "  🔄 Overwriting $name"
            cp "$src" "$dest"
            ;;
        d|D)
            diff --color=auto -u "$dest" "$src" || true
            read -rp "  Overwrite? [y/N] " confirm
            case "$confirm" in
                y|Y) echo "  🔄 Overwriting $name"; cp "$src" "$dest" ;;
                *)   echo "  ⏭️  Keeping local $name" ;;
            esac
            ;;
        *)
            echo "  ⏭️  Keeping local $name"
            ;;
    esac
}

# Deploy configuration files (before statusline — its installer verifies settings.json)
copy_if_missing "$CONFIG_SOURCE/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
copy_if_missing "$CONFIG_SOURCE/PERMISSIONS-GUIDE.md" "$CLAUDE_DIR/PERMISSIONS-GUIDE.md"
copy_if_missing "$CONFIG_SOURCE/README.md" "$CLAUDE_DIR/README.md"

# Snapshot live skillOverrides BEFORE the copy — copy_if_missing is a whole-file
# `cp`, not a merge, so FORCE_UPDATE=1 would otherwise discard visibility settings
# for skills this repo does not own (externally provisioned skills under
# $CLAUDE_DIR/skills/, synced claude.ai skills, anything toggled via /skills).
# Losing those silently re-enables every one of them, which blows the skill-listing
# budget and degrades routing for the skills that should trigger.
LIVE_SKILL_OVERRIDES=""
if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 >/dev/null 2>&1; then
    LIVE_SKILL_OVERRIDES="$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as fh:
        print(json.dumps(json.load(fh).get("skillOverrides", {})))
except Exception:
    print("{}")
' "$CLAUDE_DIR/settings.json" 2>/dev/null || echo '{}')"
fi

copy_if_missing "$CONFIG_SOURCE/settings.json" "$CLAUDE_DIR/settings.json"

# Re-merge the live skillOverrides captured above. Repo-owned entries win (so the
# repo stays the source of truth for its own skills); every other key is carried
# forward from the deployed file. Runs unconditionally, like the path-rewrite and
# identity overlay below, so it repairs the file whether or not the copy fired.
if [ -n "$LIVE_SKILL_OVERRIDES" ] && [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 >/dev/null 2>&1; then
    # Kept inside $CLAUDE_DIR (not $TMPDIR) so the mv below is a same-filesystem
    # rename, i.e. atomic — settings.json is never observed half-written. The
    # trap covers the gap the if/else can't: a Ctrl-C mid-merge would otherwise
    # strand the temp file in the live config dir.
    tmp_merged="$CLAUDE_DIR/settings.json.merge.$$"
    trap 'rm -f "$tmp_merged"' EXIT
    if python3 -c '
import json, sys
settings_path, live_json, repo_skills_dir = sys.argv[1], sys.argv[2], sys.argv[3]
import os

with open(settings_path) as fh:
    settings = json.load(fh)

live = json.loads(live_json)
repo_owned = {
    name for name in os.listdir(repo_skills_dir)
    if os.path.isfile(os.path.join(repo_skills_dir, name, "SKILL.md"))
} if os.path.isdir(repo_skills_dir) else set()

repo_declared = settings.get("skillOverrides", {})
merged = {k: v for k, v in live.items() if k not in repo_owned}
merged.update(repo_declared)
if merged:
    settings["skillOverrides"] = dict(sorted(merged.items()))
    kept = sorted(k for k in merged if k not in repo_owned)
    if kept:
        print("  🧩 Preserved skillOverrides for %d non-repo skill(s)" % len(kept),
              file=sys.stderr)

# The repo is the source of truth for its own skills, so a local toggle of a
# repo-owned skill is intentionally reverted here. Say so out loud rather than
# dropping it silently — an unexplained setting reversal is indistinguishable
# from a bug.
reverted = sorted(
    k for k, v in live.items()
    if k in repo_owned and repo_declared.get(k, "on") != v
)
if reverted:
    print("  ↩️  Reset %s to the repo value (the repo owns its own skills; "
          "edit config/settings.json to change)" % ", ".join(reverted),
          file=sys.stderr)

# ensure_ascii=False is load-bearing: settings.json is full of em-dashes in the
# Auto Mode prose, and the default escapes each one to a — sequence. Since
# copy_if_missing compares by SHA-256, that reserialization would leave the
# deployed file permanently divergent from the repo copy, prompting
# "settings.json differs" on every install until the user stops reading them.
with open(sys.argv[4], "w", encoding="utf-8") as fh:
    json.dump(settings, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
' "$CLAUDE_DIR/settings.json" "$LIVE_SKILL_OVERRIDES" "$SCRIPT_DIR/skills" "$tmp_merged"; then
        mv "$tmp_merged" "$CLAUDE_DIR/settings.json"
    else
        echo "  ❌ skillOverrides merge failed — keeping settings.json as copied" >&2
        rm -f "$tmp_merged"
    fi
    # Release the trap so it doesn't collide with the identity-overlay trap set
    # further down; the temp file is already gone down both branches above.
    trap - EXIT
fi

# Rewrite ~/.claude/ paths in settings.json for non-default targets
if [ "$CLAUDE_DIR" != "$HOME/.claude" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    claude_dir_tilde="${CLAUDE_DIR/#$HOME/\~}"
    echo "  🔄 Rewriting paths in settings.json → $claude_dir_tilde/"
    sed -i '' "s|~/.claude/|${claude_dir_tilde}/|g" "$CLAUDE_DIR/settings.json"
fi

# Apply per-target identity overlay (if present) — runs unconditionally so the
# placeholder block in settings.json is always replaced when an overlay exists,
# regardless of whether copy_if_missing overwrote the file. Must run AFTER the
# path-rewrite above so user-typed `~/.claude/` references in overlay prose
# aren't mangled.
if [ -f "$CLAUDE_DIR/identity.json" ] && [ -f "$CLAUDE_DIR/settings.json" ]; then
    if ! command -v python3 >/dev/null 2>&1; then
        echo "  ⚠️  python3 not found — skipping identity overlay (install Xcode CLT then re-run)"
    else
        echo "  🪪 Applying identity overlay from identity.json"
        # Build the replacement block on stdout, one JSON array string per line,
        # using the same 6-space indent as the surrounding "environment" array.
        overlay_block="$(python3 - "$CLAUDE_DIR/identity.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    ident = json.load(f)
lines = ident.get("environment_extras", [])
if not lines:
    name = ident.get("name", "")
    email = ident.get("email", "")
    lines = [f"Developer: {name} ({email}), individual developer."]
indent = "      "
print("\n".join(f'{indent}{json.dumps(line)},' for line in lines))
PYEOF
)"
        # Write block to temp file, then use awk to splice it between markers.
        tmp_dir="${TMPDIR:-/tmp}"
        tmp_block="$tmp_dir/my-claude-identity-block.$$"
        tmp_out="$tmp_dir/my-claude-settings.$$"
        trap 'rm -f "$tmp_block" "$tmp_out"' EXIT
        printf '%s\n' "$overlay_block" > "$tmp_block"
        awk -v blockfile="$tmp_block" '
            /--- identity block start \(managed by make set-identity\) ---/ {
                print
                while ((getline line < blockfile) > 0) print line
                close(blockfile)
                in_block = 1
                next
            }
            /--- identity block end ---/ {
                in_block = 0
                print
                next
            }
            !in_block { print }
        ' "$CLAUDE_DIR/settings.json" > "$tmp_out"
        if python3 -c "import json; json.load(open('$tmp_out'))" 2>/dev/null; then
            mv "$tmp_out" "$CLAUDE_DIR/settings.json"
        else
            echo "  ❌ Overlay produced invalid JSON — keeping original settings.json" >&2
            rm -f "$tmp_out"
        fi
        rm -f "$tmp_block"
        trap - EXIT
    fi
fi

# Deploy the statusline.
#
# This repo owns its statusline outright: a small bash+jq script with no
# upstream pin, no checksum verification, and no network fetch. It replaces the
# former rz1989s/tmck/none backend switcher, which shipped ~2800 lines of
# vendored code to render a bar that grew to 15 terminal rows.
#
# The script reads the native context_window / rate_limits payload fields, so
# there is nothing to keep in sync with an upstream project.

STATUSLINE_DIR="$CLAUDE_DIR/statusline"

if [ -f "$CONFIG_SOURCE/statusline/statusline.sh" ]; then
    mkdir -p "$STATUSLINE_DIR"
    # Always overwritten: this is routing logic, not user-tunable config.
    echo "  📊 Deploying statusline.sh"
    cp "$CONFIG_SOURCE/statusline/statusline.sh" "$STATUSLINE_DIR/statusline.sh"
    chmod +x "$STATUSLINE_DIR/statusline.sh"
fi

# ---------------------------------------------------------------------------
# Report leftovers from the removed backends. These live in the deploy target,
# not the repo, and deleting a user's files without asking is not this
# script's job — so print the exact commands and let the user run them.
# ---------------------------------------------------------------------------
stale_found=0
stale_report() {
    if [ "$stale_found" -eq 0 ]; then
        echo ""
        echo "  🧹 Leftovers from the previous statusline backends were found."
        echo "     They are inert (nothing references them). To reclaim the space:"
        echo ""
        stale_found=1
    fi
    echo "       rm -rf $1"
}
for stale in \
    "$STATUSLINE_DIR/statusline.sh.bak" \
    "$STATUSLINE_DIR/lib" \
    "$STATUSLINE_DIR/examples" \
    "$STATUSLINE_DIR/Config.toml" \
    "$STATUSLINE_DIR/statusline-wrapper.sh" \
    "$STATUSLINE_DIR/version.txt" \
    "$STATUSLINE_DIR/themes.py" \
    "$STATUSLINE_DIR/.Config.cache.sh" \
    "$STATUSLINE_DIR/.Config.checksum" \
    "$CLAUDE_DIR/statusline_command.py" \
    "$CLAUDE_DIR/statusline-choice"
do
    # -L as well as -e: the tmck deploy left dangling symlinks, which -e misses.
    if [ -e "$stale" ] || [ -L "$stale" ]; then
        stale_report "$stale"
    fi
done
for ext in "$CLAUDE_DIR"/external/yet-another-statusline-*; do
    if [ -e "$ext" ]; then
        stale_report "$ext"
    fi
done
if [ "$stale_found" -eq 1 ]; then
    echo ""
fi

# ---------------------------------------------------------------------------
# Point settings.json.statusLine at the deployed script. JSON
# load/mutate/dump (mirroring the identity-overlay Python block above) — not
# AWK-marker splicing, because the statusLine object spans multiple lines and
# would be vulnerable to any formatter that reorders keys.
# ---------------------------------------------------------------------------
if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR_TILDE" <<'PYEOF'
import json, os, sys
path, tilde = sys.argv[1], sys.argv[2]
with open(path) as f:
    s = json.load(f)
s["statusLine"] = {
    "type": "command",
    "command": f"bash {tilde}/statusline/statusline.sh",
    # Event-driven updates go quiet while background subagents run, so keep a
    # timer to refresh git state and quota during idle stretches.
    "refreshInterval": 5,
}
# Write atomically to avoid leaving a half-written file if the process is killed.
# ensure_ascii=False for the same reason as the skillOverrides merge above: the
# default escapes the em-dashes in the Auto Mode prose, which would leave the
# deployed file permanently checksum-divergent from the repo copy.
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
PYEOF
    then
        echo "  ❌ statusLine splice failed — settings.json unchanged" >&2
        rm -f "$CLAUDE_DIR/settings.json.tmp"
    else
        echo "  🎚️  settings.json statusLine wired"
    fi
fi

# Deploy rules (auto-loaded by Claude Code)
if [ -d "$CONFIG_SOURCE/rules" ] && [ "$(ls -A "$CONFIG_SOURCE/rules" 2>/dev/null)" ]; then
    echo ""
    echo "  📏 Setting up rules..."
    for rule in "$CONFIG_SOURCE/rules/"*.md; do
        if [ -f "$rule" ]; then
            rule_name="$(basename "$rule")"
            copy_if_missing "$rule" "$CLAUDE_DIR/rules/$rule_name"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Remove files this repo used to deploy but no longer does. copy_if_missing
# never deletes, so without this list a renamed or deleted rule lingers in
# $CLAUDE_DIR forever — and rules keep loading into every session.
# ---------------------------------------------------------------------------
STALE_FILES=(
    "rules/quality-workflow.md"    # merged into CLAUDE.md
    "rules/remote-and-voice.md"    # moved to repo docs/reference/
    "rules/reliability.md"         # moved to commands/plan/references/
    "hooks/end-of-turn.sh"         # unwired stub, deleted from repo
    "rules/ecosystem-tools.md"     # always-loaded rule → README "Ecosystem" section
)
for stale in "${STALE_FILES[@]}"; do
    if [ -f "$CLAUDE_DIR/$stale" ]; then
        echo "  🧹 Removing stale $stale"
        rm -f "$CLAUDE_DIR/$stale"
    fi
done

# Deploy agents
echo ""
echo "  🤖 Setting up agents..."
for agent in "$CONFIG_SOURCE/agents/"*.md; do
    if [ -f "$agent" ]; then
        agent_name="$(basename "$agent")"
        copy_if_missing "$agent" "$CLAUDE_DIR/agents/$agent_name"
    fi
done

# Deploy hooks (if present)
if [ -d "$SCRIPT_DIR/hooks" ] && [ "$(ls -A "$SCRIPT_DIR/hooks" 2>/dev/null)" ]; then
    echo ""
    echo "  🪝 Setting up hooks..."
    for hook in "$SCRIPT_DIR/hooks/"*; do
        if [ -f "$hook" ]; then
            hook_name="$(basename "$hook")"
            copy_if_missing "$hook" "$CLAUDE_DIR/hooks/$hook_name"
            chmod +x "$CLAUDE_DIR/hooks/$hook_name"
        fi
    done
fi

# Deploy skills (if present)
if [ -d "$SCRIPT_DIR/skills" ] && [ "$(ls -A "$SCRIPT_DIR/skills" 2>/dev/null)" ]; then
    echo ""
    echo "  🎯 Setting up skills..."
    mkdir -p "$CLAUDE_DIR/commands"
    for skill_dir in "$SCRIPT_DIR/skills/"*/; do
        if [ -d "$skill_dir" ]; then
            skill_name="$(basename "$skill_dir")"
            if [ ! -d "$CLAUDE_DIR/commands/$skill_name" ]; then
                echo "    📄 Copying skills/$skill_name"
                cp -r "$skill_dir" "$CLAUDE_DIR/commands/$skill_name"
            else
                # Compare each file within the skill directory (recursively)
                while read -r -u3 skill_file; do
                    rel="${skill_file#"$skill_dir"}"
                    dest="$CLAUDE_DIR/commands/$skill_name/$rel"
                    mkdir -p "$(dirname "$dest")"
                    copy_if_missing "$skill_file" "$dest"
                done 3< <(find "$skill_dir" -type f)
            fi
        fi
    done
fi

echo ""
echo "✅ my-claude installation complete!"
echo ""
echo "Configuration: $CLAUDE_DIR/"
echo "Development standards: $CLAUDE_DIR/CLAUDE.md"
echo "Rules (auto-loaded): $CLAUDE_DIR/rules/"
echo ""
echo "Available agents:"
for agent in "$CLAUDE_DIR/agents/"*.md; do
    if [ -f "$agent" ]; then
        agent_name="$(basename "$agent" .md)"
        echo "  - $agent_name"
    fi
done
echo ""
echo "Available skills (/slash commands):"
for skill_dir in "$CLAUDE_DIR/commands/"*/; do
    if [ -d "$skill_dir" ]; then
        skill_name="$(basename "$skill_dir")"
        echo "  - /$skill_name"
    fi
done
echo ""
