# MCP Server Setup

MCP (Model Context Protocol) servers extend Claude Code with external tools and data sources.

## Recommended Global Servers

### GitHub MCP Server

Provides issue/PR management, repo browsing, and GitHub API access.

**Prerequisites:**
- GitHub Personal Access Token with `repo` scope
- Create at: https://github.com/settings/personal-access-tokens/new

**Install:**
```bash
claude mcp add-json github '{"type":"http","url":"https://api.githubcopilot.com/mcp","headers":{"Authorization":"Bearer YOUR_GITHUB_PAT"}}' --scope user
```

**Verify:**
```bash
claude mcp list
claude mcp get github
```

### Context7 MCP Server

Fetches current documentation instead of relying on training data. Useful for up-to-date library/framework docs.

**Install:**
```bash
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp@latest
```

**Usage:** Add "use context7" to prompts when you need current docs.

**Optional:** Get a free API key at https://context7.com/dashboard for higher rate limits.

## Management Commands

```bash
# List all configured servers
claude mcp list

# Get details for a specific server
claude mcp get <name>

# Remove a server
claude mcp remove <name> --scope user

# Check status in Claude Code
/mcp
```

## Configuration Location

- User-scoped MCP config: `~/.claude.json` (contains secrets, not committed)
- Project-scoped: `.mcp.json` in project root

## Best Practices

- Keep under 10 MCPs enabled to preserve context window
- Use `--scope user` for servers you want globally
- Use `--scope local` for project-specific servers
- Restart Claude Code after adding servers
