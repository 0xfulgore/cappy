<!-- cappy:section:19-block-on-ambiguity -->
## Block on Ambiguity (Autonomous Mode)

26. **WHEN RUNNING UNATTENDED, BLOCK INSTEAD OF GUESS**: In autonomous mode, if you need a human decision you cannot infer from context, stop and surface the blocker — do not guess. Guessing produces silently-wrong work the user discovers hours later.

    ### What counts as autonomous mode
    Autopilot enabled, inside a `/loop`, spawned by a swarm coordinator, spawned by a kanban dispatcher / cron, or session marked headless. Outside autonomous mode, rule 23 (act-don't-ask) applies instead.

    ### MUST trigger a block
    - Missing credentials / API keys — never fabricate, never proceed with a placeholder.
    - UX / product decisions with real tradeoffs (copy, tier limits, default values).
    - Architectural decisions outside the task scope.
    - Destructive actions on shared state (prod writes, force pushes, branch deletes, external messages).
    - Output from a peer agent you depend on — wait, don't synthesize.
    - Paywalled / rate-limited resources (402, 429) — block, don't tight-loop retry.
    - Conflicting instructions between rules under the current task.

    ### Does NOT trigger a block — act instead
    Code style, file paths with one obvious location, test/build command (detect from manifest), variable names, tool selection (pick most reversible).

    ### How to block
    - **Autopilot loop** → `/autopilot disable` (or pause), then output a message starting with `BLOCKED:` naming the specific decision.
    - **Kanban worker** → `kanban_block(reason="...")`.
    - **Cron** → exit non-zero, write blocker to the job's notification channel.
    - **Generic `/loop`** → output `BLOCKED: <reason>`, do NOT call `ScheduleWakeup`.
    - **Swarm sub-agent** → return early with `status: "blocked", blocker: "..."`.

    Blockers must be specific and actionable. Bad: *"Need more info."* Good: *"BLOCKED: migration drops `users.legacy_id` — need confirmation no downstream service reads it. Checked `internal-services-config.yaml`, no consumers there, can't verify external."*

    ### Heartbeat
    During long autonomous runs, emit a checkpoint (kanban comment, commit, status line) at least every 5–10 min. Silent for 30+ min looks dead.

    ### Forbidden
    - *"I'll proceed with reasonable defaults"* on a destructive or architectural decision.
    - Fabricating placeholder credentials.
    - Blocking on something the user already answered earlier — re-read the transcript first.
<!-- cappy:end:19-block-on-ambiguity -->
