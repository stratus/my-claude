# Remote Control & Voice Input

## Remote Control (`/rc`)

Control local Claude Code sessions from a phone, tablet, or browser at claude.ai/code.

### How to Start
- **From existing session:** Type `/rc` (or `/remote-control`)
- **New session with RC:** `claude --rc` or `claude --rc -n "my-project"`
- **Server mode (multiple sessions):** `claude remote-control --capacity 3`

### Connecting from Mobile
1. Start RC session — a QR code and URL appear
2. Scan QR with Claude mobile app (iOS/Android) or open URL in browser
3. Session appears at claude.ai/code with green status dot

### Requirements
- **Claude.ai login** (not API keys) — the work Claude instance does NOT support RC
- Pro, Max, Team, or Enterprise subscription
- Terminal must stay open on the host machine

### Security Notes
- Only outbound HTTPS (no inbound ports opened)
- Local tools, MCP servers, and project config remain available remotely
- RC is per-session and intentional — never auto-started

## Voice Input (`/voice`)

Push-to-talk voice dictation for hands-free prompt creation.

### How to Use
- Toggle on/off: `/voice`
- **Hold Space** to record, release to transcribe
- Mix voice and typing in the same message
- Transcription is tuned for coding vocabulary

### Requirements
- Claude.ai login (not API keys)
- Local microphone access
- `voiceEnabled: true` is set in settings.json (enabled by default)

### Configuration
- Change language: `/config` → set `"language": "japanese"` (20 languages supported)
- Rebind push-to-talk key in `~/.claude/keybindings.json` under `voice:pushToTalk`
