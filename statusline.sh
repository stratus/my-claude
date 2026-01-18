#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract model display name and context usage percentage
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Format output
if [ -n "$used_pct" ]; then
  # Round to nearest integer
  used_pct=$(printf "%.0f" "$used_pct")
  echo "[$model] Context: ${used_pct}%"
else
  # If no usage data available yet (null)
  echo "[$model] Context: --"
fi
