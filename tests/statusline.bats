#!/usr/bin/env bats
# Tests for config/statusline/statusline.sh — the fixed-height 2-line bar.
#
# Contract under test:
#   stdin:  the Claude Code statusline JSON payload
#   stdout: EXACTLY two lines, always, for every input
#   stderr: silent
#
# The height guarantee is the whole point of this file. The previous backend
# rendered a variable-height boxed panel that reached 15 rows whenever
# subagents were running, which is what motivated replacing it.

SL="$BATS_TEST_DIRNAME/../config/statusline/statusline.sh"

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # Deterministic width unless a test overrides it.
    export COLUMNS=80
}

# Render $1 (a JSON payload) and leave output in $output / $lines.
# The payload goes through a file rather than being interpolated into a
# `bash -c` string, so a payload containing quotes cannot break the harness.
render() {
    printf '%s' "$1" > "$BATS_TEST_TMPDIR/payload.json"
    run bash -c "bash '$SL' < '$BATS_TEST_TMPDIR/payload.json'"
}

# Visible width, with ANSI SGR sequences stripped.
visible() {
    printf '%s' "$1" | perl -pe 's/\e\[[0-9;]*m//g'
}

FULL='{"model":{"display_name":"Opus 5"},"effort":{"level":"high"},"context_window":{"used_percentage":38.4},"rate_limits":{"five_hour":{"used_percentage":23.5},"seven_day":{"used_percentage":41.2}},"cost":{"total_cost_usd":1.234,"total_duration_ms":720000}}'

# --- height: the core guarantee ------------------------------------------

@test "renders exactly 2 lines for a fully populated payload" {
    render "$FULL"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "renders exactly 2 lines for an empty object" {
    render '{}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "renders exactly 2 lines when context_window is null (post-/compact)" {
    render '{"model":{"display_name":"Opus 5"},"context_window":null,"rate_limits":null}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "renders exactly 2 lines for malformed input" {
    render 'not json at all'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "writes nothing to stderr" {
    printf '%s' "$FULL" > "$BATS_TEST_TMPDIR/p.json"
    run bash -c "bash '$SL' < '$BATS_TEST_TMPDIR/p.json' 2>&1 >/dev/null"
    [ -z "$output" ]
}

@test "survives quotes and shell metacharacters in payload strings" {
    render '{"model":{"display_name":"O'\''; rm -rf /; echo \"pwned\" #"},"context_window":{"used_percentage":42}}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$(visible "${lines[1]}")" == *"42%"* ]]
}

# --- field extraction -----------------------------------------------------

@test "shows model display name and effort level" {
    render "$FULL"
    [[ "$(visible "${lines[0]}")" == *"Opus 5"* ]]
    [[ "$(visible "${lines[0]}")" == *"high"* ]]
}

@test "shows context percentage from the native payload field" {
    render "$FULL"
    [[ "$(visible "${lines[1]}")" == *"38%"* ]]
}

@test "shows 5h and 7d rate limits when present" {
    render "$FULL"
    local l2; l2="$(visible "${lines[1]}")"
    [[ "$l2" == *"5h 23%"* ]]
    [[ "$l2" == *"7d 41%"* ]]
}

@test "omits rate limits entirely when the payload has none" {
    # A false "0%" would read as "no quota used" — worse than showing nothing.
    render '{"model":{"display_name":"Sonnet 5"},"context_window":{"used_percentage":12}}'
    local l2; l2="$(visible "${lines[1]}")"
    [[ "$l2" != *"5h"* ]]
    [[ "$l2" != *"7d"* ]]
    [[ "$l2" == *"12%"* ]]
}

@test "field order survives an absent effort level" {
    # Regression: an empty jq field collapsed adjacent delimiters and shifted
    # every later value left by one, so the model showed the context number.
    render '{"model":{"display_name":"Opus 5"},"context_window":{"used_percentage":77},"rate_limits":{"five_hour":{"used_percentage":11},"seven_day":{"used_percentage":22}}}'
    [[ "$(visible "${lines[0]}")" == *"Opus 5"* ]]
    [[ "$(visible "${lines[1]}")" == *"77%"* ]]
    [[ "$(visible "${lines[1]}")" == *"5h 11%"* ]]
}

@test "tolerates non-numeric cost and duration without touching stderr" {
    # printf '%.2f' on a string writes "invalid number" to stderr, which would
    # break the silent-stderr contract. Types are filtered in jq instead.
    local corp="$HOME/claude-corp/svc"
    mkdir -p "$corp"
    cd "$corp"
    printf '%s' '{"cost":{"total_cost_usd":"abc","total_duration_ms":"xyz"}}' > "$BATS_TEST_TMPDIR/p.json"
    run bash -c "bash '$SL' < '$BATS_TEST_TMPDIR/p.json' 2>&1 >/dev/null"
    [ -z "$output" ]
}

