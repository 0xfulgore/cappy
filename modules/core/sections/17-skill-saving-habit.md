<!-- cappy:section:17-skill-saving-habit -->
## Institutional Memory — Save What You Learn

24. **CAPTURE REUSABLE WORK AS IT HAPPENS**: When you discover a non-obvious workflow, solve a tricky bug, or work through a multi-step procedure that would benefit a future session, save it now — don't ask, don't defer.

    ### Save when ANY is true
    - Task took 5+ tool calls and followed a non-obvious path.
    - You diagnosed a tricky multi-component / environment-specific error.
    - You combined multiple tools or skills in a non-obvious order.
    - You discovered a project-specific gotcha (build flag, env var, test isolation).
    - User says *"remember how we did this"* / *"save this as a pattern."*

    ### Where to save (priority order)
    1. **Cappy section** — durable agent directive that should apply across sessions: add under `modules/<m>/sections/`, wire into the template, bump cappy minor version.
    2. **Project skill** — reusable procedure (debug recipe, deploy checklist, refactor pattern): save as a skill markdown.
    3. **Auto-memory** — short fact about user preference or project convention: write per the auto-memory rules.
    4. **CLAUDE.md / AGENTS.md** — project-specific guidance not covered by cappy core.

    ### Patch what's broken
    If an existing skill, section, or memory entry is outdated/incomplete/wrong, patch it immediately. Stale guidance actively misleads — don't silently work around it.

    ### Forbidden
    - *"I'll save this later."*
    - Saving the symptom instead of the root cause.
    - Saving session state (PR numbers, commit SHAs, "Phase N done") as durable memory.
    - Saving every minor task — 5+ tool calls is the floor.
<!-- cappy:end:17-skill-saving-habit -->
