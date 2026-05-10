<!-- cappy:section:20-qualifying-questions -->
## Qualifying Questions (capture goal + scope before work)

27. **ASK 2 QUESTIONS BEFORE NON-TRIVIAL WORK**: Before starting work that crosses ANY of the triggers below, you MUST capture the user's success criterion and scope boundary up front via `AskUserQuestion`. The answers feed downstream rules — rule 15 (SDLC PRD), rule 25 (autopilot context), rule 26 (block-on-ambiguity scope drift detection). Without this, the task starts on assumptions rather than alignment.

    ### Triggers
    Fire on **any** of:
    1. **SDLC Phase 1 fires** — non-trivial task per rule 15 (new feature, architectural change, >3 files)
    2. **Autopilot is about to be enabled** — per rule 25, before triggering the autopilot-handoff offer
    3. **Multi-ticket plan in flight** — 2+ tickets / Phase 4 dispatch
    4. **User asks for "an audit", "a review", "a refactor", or any open-ended scope** that doesn't have an obvious deliverable

    ### Skip conditions
    Do NOT fire on:
    - Single-file bug fixes
    - Typo / config tweaks the user described in full
    - User said "just do it", "quick fix", "skip the process"
    - Pure information requests ("what does this code do?", "where is X defined?")
    - Continuing work the user already qualified earlier in the same session

    ### The two questions
    Use `AskUserQuestion` with **a single batch of 2 questions** (not sequential):

    > **Question 1 — Done criterion:**
    > *"How will we know this is done? (e.g., 'tests passing in CI', 'feature visible in browser', 'audit findings landed in code', 'docs accurate against current behavior')"*
    >
    > Header: "Done"
    > Options: provide 2-4 sensible defaults inferred from the user's phrasing, plus "Other" lets them write free-form. The free-form version becomes the success criterion.

    > **Question 2 — Out of scope:**
    > *"Anything explicitly out of scope for this task?"*
    >
    > Header: "Out of scope"
    > Options: "Nothing — full scope as described" / "Only what I named — don't expand" / 1-2 task-specific exclusions you can infer / "Other" for free-form.

    ### Persistence
    The answers persist in **session conversation context** for the duration of the task — no separate file. Reference them explicitly when:
    - Drafting the Phase 2 PRD (rule 15) — the done-criterion is the acceptance criterion
    - Engaging autopilot (rule 25) — the done-criterion becomes the loop-exit reference
    - Detecting mid-task scope drift (rule 26) — work outside the captured scope is a block-trigger, not silent expansion

    ### What NOT to do
    - **Do not ask 4+ questions.** 2 is the contract. Asking more is friction.
    - **Do not ask sequentially.** Use the multi-question batch form of `AskUserQuestion`.
    - **Do not skip the questions then later say "I assumed X."** The whole point of asking is to NOT assume. If you skipped and got it wrong, that's on you.
    - **Do not re-ask within the same task.** Once the answers are captured, reference them. Re-asking signals you didn't track the answers.
    - **Do not ask for tasks below the trigger threshold.** Trivia + clear single-step requests = act per rule 23 (act-don't-ask), not interrogate.

    ### Why this rule exists
    Autonomous and semi-autonomous runs that ship the wrong outcome usually fail at the *start* — the user said "fix the flaky test" but the agent shipped a test that's no longer flaky because it was deleted. A 30-second up-front exchange about "what does done look like?" prevents the entire failure class. Hermes-agent's `/goal` mechanism captures this same insight via a free-form goal string; cappy's version structures it as 2 questions so the answers are usable downstream by rules 15/25/26 without parsing.
<!-- cappy:end:20-qualifying-questions -->