@test "tolerates non-numeric percentages" {
    render '{"context_window":{"used_percentage":"lots"},"rate_limits":{"five_hour":{"used_percentage":"n/a"}}}'
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "neutralizes a newline embedded in a payload string" {
    # Fields are read positionally, one per line; an embedded newline would
    # desync every field after it (and could add a third output line).
    render '{"model":{"display_name":"Evil\nInjected"},"context_window":{"used_percentage":50}}'
    [ "${#lines[@]}" -eq 2 ]
    [[ "$(visible "${lines[1]}")" == *"50%"* ]]
}

@test "degrades to 2 quiet lines when jq is unavailable" {
    # jq ships with macOS, but the bar must not spew errors or collapse if it
    # is ever missing — it runs on a timer, so a failure would repeat forever.
    local stub="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$stub"
    printf '#!/bin/sh\nexit 127\n' > "$stub/jq"
    chmod +x "$stub/jq"

    # Prepend the stub to the *current* PATH, expanded here rather than inside
    # the `bash -c` string (where a mangled PATH would also hide bash itself).
    local stubbed="$stub:$PATH"

    PATH="$stubbed" run bash "$SL" < /dev/null
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]

    PATH="$stubbed" run bash -c "bash '$SL' < /dev/null 2>&1 >/dev/null"
    [ -z "$output" ]
}

@test "clamps a context percentage above 100" {
    render '{"context_window":{"used_percentage":140}}'
    [ "${#lines[@]}" -eq 2 ]
    [[ "$(visible "${lines[1]}")" == *"100%"* ]]
}

# --- git segment ----------------------------------------------------------

@test "shows branch and dirty marker inside a git repo" {
    local repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git commit -q --allow-empty -m root
    echo change > file.txt

    render "$FULL"
    local l1; l1="$(visible "${lines[0]}")"
    [[ "$l1" == *"main"* || "$l1" == *"master"* ]]
    [[ "$l1" == *"*"* ]]
}

@test "omits the git segment outside a repo" {
    local plain="$BATS_TEST_TMPDIR/plain"
    mkdir -p "$plain"
    cd "$plain"
    render "$FULL"
    [ "${#lines[@]}" -eq 2 ]
    [[ "$(visible "${lines[0]}")" != *"*"* ]]
}

# --- corp vs personal -----------------------------------------------------

@test "shows cost and elapsed time under ~/claude-corp" {
    local corp="$HOME/claude-corp/acme-svc"
    mkdir -p "$corp"
    cd "$corp"
    render "$FULL"
    local l2; l2="$(visible "${lines[1]}")"
    [[ "$l2" == *'$1.23'* ]]
    [[ "$l2" == *"12m"* ]]
    [[ "$l2" != *"5h"* ]]
}

@test "formats cost identically under a comma-decimal locale" {
    # Regression: printf '%.2f' parses per LC_NUMERIC, so under de_DE/fr_FR it
    # rendered "$1,00" — dropping the cents — and wrote "invalid number" to
    # stderr on every refresh. Cost is now carried as integer cents and split
    # with integer math, which no locale can reinterpret.
    local corp="$HOME/claude-corp/svc"
    mkdir -p "$corp"
    cd "$corp"
    printf '%s' '{"cost":{"total_cost_usd":1.234,"total_duration_ms":720000}}' \
        > "$BATS_TEST_TMPDIR/p.json"

    for loc in C de_DE.UTF-8 fr_FR.UTF-8; do
        run bash -c "LC_ALL=$loc bash '$SL' < '$BATS_TEST_TMPDIR/p.json' 2>/dev/null"
        [ "${#lines[@]}" -eq 2 ]
        [[ "$(visible "${lines[1]}")" == *'$1.23'* ]] || {
            echo "LC_ALL=$loc rendered: $(visible "${lines[1]}")" >&2
            return 1
        }
        run bash -c "LC_ALL=$loc bash '$SL' < '$BATS_TEST_TMPDIR/p.json' 2>&1 >/dev/null"
        [ -z "$output" ] || {
            echo "LC_ALL=$loc wrote to stderr: $output" >&2
            return 1
        }
    done
}

@test "rounds cost to cents correctly, including the carry" {
    local corp="$HOME/claude-corp/svc"
    mkdir -p "$corp"
    cd "$corp"
    render '{"cost":{"total_cost_usd":9.999,"total_duration_ms":0}}'
    [[ "$(visible "${lines[1]}")" == *'$10.00'* ]]
}

@test "shows rate limits outside ~/claude-corp" {
    local personal="$HOME/dev/project"
    mkdir -p "$personal"
    cd "$personal"
    render "$FULL"
    [[ "$(visible "${lines[1]}")" == *"5h 23%"* ]]
}

# --- responsive width -----------------------------------------------------

@test "both lines fit within COLUMNS at common widths" {
    for c in 120 100 80 72 64 56 50 45 40; do
        COLUMNS=$c render "$FULL"
        [ "${#lines[@]}" -eq 2 ]
        for l in "${lines[@]}"; do
            local w; w=$(visible "$l" | awk '{print length}')
            [ "$w" -le "$c" ] || {
                echo "COLUMNS=$c: line of width $w overflows: $(visible "$l")" >&2
                return 1
            }
        done
    done
}

@test "still emits 2 lines at a very narrow width" {
    COLUMNS=40 render "$FULL"
    [ "${#lines[@]}" -eq 2 ]
}
