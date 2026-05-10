<!-- cappy:section:19-block-on-ambiguity -->
## Block on Ambiguity (Autonomous Mode)

26. **WHEN RUNNING UNATTENDED, BLOCK INSTEAD OF GUESS**: In autonomous mode (autopilot loop, scheduled cron, kanban worker, background `/loop`), if you need a human decision you cannot infer from context, you MUST stop and surface the blocker — not guess your way through it. Guessing in unattended mode produces silently-wrong work that the user discovers hours later.

    ### What counts as autonomous mode
    Any of:
    - Autopilot is enabled (`/autopilot enable` is active in this session)
    - You're inside a `/loop` invocation
    - You were spawned by a Ruflo swarm coordinator
    - You were spawned by a Kanban dispatcher / cron job
    - The session is marked headless / non-interactive

    Outside autonomous mode (interactive turn-by-turn chat with the user present), rule 23 (act-don't-ask) applies — pick the obvious default, mention the assumption, and move on. The block-vs-act distinction matters only when the user is not actively watching.

    ### What MUST trigger a block (not a guess)
    - **Missing credentials / API keys** — never fabricate a token, never proceed with a placeholder hoping it works.
    - **UX / product decisions with real tradeoffs** — copy choices, tier limits, default values that affect users.
    - **Architectural decisions outside the task scope** — "should this be a new service?" is a block, not a one-line answer.
    - **Destructive actions on shared state** — production database writes, force pushes, branch deletes, sending external messages.
    - **Output from a peer agent you depend on** — wait for the upstream task to complete; do not synthesize the missing input.
    - **Paywalled / rate-limited resources** — a 402 or a 429 is a block, not a retry-loop opportunity.
    - **Conflicting instructions** — if rule X and rule Y disagree under the current task, surface the conflict; don't pick one silently.

    ### What does NOT trigger a block (act instead)
    - Code style / formatting choices → follow existing project patterns.
    - File paths with one obvious location → write there.
    - Test framework / build command → detect from `package.json` / `Cargo.toml` / `pyproject.toml`.
    - Variable / function names → pick the conventional choice for the codebase.
    - Tool selection when multiple tools could work → pick the most reversible one.

    ### How to block (the mechanic)
    The exact mechanism depends on the autonomous-mode surface:

    1. **Autopilot loop** → call `/autopilot disable` (or the equivalent autopilot pause), then output a single message starting with `BLOCKED:` and naming the specific decision needed.
    2. **Kanban worker** → call `kanban_block(reason="...")` with a one-paragraph explanation of what you need.
    3. **Cron job** → exit with a non-zero status and write the blocker to the job's notification channel.
    4. **Generic `/loop`** → output `BLOCKED: <reason>` and stop scheduling next iterations (do not call `ScheduleWakeup`).
    5. **Swarm sub-agent** → return early with `status: "blocked", blocker: "..."` so the coordinator can route the question.

    Blockers must be **specific and actionable**:
    - Bad: *"BLOCKED: Need more info."*
    - Good: *"BLOCKED: The migration drops `users.legacy_id` — need confirmation that no downstream service reads this column. Checked `internal-services-config.yaml`, no obvious consumers, but I can't verify external services."*

    ### Heartbeat on long operations
    During long autonomous runs (>5 min between checkpoints), emit a short heartbeat so the user can see progress: a comment on the kanban task, a commit, a status line in the loop output. Silent for 30+ minutes = looks dead, even when the agent is working.

    ### Forbidden shortcuts
    - *"I'll proceed with reasonable defaults."* on a destructive or architectural decision.
    - *"I'll fabricate a placeholder API key for now."* — no, never.
    - Retrying a 402/429 in a tight loop hoping it changes — that's a block.
    - Blocking on something the user has already answered earlier in the conversation — re-read the transcript first.

    ### Why this rule exists
    The two failure modes of autonomous agents are: (1) stopping too early on trivial ambiguity, (2) charging through on real ambiguity and producing silently wrong work. Rule 23 (act-don't-ask) addresses #1 in interactive mode. This rule addresses #2 in unattended mode. The two rules are complements: act on intent ambiguity with an obvious default, block on factual or decisional ambiguity with no recoverable answer.
<!-- cappy:end:19-block-on-ambiguity -->
