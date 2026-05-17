#!/usr/bin/env bash
# =============================================================================
# UserPromptExpansion Hook: Log Skill Invocations
# =============================================================================
#
# Fires when a slash command (skill) expands. Appends a single line to
# ~/.claude/skill-usage.log so the user can review which skills they've used,
# how often, and with what arguments — without parsing transcripts after the
# fact.
#
# Only logs the long-running workflow skills (plan, implement, autopilot,
# polish, audit). Short utility skills (commit-messages, pr, remember, etc.)
# fire too often to be useful in the log. Adjust the matcher in
# config/settings.json to widen the net.
#
# Log line format (tab-separated for easy awk/cut):
#   ISO-8601-timestamp \t command_name \t command_source \t command_args
#
# Exit code: always 0. Observability must never block a session.
# =============================================================================

set -euo pipefail

INPUT=$(cat)
CMD_NAME=$(echo "$INPUT" | jq -r '.command_name // empty')
CMD_SRC=$(echo "$INPUT"  | jq -r '.command_source // "unknown"')
CMD_ARGS=$(echo "$INPUT" | jq -r '.command_args // ""')

# Bail silently if no command name (malformed event).
[[ -z "$CMD_NAME" ]] && exit 0

LOG="$HOME/.claude/skill-usage.log"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Atomic append (one printf, single write syscall).
printf '%s\t%s\t%s\t%s\n' "$TS" "$CMD_NAME" "$CMD_SRC" "$CMD_ARGS" >> "$LOG"

exit 0
