# Project Templates

Domain-specific CLAUDE.md templates for new projects. These extend the global `~/.claude/CLAUDE.md` with stack-specific patterns.

## Available Templates

| Template | Use For |
|----------|---------|
| `nextjs/` | Next.js 15+ web apps with App Router, Tailwind, shadcn/ui |
| `react-native/` | React Native/Expo mobile apps |
| `go-cli/` | Go CLI tools and services |
| `cuj-template.md` | Critical User Journey document scaffold |
| `ad-template.md` | Architecture Decision Record (ADR) scaffold |

## Usage

Copy the `.claude/` directory to your new project:

```bash
# For a Next.js project
cp -r ~/my-claude/templates/nextjs/.claude ~/your-new-project/

# For a React Native project
cp -r ~/my-claude/templates/react-native/.claude ~/your-new-project/

# For a Go CLI/service
cp -r ~/my-claude/templates/go-cli/.claude ~/your-new-project/
```

Then customize the `CLAUDE.md` for your specific project needs.

## Template Contents

Each template provides:
- Stack-specific architecture guidance
- Coding rules and patterns
- Testing strategy
- Build and deployment commands

## Customization

After copying, update:
1. Project-specific paths and commands
2. Team conventions that differ from defaults
3. Additional tools or frameworks used
