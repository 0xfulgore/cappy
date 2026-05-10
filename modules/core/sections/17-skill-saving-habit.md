<!-- cappy:section:17-skill-saving-habit -->
## Institutional Memory — Save What You Learn

24. **CAPTURE REUSABLE WORK AS IT HAPPENS**: When you discover a non-obvious workflow, solve a tricky bug, or work through a multi-step procedure that would benefit a future session, save it. Don't ask permission — surface the save and do it. Future you (and other agents in this project) will thank present you.

    ### Trigger conditions
    Save the approach when **any** of these is true:
    - The task took **5+ tool calls** to complete and followed a non-obvious path.
    - You fixed an error that was tricky to diagnose (multi-component, deep stack, environment-specific).
    - You worked out a workflow that combines multiple tools or skills in a non-obvious order.
    - You discovered a project-specific gotcha (build flag, env var quirk, test isolation requirement).
    - The user explicitly says *"remember how we did this"* or *"save this as a pattern."*

    ### Where to save (in priority order)
    1. **Cappy section file** — if the lesson is a *durable agent directive* that should apply across all future sessions in this project, add it as a new section under `modules/core/sections/` (or the relevant module's `sections/`) and wire it into the template. Bump the cappy minor version.
    2. **Project skill** — if the lesson is a *reusable procedure* (debugging recipe, deployment checklist, refactor pattern), save it as a skill markdown in the project's skills directory.
    3. **Auto-memory** — if the lesson is a *short fact* about user preference or project convention that should inform future responses but doesn't warrant a full section, write it to memory per the auto-memory rules.
    4. **CLAUDE.md / AGENTS.md** — if the lesson is *project-specific guidance* not covered by cappy core, append a short paragraph to the project's CLAUDE.md.

    ### Patch what's broken, don't just step around it
    When using an existing skill, section, or memory entry and finding it **outdated, incomplete, or wrong**: patch it immediately. Do not silently work around it. Stale guidance is worse than no guidance — it actively misleads.

    ### Forbidden shortcuts
    - *"I'll save this later."* — no, save it now or it never happens.
    - Saving the *symptom* instead of the *root cause* (e.g., "if X breaks, restart Y" when the real lesson is "Y has a stale-cache bug under condition Z").
    - Bloating memory with task progress, PR numbers, commit SHAs, "Phase N done" — those are session state, not durable facts. The auto-memory rules already forbid this; don't repeat it under a "skill" label either.
    - Saving every minor task. The 5+ tool-call threshold is the floor. Trivial single-step tasks don't earn a save.

    ### Why this rule exists
    Every session starts cold unless you leave breadcrumbs. Hermes-agent and other autonomous systems treat skill-saving as a first-class operation — the agent that learns is dramatically more useful than the agent that re-discovers the same lesson every week. Cappy's modules + sections + auto-memory are the persistence surfaces; this rule is the obligation to *use* them.
<!-- cappy:end:17-skill-saving-habit -->
