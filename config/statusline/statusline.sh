#!/usr/bin/env bash
#
# Claude Code statusline — fixed 2-line bar.
#
#   ~/d/s/my-claude  main*  Opus 5 · high
#   ctx ████░░░░░░ 38%  |  5h 23%  |  7d 41%
#
# Reads the session JSON payload on stdin and prints exactly two lines. The
# height is fixed by construction: two printf calls, no conditional rows. That
# is the property this file exists to guarantee — the previous backend grew to
# 15 lines whenever subagents were running.
#
# Under ~/claude-corp/ (API-billed) line 2 shows session cost + elapsed instead
# of rate limits, because cost is the real number on an API account and rate
# limits are absent there.
#
# Notes:
#   - `tput cols` cannot work here: Claude Code captures stdout rather than
#     attaching a tty. Read $COLUMNS instead (set by Claude Code, v2.1.153+).
#   - context_window is null before the first API call and again after
#     /compact. rate_limits is absent entirely on non-Pro/Max accounts.
#   - context_window.used_percentage counts input tokens only, hence the terse
#     "ctx" label rather than implying whole-window occupancy.

set -uo pipefail

payload="$(cat)"

# --- one jq call, one field per line ---------------------------------------
# Eight subprocesses per refresh would be wasteful at refreshInterval=5, so
# extract everything in a single pass. `// 0` guards both a null field and a
# null parent object, since jq traverses null without erroring. Fields are read
# positionally by `mapfile`, so every one must emit exactly one non-empty line —
# an empty or newline-bearing value shifts every field after it.
mapfile -t _f < <(printf '%s' "$payload" | jq -r '
  # num accepts a JSON number OR a numeric string, so a future payload that
  # ships percentages as strings still reads correctly instead of silently
  # rendering 0% forever. Anything else (object, bool, null) yields null.
  def num: if type == "number" then . elif type == "string" then (tonumber? // null) else null end;

  [ (.model.display_name // "?")
  , (if (.effort.level // "") == "" then "-" else .effort.level end)
  , ((.context_window.used_percentage | num // 0) | floor)
  , ((.rate_limits.five_hour.used_percentage | num // 0) | floor)
  , ((.rate_limits.seven_day.used_percentage | num // 0) | floor)
  # Integer CENTS, deliberately. Formatting with printf '%.2f' would parse per
  # LC_NUMERIC: under a comma-decimal locale bash renders "$1,00" (dropping the
  # cents entirely) and writes "invalid number" to stderr on every refresh.
  # Integer cents split by integer math below is locale-independent, and it
  # drops a fork from the hot path.
  , ((.cost.total_cost_usd | num // 0) * 100 | round)
  , ((.cost.total_duration_ms | num // 0) | floor)
  , (if (.rate_limits.five_hour.used_percentage | num) == null then 0 else 1 end)
  ]
  # Strip newlines from any field: this list is read positionally, one field
  # per line, so an embedded newline in (say) a model name would desync it.
  | map(tostring | gsub("[\r\n]"; " ")) | .[]' 2>/dev/null)

# jq missing or payload unparseable: still emit two lines, never zero.
model="${_f[0]:-?}"
effort="${_f[1]:--}"
ctx_pct="${_f[2]:-0}"
five_h="${_f[3]:-0}"
seven_d="${_f[4]:-0}"
cost="${_f[5]:-0}"
dur_ms="${_f[6]:-0}"
has_limits="${_f[7]:-0}"

# --- colors ----------------------------------------------------------------
C_PATH=$'\033[38;5;75m'
C_GIT=$'\033[38;5;114m'
C_MODEL=$'\033[38;5;226m'
C_DIM=$'\033[38;5;246m'
C_ACCENT=$'\033[38;5;180m'
C_OK=$'\033[38;5;40m'
C_WARN=$'\033[38;5;214m'
C_CRIT=$'\033[38;5;203m'
R=$'\033[0m'

# --- path: ~/dev/stratus/my-claude -> ~/d/s/my-claude ----------------------
# A bare ${PWD/#$HOME/~} leaves the tilde escaped, so branch explicitly.
p="$PWD"
case "$p" in
    "$HOME") p="~" ;;
    "$HOME"/*) p="~${p#"$HOME"}" ;;
esac
short_path="$(printf '%s' "$p" | awk -F/ 'BEGIN{OFS="/"}
    { for (i = 1; i < NF; i++) if ($i != "~" && $i != "") $i = substr($i, 1, 1); print }')"

# --- git: branch + dirty marker -------------------------------------------
# --no-optional-locks and an emptied core.fsmonitor keep a bar that fires every
# few seconds from contending with the user's real git commands over the index.
git_seg=""
if g_branch=$(git -c core.fsmonitor= --no-optional-locks symbolic-ref --quiet --short HEAD 2>/dev/null) \
   || g_branch=$(git -c core.fsmonitor= --no-optional-locks rev-parse --short HEAD 2>/dev/null); then
    dirty=""
    if ! git -c core.fsmonitor= --no-optional-locks diff --quiet --ignore-submodules HEAD 2>/dev/null; then
        dirty="*"
    elif [ -n "$(git -c core.fsmonitor= --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | head -n 1)" ]; then
        dirty="*"
    fi
    git_seg="  ${C_GIT}${g_branch}${dirty}${R}"
fi

# --- context bar -----------------------------------------------------------
case "$ctx_pct" in ''|*[!0-9]*) ctx_pct=0 ;; esac
[ "$ctx_pct" -gt 100 ] && ctx_pct=100
if   [ "$ctx_pct" -ge 85 ]; then c_ctx="$C_CRIT"
elif [ "$ctx_pct" -ge 60 ]; then c_ctx="$C_WARN"
else                            c_ctx="$C_OK"
fi
# Narrow terminals get a 5-cell bar so line 2 still fits; line 2 carries only
# fixed-width data, so the bar is the sole segment that can give ground.
cols="${COLUMNS:-80}"
bar_cells=10
[ "$cols" -lt 64 ] && bar_cells=5
filled=$(( ctx_pct * bar_cells / 100 ))
bar=""
for ((i = 0; i < bar_cells; i++)); do
    if [ "$i" -lt "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
done

# --- line 1 ----------------------------------------------------------------
effort_seg=""
[ -n "${effort:-}" ] && [ "$effort" != "-" ] && effort_seg=" ${C_DIM}·${R} ${C_ACCENT}${effort}${R}"

# Truncate the path if the terminal is narrow — it is the only segment on
# line 1 that can grow without bound.
max_path=$(( cols - 34 ))
[ "$max_path" -lt 12 ] && max_path=12
if [ "${#short_path}" -gt "$max_path" ]; then
    short_path="…${short_path: -$((max_path - 1))}"
fi

printf '%s %s%s%s%s  %s%s%s%s\n' \
    "" "$C_PATH" "$short_path" "$R" "$git_seg" "$C_MODEL" "$model" "$R" "$effort_seg"

# --- line 2 ----------------------------------------------------------------
# Kept deliberately ANSI-light: multi-line status lines with escape codes are
# more prone to rendering issues and can collapse on terminal resize.
# Separator widens with the terminal; at very narrow widths every space counts.
if [ "$cols" -lt 56 ]; then sep=" ${C_DIM}|${R} "; else sep="  ${C_DIM}|${R}  "; fi
# Below ~48 cols the "ctx" label is the first thing to go; the bar itself still
# reads as a context meter without it.
if [ "$cols" -lt 48 ]; then
    line2=" ${c_ctx}${bar} ${ctx_pct}%${R}"
else
    line2=" ${C_DIM}ctx${R} ${c_ctx}${bar} ${ctx_pct}%${R}"
fi

case "$PWD" in
    "$HOME"/claude-corp*)
        # API-billed: cost is real, rate limits are not reported.
        mins=$(( ${dur_ms:-0} / 60000 ))
        # $cost is integer cents; split it with integer math so no float
        # formatting (and therefore no locale) is involved.
        cents="${cost:-0}"
        case "$cents" in ''|*[!0-9]*) cents=0 ;; esac
        line2="${line2}${sep}${C_ACCENT}\$$(( cents / 100 )).$(printf '%02d' $(( cents % 100 )))${R}"
        line2="${line2}${sep}${C_ACCENT}${mins}m${R}"
        ;;
    *)
        # Subscription: show quota headroom. Omit entirely when the payload
        # carries no rate_limits — a false "0%" reads as "nothing used".
        if [ "$has_limits" = "1" ]; then
            line2="${line2}${sep}${C_ACCENT}5h ${five_h}%${R}"
            line2="${line2}${sep}${C_ACCENT}7d ${seven_d}%${R}"
        fi
        ;;
esac

printf '%s\n' "$line2"
