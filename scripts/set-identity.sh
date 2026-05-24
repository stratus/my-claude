#!/usr/bin/env bash
#
# Configure per-target identity for a my-claude install.
#
# Writes $CLAUDE_DIR/identity.json (the overlay applied by install.sh) and
# optionally adds one or more [includeIf "gitdir/i:..."] stanzas to
# ~/.gitconfig that point at $CLAUDE_DIR/.gitconfig.d/identity.inc, so git
# uses this identity when working inside the specified work-repo trees.
#
# IMPORTANT distinction: the gitdir pattern is the directory tree where your
# git **work repos** live, NOT your $CLAUDE_DIR. They are often different
# (e.g. corp config at ~/.claude-corp/ but corp repos at ~/claude-corp/).
#
# Usage: CLAUDE_DIR=~/.claude ./scripts/set-identity.sh
#        (invoked by `make set-identity`)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"
CLAUDE_DIR="${CLAUDE_DIR%/}"   # strip trailing slash (fixes double-slash bug)

echo ""
echo "🪪 Configuring identity for $CLAUDE_DIR"
echo ""

# Pre-flight: settings.json must exist
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    echo "❌ $CLAUDE_DIR/settings.json not found." >&2
    echo "   Run 'make install' first, then re-run 'make set-identity'." >&2
    exit 1
fi

# Pre-flight: python3 needed by install.sh's overlay applier
if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ python3 not found — install.sh needs it to apply the overlay." >&2
    echo "   Install Xcode CLT (macOS) or python3 (Linux), then re-run." >&2
    exit 1
fi

# Load existing identity for prompt defaults
existing_name=""
existing_email=""
if [ -f "$CLAUDE_DIR/identity.json" ]; then
    existing_name="$(python3 -c "import json; print(json.load(open('$CLAUDE_DIR/identity.json')).get('name',''))" 2>/dev/null || echo "")"
    existing_email="$(python3 -c "import json; print(json.load(open('$CLAUDE_DIR/identity.json')).get('email',''))" 2>/dev/null || echo "")"
fi

prompt_with_default() {
    local label="$1"
    local default="$2"
    local var
    if [ -n "$default" ]; then
        read -rp "  $label [$default]: " var
        echo "${var:-$default}"
    else
        read -rp "  $label: " var
        echo "$var"
    fi
}

name="$(prompt_with_default "Name" "$existing_name")"
email="$(prompt_with_default "Email" "$existing_email")"

# Reject whitespace-only inputs (a lone space or tab passes `[ -z ]` but
# would silently break git's [user] block).
if [[ -z "${name// }" ]] || [[ -z "${email// }" ]]; then
    echo "❌ Name and email are both required (non-whitespace)." >&2
    exit 1
fi

# Optional organization-specific trust prose
echo ""
read -rp "  Add organization-specific trust prose for Auto Mode? [y/N] " add_org
add_org="${add_org:-N}"

env_extras_json='[]'
if [[ "$add_org" =~ ^[yY]$ ]]; then
    echo "  Enter up to 3 trust-prose lines (blank line to finish):"
    extras=()
    extras+=("Developer: $name ($email), individual developer.")
    while [ "${#extras[@]}" -lt 4 ]; do
        read -rp "    line ${#extras[@]}: " line
        [ -z "$line" ] && break
        extras+=("$line")
    done
    # Build a JSON array via python3 (safe quoting)
    env_extras_json="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1:]))" "${extras[@]}")"
else
    env_extras_json="$(python3 -c "import json,sys; print(json.dumps([sys.argv[1]]))" "Developer: $name ($email), individual developer.")"
fi

# Write identity.json (chmod 600 — contains email)
tmp_dir="${TMPDIR:-/tmp}"
tmp_identity="$tmp_dir/identity.$$.json"
python3 - "$name" "$email" "$env_extras_json" > "$tmp_identity" <<'PYEOF'
import json, sys
name, email, extras_json = sys.argv[1], sys.argv[2], sys.argv[3]
data = {
    "name": name,
    "email": email,
    "environment_extras": json.loads(extras_json),
}
print(json.dumps(data, indent=2))
PYEOF

mv "$tmp_identity" "$CLAUDE_DIR/identity.json"
chmod 600 "$CLAUDE_DIR/identity.json"
echo "  ✅ Wrote $CLAUDE_DIR/identity.json"

