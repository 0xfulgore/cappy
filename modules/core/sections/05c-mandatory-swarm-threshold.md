<!-- cappy:section:05c-mandatory-swarm-threshold -->
7b. **MANDATORY SWARM SPLIT FOR LARGE WORK**: A task is "large" and MUST run via a Ruflo swarm (or `TeamCreate` fallback per 7a) — not solo, not a single sub-agent — when ANY threshold trips:

- **>10 files** touched (creates / edits / deletes)
- **>300 LOC** of net new or changed code
- **>8 numbered tasks** in the Phase 3 design
- **>2 hours** of focused work
- **>2 distinct subsystems** (e.g., backend + frontend + migrations)

### When to evaluate
- **End of Phase 3** — before any Phase 4 implementation. Use the Phase 3 task list / file count / architecture surface.
- **SDLC skipped** — evaluate before your first code-writing turn; if a threshold trips, propose the swarm split before writing.

### Mechanic
1. State the counts: *"This work touches N files / ~M LOC / K tasks → over the swarm threshold."*
2. `ruflo-swarm:swarm-init` (or `Skill` → `ruflo-swarm:swarm`) with topology: coordinator + architect + coder(s) + reviewer + tester. Native `TeamCreate` fallback only when Ruflo isn't present (verify per 7a).
3. Split the Phase 3 task list along **dependency boundaries** — coherent slices (one subsystem / one feature vertical / one layer), 5–8 files max per agent.
4. `ruflo-swarm:watch` for live observability. Re-aggregate before reporting completion.

### Forbidden
- "Just start" on a large task and split later — context decay already happened.
- Routing a large task through a single `Agent` call.
- Silently skipping the count when SDLC is bypassed — speak the count out loud.

### Below threshold
Proceed solo or with a single sub-agent. Rule 7 (>5 files → parallel sub-agents for context relief) still applies as the lower-bar default.
<!-- cappy:end:05c-mandatory-swarm-threshold -->
