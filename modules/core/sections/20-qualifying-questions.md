<!-- cappy:section:20-qualifying-questions -->
## Qualifying Questions (capture goal + scope before work)

27. **ASK 2 QUESTIONS BEFORE NON-TRIVIAL WORK**: Before starting work that crosses any of the triggers below, capture the user's success criterion and scope boundary up front via `AskUserQuestion`. The answers feed rules 15 (PRD), 25 (autopilot), and 26 (scope-drift block detection).

    ### Triggers (any one)
    1. SDLC Phase 1 fires (non-trivial per rule 15: new feature, architectural change, >3 files).
    2. Autopilot is about to be enabled (rule 25).
    3. Multi-ticket plan in flight (2+ tickets / Phase 4 dispatch).
    4. User asks for an "audit", "review", "refactor", or any open-ended scope without an obvious deliverable.

    ### Skip
    Single-file bug fixes, typo/config tweaks fully described, "just do it"/"quick fix"/"skip the process", pure information requests, or work the user already qualified earlier in this session.

    ### The two questions (single batch via `AskUserQuestion`, not sequential)
    1. **Done criterion** — header `"Done"`. *"How will we know this is done?"* Provide 2–4 sensible defaults inferred from the user's phrasing; "Other" allows free-form. The answer becomes the success criterion.
    2. **Out of scope** — header `"Out of scope"`. *"Anything explicitly out of scope?"* Options: *Nothing — full scope* / *Only what I named — don't expand* / 1–2 task-specific exclusions / *Other*.

    ### Persistence
    Answers live in session conversation context — no separate file. Reference them when drafting the Phase 2 PRD (acceptance criterion = done criterion), engaging autopilot (loop-exit reference), and detecting scope drift (work outside captured scope is a block-trigger).

    ### Forbidden
    - Asking 4+ questions; 2 is the contract.
    - Asking sequentially instead of one batch.
    - Skipping the questions then later saying "I assumed X".
    - Re-asking after answers are captured.
    - Asking on tasks below the trigger threshold (use rule 23 instead).
<!-- cappy:end:20-qualifying-questions -->
