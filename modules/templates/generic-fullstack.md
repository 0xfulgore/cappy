# {{PROJECT_NAME}} — Development Guide

## Tech Stack
- **Frontend**: {{FRONTEND}}
- **Backend**: {{BACKEND}}
- **Database**: {{DATABASE}}
- **Deployment**: {{DEPLOYMENT}}

## Commands
```bash
# Development
{{DEV_COMMAND}}

# Testing
{{TEST_COMMAND}}

# Linting
{{LINT_COMMAND}}

# Type checking
{{TYPECHECK_COMMAND}}

# Build
{{BUILD_COMMAND}}
```

## Architecture
Document your project structure here. Common patterns:
- Monorepo: `packages/frontend/`, `packages/backend/`, `packages/shared/`
- Standard: `src/`, `tests/`, `docs/`

## Code Style
- Consistent naming: camelCase for variables/functions, PascalCase for types/components
- No magic numbers — use named constants
- Error handling at system boundaries (user input, API calls, file I/O)
- Tests for all business logic
- Document non-obvious decisions with comments explaining *why*, not *what*
