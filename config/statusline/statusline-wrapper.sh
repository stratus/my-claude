#!/usr/bin/env bash
#
# Statusline wrapper — context-aware configuration
#
# Detects the working directory and applies ENV_CONFIG_* overrides
# for API-based (corp) vs Max subscription (personal) usage.
#
# Corp directory: ~/claude-corp/
#   -> Enables cost tracking, burn rate, context window, usage limits
#
# All other directories: personal defaults from Config.toml
#

if [[ "$PWD" == "$HOME/claude-corp"* ]]; then
    # API-based account: cost and usage awareness matters
    export ENV_CONFIG_SHOW_COST_TRACKING=true
    export ENV_CONFIG_DISPLAY_LINES=2
    export ENV_CONFIG_LINE1_COMPONENTS="repo_info,model_info,context_window,time_display"
    export ENV_CONFIG_LINE2_COMPONENTS="cost_daily,burn_rate,usage_limits,commits"
fi

WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$WRAPPER_DIR/statusline.sh"
