<!-- cappy:section:12-default-sdlc -->
## Default Workflow: Product SDLC Pipeline

15. SDLC BY DEFAULT: Unless the user explicitly asks to skip the pipeline (e.g., "just fix this", "quick change", "skip the process"), ALL non-trivial tasks MUST follow the 6-phase SDLC pipeline. A task is "non-trivial" if it involves new features, architectural changes, or touches more than 3 files.

### The Pipeline

You MUST follow these phases in order. Do NOT skip phases. Do NOT start coding before Phase 3 is approved.

**Phase 1 — Discovery** (before writing any code or spec)
- Explore the existing codebase to understand current patterns, tech stack, and relevant files
- Research the problem space (competitive products, best practices, common pitfalls)
- Surface open questions — anything ambiguous, risky, or assumption-heavy
- Produce a Research Brief and present it with your questions
- Wait for the user to answer questions before proceeding

**Phase 2 — Specification** (before any technical design)
- Write a PRD containing:
  - Problem statement and proposed solution
  - User stories with acceptance criteria (Given/When/Then)
  - Scope: in-scope, out-of-scope, future considerations
  - Success metrics: how do we know this worked?
- Present the PRD to the user
- **GATE: Do NOT proceed until the user explicitly approves the PRD**

**Phase 3 — Technical Design** (before any implementation)
- Produce a design document containing:
  - Architecture decisions and how they fit existing patterns
  - Data model / schema changes (if any)
  - API contracts (request/response shapes, error codes)
  - Component breakdown (frontend, if applicable)
  - Security considerations
  - **Numbered task list** tagged [Backend], [Frontend], or [Shared], ordered by dependency
- Present the design to the user
- **GATE: Do NOT proceed until the user explicitly approves the design**

**Phase 4 — Implementation** (parallel where possible)
- Work through the task list from Phase 3 in order
- For each task: implement, write tests, run type-check + lint
- If using agent teams: backend and frontend tasks run in parallel
- If working solo: work through tasks sequentially, verify after each

**Phase 5 — Review** (self-review if solo, dedicated reviewer if team)
- Audit all code against:
  - Code quality: patterns, naming, duplication, error handling
  - Security: OWASP Top 10, input validation, auth checks
  - Architecture compliance: does the code match the approved design?
  - Test coverage: all new logic has tests
- If issues found: fix them and re-review. Do NOT proceed with issues.

**Phase 6 — Validation** (final gate)
- Run ALL Definition of Done gates:
  - Type check (zero errors)
  - Lint (zero errors)
  - Tests (all passing)
  - Build (succeeds)
  - Coverage (meets thresholds if configured)
- Trace every acceptance criterion from the PRD — verify each one passes
- If any gate fails or any acceptance criterion is unmet: fix and re-validate

### When to Skip
The user can opt out with phrases like:
- "Just do it" / "skip the process" / "quick fix"
- "No need for a PRD" / "skip discovery"
- "I already know what I want, just build it"
- Single-file bug fixes, typos, config changes, or tasks the user gives with exact specifications

When skipping, still apply the Definition of Done gates (Phase 6) — those are never optional.

### Presenting Gates to the User
At each approval gate, present a clear summary and explicitly ask:
- "Here's the PRD. Shall I proceed with technical design, or do you want changes?"
- "Here's the technical design and task breakdown. Ready to build, or adjustments needed?"
Do NOT use vague phrasing. Make it clear you are waiting for approval.
<!-- cappy:end:12-default-sdlc -->
