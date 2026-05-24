#!/usr/bin/env bash
#
# Configure per-target identity for a my-claude install.
#
# Writes $CLAUDE_DIR/identity.json (the overlay applied by install.sh) and
# optionally adds an [includeIf "gitdir:..."] block to ~/.gitconfig that
# points at $CLAUDE_DIR/.gitconfig.d/identity.inc so git uses this identity
# when working inside the specified directory tree.
#
# Usage: CLAUDE_DIR=~/.claude ./scripts/set-identity.sh
#        (invoked by `make set-identity`)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

# Resolve ~/ in CLAUDE_DIR if present
CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"

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

# Optional git includeIf setup
echo ""
read -rp "  Set up git includeIf for this target? [y/N] " add_git
add_git="${add_git:-N}"

if [[ "$add_git" =~ ^[yY]$ ]]; then
    while :; do
        read -rp "    gitdir pattern (must end with /, e.g. ~/work/nvidia/): " gitdir
        if [ -z "$gitdir" ]; then
            echo "    (empty — skipping git includeIf setup)"
            add_git="N"
            break
        fi
        if [[ "$gitdir" != */ ]]; then
            echo "    ⚠️  gitdir must end with a trailing slash. Try again."
            continue
        fi
        break
    done
fi

if [[ "$add_git" =~ ^[yY]$ ]]; then
    inc_dir="$CLAUDE_DIR/.gitconfig.d"
    inc_file="$inc_dir/identity.inc"
    mkdir -p "$inc_dir"
    cat > "$inc_file" <<EOF
[user]
    name = $name
    email = $email
EOF
    chmod 600 "$inc_file"
    echo "  ✅ Wrote $inc_file"

    # Idempotent append to ~/.gitconfig — skip if already present.
    # Check both tilde and absolute forms (and a quoted variant) because a
    # user may have hand-edited ~/.gitconfig with any of them.
    gitconfig="$HOME/.gitconfig"
    inc_file_tilde="${inc_file/#$HOME/\~}"
    already_present=0
    if [ -f "$gitconfig" ]; then
        if grep -Fq "path = $inc_file_tilde" "$gitconfig" \
            || grep -Fq "path = $inc_file" "$gitconfig" \
            || grep -Fq "path = \"$inc_file_tilde\"" "$gitconfig" \
            || grep -Fq "path = \"$inc_file\"" "$gitconfig"; then
            already_present=1
        fi
    fi
    if [ "$already_present" = "1" ]; then
        echo "  ⏭️  ~/.gitconfig already references $inc_file_tilde — leaving alone"
    else
        printf '\n[includeIf "gitdir:%s"]\n    path = %s\n' "$gitdir" "$inc_file_tilde" >> "$gitconfig"
        echo "  ✅ Added [includeIf \"gitdir:$gitdir\"] to ~/.gitconfig"
    fi
fi

# Re-apply overlay to settings.json by re-running install.sh's relevant section.
# Easiest path: invoke install.sh — its overlay block runs unconditionally when
# identity.json is present and is idempotent.
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
[[ "$add_git" =~ ^[yY]$ ]] && echo "   Git:   includeIf gitdir:$gitdir → $inc_file_tilde"
echo ""
