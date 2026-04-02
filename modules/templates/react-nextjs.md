# {{PROJECT_NAME}} — Development Guide

## Tech Stack
- **Framework**: Next.js {{NEXT_VERSION}} with App Router
- **Language**: TypeScript (strict mode)
- **Styling**: {{CSS_SOLUTION}}
- **State**: {{STATE_MANAGEMENT}}
- **Database**: {{DATABASE}}
- **Auth**: {{AUTH_PROVIDER}}

## Commands
```bash
{{PKG_MANAGER}} dev          # Start dev server
{{PKG_MANAGER}} build        # Production build
{{PKG_MANAGER}} test         # Run tests
{{PKG_MANAGER}} lint         # Run linter
{{PKG_MANAGER}} tsc          # Type check (npx tsc --noEmit)
```

## Architecture
- `src/app/` — App Router pages and layouts
- `src/components/` — Reusable UI components
- `src/lib/` — Utilities, API clients, helpers
- `src/hooks/` — Custom React hooks
- `src/stores/` — State management
- `src/types/` — TypeScript type definitions

## Code Style
- Use TypeScript strict mode — no `any`, no `as` casts without justification
- Components: named exports, PascalCase files
- Server components by default; add `'use client'` only when needed
- Prefer server actions over API routes for mutations
- Use Zod for runtime validation at system boundaries
