#!/usr/bin/env bash
# =============================================================================
# Notification Hook: Desktop Alerts
# =============================================================================
#
# This hook runs when Claude Code sends notifications.
# It triggers desktop notifications so you know when Claude needs input.
#
# Works on:
#   - macOS (osascript)
#   - Linux (notify-send)
#   - Windows WSL (powershell)
#
# Usage:
#   Add to ~/.claude/settings.json:
#   {
#     "hooks": {
#       "Notification": [
#         {
#           "matcher": "*",
#           "hooks": [
#             {
#               "type": "command",
#               "command": "~/.claude/hooks/notify.sh"
#             }
#           ]
#         }
#       ]
#     }
#   }
# =============================================================================

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract notification content
CONTENT=$(echo "$INPUT" | jq -r '.content // "Claude needs your attention"')

# Truncate long messages
if [[ ${#CONTENT} -gt 100 ]]; then
    CONTENT="${CONTENT:0:100}..."
fi

# -----------------------------------------------------------------------------
# Send notification based on OS
# -----------------------------------------------------------------------------

send_notification() {
    local title="Claude Code"
    local message="$1"
    
    # macOS — pass message/title as env vars and read via osascript's
    # `system attribute` so the payload is treated as data, not shell code.
    # Earlier versions interpolated $message into a double-quoted -e string,
    # which let `$(...)`, backticks, and `$VAR` expand before osascript saw them.
    if [[ "$OSTYPE" == "darwin"* ]]; then
        MSG="$message" TITLE="$title" osascript \
            -e 'display notification (system attribute "MSG") with title (system attribute "TITLE") sound name "Glass"' \
            2>/dev/null || true
        return
    fi
    
    # Linux with notify-send
    if command -v notify-send &>/dev/null; then
        notify-send "$title" "$message" -u normal -t 5000 2>/dev/null || true
        return
    fi
    
    # Windows WSL
    #
    # Base64-encode title/message on the bash side so the PowerShell template
    # never interpolates user-controlled text directly into XML. Decoded
    # values are XML-escaped via [System.Security.SecurityElement]::Escape
    # before being injected, so a message containing </text> or & can't
    # break or hijack the toast XML.
    if grep -qi microsoft /proc/version 2>/dev/null; then
        local title_b64 message_b64
        title_b64=$(printf '%s' "$title" | base64 | tr -d '\n')
        message_b64=$(printf '%s' "$message" | base64 | tr -d '\n')
        powershell.exe -Command "
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
            \$titleRaw   = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${title_b64}'))
            \$messageRaw = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${message_b64}'))
            \$titleXml   = [System.Security.SecurityElement]::Escape(\$titleRaw)
            \$messageXml = [System.Security.SecurityElement]::Escape(\$messageRaw)
            \$template = '<toast><visual><binding template=\"ToastText02\"><text id=\"1\">' + \$titleXml + '</text><text id=\"2\">' + \$messageXml + '</text></binding></visual></toast>'
            \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
            \$xml.LoadXml(\$template)
            \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
            [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
        " 2>/dev/null || true
        return
    fi
    
    # Fallback: terminal bell
    echo -e '\a'
}

send_notification "$CONTENT"
exit 0
