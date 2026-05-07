<!-- cappy:section:05c-mandatory-swarm-threshold -->
7b. **MANDATORY SWARM SPLIT FOR LARGE BODIES OF WORK**: A task qualifies as "large" and MUST be executed via a Ruflo swarm (or `TeamCreate` fallback per 7a) — not by you alone, not by a single sub-agent — when **any** of the following thresholds is tripped:

- **>10 files** will be touched (creates, edits, or deletes)
- **>300 LOC** of net new or changed code is estimated
- **>8 numbered tasks** in the Phase 3 design
- **>2 hours** of focused work is estimated
- **>2 distinct subsystems** are touched (e.g., backend + frontend + migrations)

### When to evaluate
- **At the end of Phase 3 (Technical Design)** — before any Phase 4 implementation begins. The numbered task list, file count, and architecture surface from Phase 3 give you the data to count thresholds against.
- **If the task skipped SDLC** (user said "just do it"): evaluate before your first code-writing turn. If a threshold is tripped, stop and propose the swarm split before writing code.

### Mechanic
1. State the counts explicitly: "This work touches N files / ~M LOC / K tasks → over the swarm threshold."
2. Initialize the swarm with `ruflo-swarm:swarm-init` (or `Skill` tool with `ruflo-swarm:swarm`) using a topology that matches the task — coordinator + architect + coder(s) + reviewer + tester. Fall back to native `TeamCreate` only if Ruflo is not present in this session (verify per rule 7a).
3. Split the Phase 3 task list across agents along **dependency boundaries**, not arbitrary chunks. Each agent gets a coherent slice (one subsystem, one feature vertical, or one layer) and 5–8 files max.
4. Use `ruflo-swarm:watch` (or equivalent) for live observability. Re-aggregate results before reporting completion.

### Forbidden shortcuts
- Do **not** "just start" on a large task and split later — context decay will already have happened.
- Do **not** route a large task through a single `Agent` call. Sub-agents have their own context but no anti-drift coordination.
- Do **not** silently skip the count when SDLC is bypassed. Speak the count out loud.

### Below threshold
If none of the thresholds trip, you may proceed solo or with a single sub-agent (per rule 7's parallel-read pattern). Rule 7 (>5 files → parallel sub-agents for context relief) still applies as the lower-bar default.
<!-- cappy:end:05c-mandatory-swarm-threshold -->
