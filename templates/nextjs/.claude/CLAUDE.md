# Next.js Project Guidelines

Project-specific rules that extend global `~/.claude/CLAUDE.md`.

## Stack

- Next.js 15+ with App Router
- React 19, TypeScript strict mode
- Tailwind CSS + shadcn/ui components
- Vercel AI SDK for streaming/AI features (if applicable)

## Architecture

```
src/
├── app/           # App Router pages and layouts
├── components/    # React components
│   ├── ui/        # shadcn/ui primitives
│   └── [feature]/ # Feature-specific components
├── lib/           # Utilities, helpers
├── hooks/         # Custom React hooks
└── types/         # TypeScript types
```

## Rules

### Components
- Server Components by default; add `'use client'` only when needed
- Prefer Server Actions over API routes for mutations
- Use `next/image` for all images, `next/font` for fonts
- No barrel exports (breaks tree-shaking)

### Data Fetching
- Fetch in Server Components, not client
- Use `cache()` for request deduplication
- Implement loading.tsx and error.tsx for each route segment

### Styling
- Tailwind utility classes only; no custom CSS unless necessary
- Use shadcn/ui components before creating custom ones
- Mobile-first responsive design (`sm:`, `md:`, `lg:`)

### Performance
- Minimize `'use client'` boundaries
- Use dynamic imports for heavy components: `dynamic(() => import(...))`
- Implement Suspense boundaries for streaming

### Testing
- Playwright for E2E tests in `e2e/`
- Vitest for unit tests alongside components
- Test user flows, not implementation details

## Commands

```bash
npm run dev      # Development server
npm run build    # Production build
npm run test     # Run tests
npm run lint     # ESLint + TypeScript check
```

## Deployment

- Vercel (automatic via GitHub integration)
- Preview deployments on PRs
- Production on main branch