# ----------------------------------------------------------------------------
# Optional git includeIf setup
# ----------------------------------------------------------------------------
# gitdir patterns describe the directory tree(s) where your git WORK REPOS
# live — NOT your Claude config dir. For the default ~/.claude target, the
# top-level [user] block in ~/.gitconfig usually covers personal repos
# already, so we default to N. For non-default targets we still default to
# N — the user opts in explicitly with `y`.

is_default_target=0
if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
    is_default_target=1
fi

echo ""
if [ "$is_default_target" = "1" ]; then
    echo "  Set up git includeIf so this identity applies in specific directory trees? [y/N]"
    echo "    Default is N — your top-level [user] block in ~/.gitconfig already covers personal repos."
else
    echo "  Set up git includeIf so this identity applies in specific directory trees? [y/N]"
    echo "    Answer y if you have work repos in dedicated trees that should use this identity."
fi
read -rp "  > " add_git
add_git="${add_git:-N}"

declare -a patterns=()
use_case_insensitive=0

if [[ "$add_git" =~ ^[yY]$ ]]; then
    echo ""
    echo "  Which directory tree(s) hold your git work repos that should use this identity?"
    echo "  NOTE: This is NOT your Claude config dir ($CLAUDE_DIR) — it's the tree(s)"
    echo "        under which you clone the actual git repos."
    echo "  Examples:"
    echo "    ~/claude-corp/                       (one tree)"
    echo "    ~/work/nvidia/, ~/src/nvidia/        (multiple trees, comma-separated)"
    echo "  Patterns must end with /. Press Enter to skip."
    echo ""

    while :; do
        read -rp "  Patterns: " raw_patterns
        if [ -z "$raw_patterns" ]; then
            echo "    (empty — skipping git includeIf setup)"
            add_git="N"
            break
        fi
        # Reject escaped commas (paths with literal commas need multiple runs)
        if [[ "$raw_patterns" == *'\,'* ]]; then
            echo "    ⚠️  Escaped commas (\\,) are not supported. For paths containing a literal"
            echo "        comma, run 'make set-identity' once per pattern."
            continue
        fi
        # Split on , and trim whitespace
        patterns=()
        bad=()
        IFS=',' read -ra raw_arr <<< "$raw_patterns"
        for p in "${raw_arr[@]}"; do
            # Trim leading and trailing whitespace. POSIX char-class negation
            # inside a bash glob is [^[:space:]], NOT [![:space:]] (that's a
            # different beast and silently misbehaves).
            p="${p#"${p%%[^[:space:]]*}"}"
            p="${p%"${p##*[^[:space:]]}"}"
            [ -z "$p" ] && continue
            if [[ "$p" != */ ]]; then
                bad+=("$p")
            else
                patterns+=("$p")
            fi
        done
        if [ "${#bad[@]}" -gt 0 ]; then
            echo "    ⚠️  These patterns are missing the trailing slash:"
            for b in "${bad[@]}"; do echo "        $b"; done
            echo "    Add trailing slashes and try the whole field again."
            continue
        fi
        if [ "${#patterns[@]}" -eq 0 ]; then
            echo "    ⚠️  No valid patterns supplied. Try again or press Enter to skip."
            continue
        fi
        break
    done

    # Case-sensitivity prompt (only if we actually have patterns)
    if [ "${#patterns[@]}" -gt 0 ] && [[ "$add_git" =~ ^[yY]$ ]]; then
        case_default="N"
        case_hint="[y/N]"
        if [ "$(uname -s)" = "Darwin" ]; then
            case_default="Y"
            case_hint="[Y/n]"
        fi
        echo ""
        echo "  Match case-insensitively? $case_hint"
        echo "    (macOS APFS is case-insensitive by default; Linux ext4 is case-sensitive)"
        read -rp "  > " case_ans
        case_ans="${case_ans:-$case_default}"
        if [[ "$case_ans" =~ ^[yY]$ ]]; then
            use_case_insensitive=1
        fi
    fi
fi

if [[ "$add_git" =~ ^[yY]$ ]] && [ "${#patterns[@]}" -gt 0 ]; then
    inc_dir="$CLAUDE_DIR/.gitconfig.d"
    inc_file="$inc_dir/identity.inc"
    inc_file_tilde="${inc_file/#$HOME/\~}"
    mkdir -p "$inc_dir"
    cat > "$inc_file" <<EOF
[user]
    name = $name
    email = $email
EOF
    chmod 600 "$inc_file"
    echo ""
    echo "  ✅ Wrote $inc_file"

    # Backup ~/.gitconfig before any mutation
    backup_file="$HOME/.gitconfig.bak.$(date +%s).$$"
    if [ -f "$HOME/.gitconfig" ]; then
        cp -p "$HOME/.gitconfig" "$backup_file"
        echo "  💾 Backed up ~/.gitconfig → $backup_file"
    fi

    # Subsection prefix
    if [ "$use_case_insensitive" = "1" ]; then
        prefix="gitdir/i"
    else
        prefix="gitdir"
    fi

    # Normalize a path for comparison: expand ~, collapse //, strip trailing /
    normalize_path() {
        local p="$1"
        p="${p/#\~/$HOME}"
        # Collapse repeated slashes
        while [[ "$p" == *//* ]]; do p="${p//\/\//\/}"; done
        echo "${p%/}"
    }
    target_normalized="$(normalize_path "$inc_file")"

    # Detect overlap with pre-existing includeIf stanzas (warning only).
    # Use --get-all because a single subsection may have multiple `path` values.
    while IFS= read -r existing_key; do
        [ -z "$existing_key" ] && continue
        existing_subsection="${existing_key#includeIf.}"
        existing_subsection="${existing_subsection%.path}"
        existing_pat="${existing_subsection#gitdir:}"
        existing_pat="${existing_pat#gitdir/i:}"
        while IFS= read -r existing_path; do
            [ -z "$existing_path" ] && continue
            for new_pat in "${patterns[@]}"; do
                if [ "$(normalize_path "$existing_path")" != "$target_normalized" ] \
                   && [ -n "$existing_pat" ] \
                   && [[ "$new_pat" == "$existing_pat"* ]] \
                   && [ "$new_pat" != "$existing_pat" ]; then
                    echo "  ⚠️  Pre-existing [includeIf \"$existing_subsection\"] (path = $existing_path)"
                    echo "      may shadow your new pattern '$new_pat' depending on file ordering."
                    echo "      Review with: git config --global --list --show-origin | grep -A1 includeIf"
                fi
            done
        done < <(git config --global --get-all "$existing_key" 2>/dev/null || true)
    done < <(git config --global --name-only --get-regexp '^includeIf\.' 2>/dev/null | sort -u || true)

    # For each pattern: check idempotency, add via git config
    added_count=0
    skipped_count=0
    for pat in "${patterns[@]}"; do
        # Idempotency: a stanza is a duplicate iff there exists a path value
        # under includeIf.<prefix:pat>.path that already points at our .inc.
        already=0
        while IFS= read -r existing_path; do
            [ -z "$existing_path" ] && continue
            if [ "$(normalize_path "$existing_path")" = "$target_normalized" ]; then
                already=1
                break
            fi
        done < <(git config --global --get-all "includeIf.$prefix:$pat.path" 2>/dev/null || true)

        if [ "$already" = "1" ]; then
            echo "  ⏭️  [includeIf \"$prefix:$pat\"] → $inc_file_tilde already present"
            skipped_count=$((skipped_count + 1))
        else
            # git config handles locking, escaping, canonical output
            git config --global --add "includeIf.$prefix:$pat.path" "$inc_file_tilde"
            echo "  ✅ Added [includeIf \"$prefix:$pat\"] → $inc_file_tilde"
            added_count=$((added_count + 1))
        fi
    done
    echo "  📊 includeIf summary: $added_count added, $skipped_count already present"
fi

# Re-apply overlay to settings.json by re-running install.sh's relevant section.
echo ""
echo "  🔄 Re-running install.sh to apply overlay..."
FORCE_UPDATE=1 CLAUDE_DIR="$CLAUDE_DIR" "$REPO_DIR/install.sh" > "$tmp_dir/set-identity-install.$$.log" 2>&1 || {
    echo "  ❌ install.sh failed — see $tmp_dir/set-identity-install.$$.log" >&2
    exit 1
}
rm -f "$tmp_dir/set-identity-install.$$.log"

echo ""
echo "✅ Identity configured for $CLAUDE_DIR"
echo "   Name:  $name"
echo "   Email: $email"
if [[ "$add_git" =~ ^[yY]$ ]] && [ "${#patterns[@]}" -gt 0 ]; then
    for pat in "${patterns[@]}"; do
        echo "   Git:   [includeIf \"$prefix:$pat\"] → $inc_file_tilde"
    done
fi
echo ""
