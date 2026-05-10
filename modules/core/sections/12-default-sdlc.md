<!-- cappy:section:12-default-sdlc -->
## Default Workflow: Product SDLC Pipeline

15. **SDLC BY DEFAULT**: Unless the user opts out ("just fix this", "quick change", "skip the process"), all non-trivial tasks (new features, architectural changes, >3 files) MUST follow the 6-phase pipeline. Phases run in order. Do NOT start coding before Phase 3 is approved.

    ### Phase 1 — Discovery
    Explore the codebase (patterns, stack, relevant files). Research the problem space. Surface ambiguous/risky/assumption-heavy items. Produce a Research Brief and present it with your open questions. Wait for answers before proceeding.

    ### Phase 2 — Specification (PRD)
    Write a PRD with: problem + proposed solution, user stories with Given/When/Then acceptance criteria, scope (in/out/future), success metrics. Present it. **GATE: do not proceed without explicit user approval.**

    ### Phase 3 — Technical Design
    Produce a design with: architecture decisions and how they fit existing patterns, data model / schema changes, API contracts (request/response/errors), component breakdown, security considerations, **a numbered task list tagged [Backend] / [Frontend] / [Shared] ordered by dependency**. Present it. **GATE: do not proceed without explicit user approval.**

    ### Phase 4 — Implementation
    Work through the Phase 3 task list. For each task: implement, write tests, run type-check + lint. Backend/frontend run in parallel when using teams; sequential when solo with verification after each.

    ### Phase 5 — Review
    Audit code against: code quality (patterns, naming, duplication, error handling), security (OWASP Top 10, input validation, auth checks), architecture compliance vs. the approved design, test coverage. Fix issues and re-review before proceeding.

    ### Phase 6 — Validation
    Run all Definition of Done gates (rule 14): type check, lint, tests, build, coverage. Trace every PRD acceptance criterion — verify each passes. Fix and re-validate on any failure.

    ### When to skip
    User opt-outs: *"just do it"*, *"quick fix"*, *"skip the process"*, *"no PRD needed"*, *"I already know what I want, just build it"*. Single-file fixes, typos, config changes, and tasks with exact specs also skip. **Phase 6 (DoD gates) is never optional.**

    ### Presenting gates
    Be explicit. Don't hedge. *"Here's the PRD. Approve and proceed to design, or revise?"* and *"Here's the design and task breakdown. Approve and start building, or adjust?"*
<!-- cappy:end:12-default-sdlc -->
