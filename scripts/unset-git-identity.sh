#!/usr/bin/env bash
#
# Remove the [includeIf] stanzas in ~/.gitconfig that point at this target's
# identity.inc, and delete the .inc file itself. Symmetrical with the set
# operation in scripts/set-identity.sh.
#
# Does NOT touch $CLAUDE_DIR/identity.json — that is `make unset-identity`'s
# responsibility (deletes the overlay and restores placeholders in settings.json).
#
# Usage: CLAUDE_DIR=~/.claude ./scripts/unset-git-identity.sh
#        (invoked by `make unset-git-identity`)
#

set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"
CLAUDE_DIR="${CLAUDE_DIR%/}"

inc_file="$CLAUDE_DIR/.gitconfig.d/identity.inc"

echo ""
echo "🧹 Removing git includeIf stanzas pointing at $inc_file"
echo ""

# Normalize a path for comparison: expand ~, collapse //, strip trailing /
normalize_path() {
    local p="$1"
    p="${p/#\~/$HOME}"
    while [[ "$p" == *//* ]]; do p="${p//\/\//\/}"; done
    echo "${p%/}"
}
target_normalized="$(normalize_path "$inc_file")"

# Backup ~/.gitconfig before any mutation
if [ ! -f "$HOME/.gitconfig" ]; then
    echo "  ⏭️  ~/.gitconfig does not exist — nothing to remove from"
else
    backup_file="$HOME/.gitconfig.bak.$(date +%s).$$"
    cp -p "$HOME/.gitconfig" "$backup_file"
    echo "  💾 Backed up ~/.gitconfig → $backup_file"

    # Collect (subsection, matching_path_value) tuples to remove. A single
    # subsection can have multiple `path = ` values (git merges into the same
    # section when --add is called with an identical subsection name). We
    # must --unset only the values pointing at our target, not the whole
    # section — that would destroy any legacy path values the user has.
    # Use --fixed-value so we compare literally, no regex escaping required.
    removed_count=0
    declare -a unset_entries=()
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        # git canonicalizes section names to lowercase. Strip the
        # 'includeif.' prefix case-insensitively to recover the subsection.
        shopt -s nocasematch
        if [[ "$key" =~ ^includeif\.(.*)\.path$ ]]; then
            subsection="${BASH_REMATCH[1]}"
        else
            shopt -u nocasematch
            continue
        fi
        shopt -u nocasematch
        # Iterate all values for this key (--get-all handles multi-value)
        while IFS= read -r existing_path; do
            [ -z "$existing_path" ] && continue
            if [ "$(normalize_path "$existing_path")" = "$target_normalized" ]; then
                unset_entries+=("$subsection|$existing_path")
            fi
        done < <(git config --global --get-all "$key" 2>/dev/null || true)
    done < <(git config --global --name-only --get-regexp '^includeIf\.' 2>/dev/null | sort -u || true)

    if [ "${#unset_entries[@]}" -eq 0 ]; then
        echo "  ⏭️  No matching [includeIf] stanzas found in ~/.gitconfig"
    else
        # Track which subsections we've touched, so we can later check if any
        # are now empty and worth --remove-section'ing for tidiness.
        declare -a touched_subsections=()
        for entry in "${unset_entries[@]}"; do
            subsection="${entry%%|*}"
            existing_path="${entry#*|}"
            echo "  → unsetting [includeIf \"$subsection\"].path = $existing_path"
            git config --global --unset --fixed-value "includeIf.$subsection.path" "$existing_path"
            removed_count=$((removed_count + 1))
            already_touched=0
            for t in "${touched_subsections[@]:-}"; do
                [ "$t" = "$subsection" ] && already_touched=1 && break
            done
            [ "$already_touched" = "0" ] && touched_subsections+=("$subsection")
        done
        # For each touched subsection: if it has no remaining `path` values,
        # remove the bracketed header itself. Otherwise leave it (a legacy
        # path value is still there).
        for subsection in "${touched_subsections[@]:-}"; do
            [ -z "$subsection" ] && continue
            if ! git config --global --get-all "includeIf.$subsection.path" >/dev/null 2>&1; then
                git config --global --remove-section "includeIf.$subsection" 2>/dev/null || true
                echo "  → removed now-empty [includeIf \"$subsection\"] header"
            fi
        done
    fi
    echo "  📊 Removed $removed_count path value(s)"
fi

# Delete the .inc file and tidy up the parent dir if empty
if [ -f "$inc_file" ]; then
    rm -f "$inc_file"
    echo "  🗑️  Deleted $inc_file"
fi
inc_dir="$CLAUDE_DIR/.gitconfig.d"
if [ -d "$inc_dir" ] && [ -z "$(ls -A "$inc_dir" 2>/dev/null || true)" ]; then
    rmdir "$inc_dir"
    echo "  🗑️  Removed empty $inc_dir/"
fi

echo ""
echo "✅ Git includeIf for $CLAUDE_DIR cleaned up"
echo "   (identity.json untouched — run 'make unset-identity' to remove the overlay)"
echo ""
