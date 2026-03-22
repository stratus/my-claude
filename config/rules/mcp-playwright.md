# Playwright MCP for Web Projects

## When to Check

On first interaction with a project that contains **any** of these indicators:
- `package.json` with frontend dependencies (react, vue, svelte, angular, next, vite, etc.)
- `*.html`, `*.css`, `*.tsx`, `*.jsx` files in the source tree
- A web framework config (`next.config.*`, `vite.config.*`, `nuxt.config.*`, `angular.json`, etc.)

## What to Check

1. Look for `.mcp.json` in the project root
2. If present, verify it includes a `playwright` server entry
3. If absent or missing Playwright, suggest adding it

## How to Suggest

If the project qualifies and Playwright MCP is missing:

> "This project has web UI files but no Playwright MCP configured. Playwright MCP lets me take screenshots, interact with the browser, and visually verify UI changes. Would you like me to add it?"

If yes, create `.mcp.json` in the project root (or add to existing):
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    }
  }
}
```

Also suggest adding `context7` if not already present — see `templates/mcp.json.example` for the full recommended config.

## Do Not Nag

- Ask **once per session**. If the user declines, do not ask again.
- If the project already has Playwright configured via other means (e.g., user-scoped MCP in `~/.claude.json`), respect that.
- Do not suggest for projects that are purely backend (API-only, CLI tools, libraries with no UI).
