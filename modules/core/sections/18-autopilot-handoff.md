<!-- cappy:section:18-autopilot-handoff -->
## Autopilot Handoff

25. **OFFER OR ENABLE AUTOPILOT WHEN AUTONOMOUS-WORTHY WORK IS IN FLIGHT**: Autopilot exists to make multi-step / multi-ticket work proceed without per-turn prompting. Surface it (or, when prefs allow, enable it directly) any time the user's work warrants autonomous iteration. Do not silently spawn a swarm or work through a multi-ticket plan without engaging this rule.

    ### Triggers — fire on ANY of the following
    1. **Rule 7b trips** — task crosses the swarm threshold (>10 files / >300 LOC / >8 tasks / >2h / >2 subsystems).
    2. **Multi-ticket plan in flight** — 2+ tickets in active state (Linear "In Progress", kanban "claimed", or in-progress TaskList items where each item is itself a ticket-sized chunk of work).
    3. **SDLC Phase 4 (Implementation) begins** — once the user approves the Phase 3 design (per rule 15, SDLC BY DEFAULT), Phase 4 dispatch is autopilot-eligible by default.
    4. **Session start with a plan already in flight** — if you boot into a session and any of triggers 1–3 already apply (e.g., resuming work on tickets started in a previous session), evaluate this rule at the **start of your first assistant turn**, not later.

    Trigger 4 is the one that catches the case the user expects: *"I told cappy to default to autopilot — why didn't it kick in when I resumed?"* Answer: it must.

    ### Detection — is autopilot actually available?
    Autopilot is **available** when ALL of the following hold in this session:
    - The `/autopilot` slash command is callable (from the `ruflo-autopilot` plugin), AND
    - The autopilot MCP tools are present in the deferred-tools manifest — verify with `ToolSearch` query `+autopilot` and look for `mcp__ruflo__autopilot_*` matches, AND
    - Either the `ruflo-autopilot:autopilot-coordinator` agent type or the `ruflo-autopilot:autopilot-loop` skill is listed.

    If detection fails (plugin enabled but MCP server not connected this session), see "MCP not connected" below — do NOT silently skip.

    ### Preference resolution
    Read user preference from **`~/.cappy/ruflo-preferences.json`** (created by the cappy installer). Schema:

    ```json
    {
      "_version": 1,
      "autopilot_offer_mode": "always" | "ask" | "never",
      "autopilot_post_completion": "auto_disable" | "stay_paused" | "stay_on"
    }
    ```

    Behavior by mode (when autopilot IS available):
    - **`always`** → enable autopilot immediately (`/autopilot enable` or the equivalent MCP call), then proceed with the work. Notify the user in one line: *"Autopilot enabled per saved preference (`offer_mode: always`). Iterating now."*
    - **`ask`** → use `AskUserQuestion` with the three options below. Persist the answer back to the file under the same key.
    - **`never`** → proceed without autopilot. Do not surface the offer.

    If the file is **missing** or `_version` is older than the current schema, treat it as `ask` for this turn. After the user answers, write the file with the current `_version`.

    ### MCP not connected — required handling when prefs=`always`
    If `autopilot_offer_mode == "always"` AND the autopilot MCP tools are NOT present in this session's tool manifest, you MUST surface this as a blocker, not silently skip:

    > *"Autopilot prefs are `always` but the ruflo-autopilot MCP server is not connected in this session. Autonomous loop cannot start. Two paths:*
    > *1. Reconnect: verify with `claude mcp list`, then restart Claude Code if `ruflo` is missing.*
    > *2. Proceed without autopilot for this session: I'll dispatch the work synchronously via sub-agents and you can re-engage autopilot in a fresh session.*
    > *Which?"*

    Forbidden when MCP is missing under `always` prefs:
    - Silently proceeding as if `offer_mode == "never"` — the user explicitly opted out of that.
    - Spending the rest of the session debugging MCP plumbing without confirming with the user that's how they want to spend the time.
    - Inventing or fabricating autopilot tool calls hoping they'll work.

    Under `ask` or `never` prefs, MCP-not-connected is a non-event — proceed without autopilot.

    ### The inline question (when mode is `ask`)
    Use exactly this structure with `AskUserQuestion`:

    > **Question:** "{Trigger summary — e.g., 'This task hits the swarm threshold (12 files / ~450 LOC).' OR '3 tickets are in flight (WAG-119/120/122).'} Run on autopilot so I iterate through this without prompting each turn?"
    >
    > **Options:**
    > 1. *"Yes, this batch only"* — autopilot enabled now, auto-disabled when the trigger condition clears (queue empty / tickets all closed / Phase 4 complete).
    > 2. *"Yes, always for autonomous-worthy work"* — saves `autopilot_offer_mode: "always"` so future triggers skip this prompt.
    > 3. *"No, dispatch synchronously"* — no autopilot loop. Saves nothing (next trigger will ask again).
    >
    > **Optional 4th option** *"Never offer autopilot"* — saves `autopilot_offer_mode: "never"`. Only include this option if the user has previously declined twice in the same session.

    ### Post-completion behavior
    Read `autopilot_post_completion` from the same file:
    - **`auto_disable`** (default) → run `/autopilot disable` immediately after the trigger condition clears. Post a one-line summary: *"Autopilot disabled. {N} tickets shipped / {M} files changed / {K} tests added."*
    - **`stay_paused`** → leave autopilot enabled but don't start a new loop. Next trigger re-engages without re-enabling.
    - **`stay_on`** → leave autopilot fully active. Warn the user once at the start of the run: *"Autopilot remains active after this task completes (`post_completion: stay_on`). Use `/autopilot disable` to stop. Token usage continues otherwise."*

    ### Forbidden shortcuts
    - Do **not** enable autopilot without surfacing it to the user (unless mode is `always` AND MCP is connected).
    - Do **not** silently skip when prefs are `always` and MCP is not connected — that violates explicit user intent. Surface the blocker per "MCP not connected" above.
    - Do **not** ask every turn — once per trigger, persisted thereafter.
    - Do **not** leave autopilot enabled silently after task completion when the saved preference is `auto_disable`.
    - Do **not** invent a 4th "remind me later" option — three options is the contract.
    - Do **not** wait for the swarm threshold (rule 7b) when triggers 2/3/4 already apply. The triggers are OR-gated, not AND-gated.

    ### Why this rule exists
    Cappy installs ruflo-autopilot as part of the default module set, but discoverability is poor — most users never learn `/autopilot enable` exists. Tying autopilot to multiple triggers (swarm threshold, multi-ticket plan, Phase 4 dispatch, session-start-with-plan) surfaces the feature whenever it's actually useful, not just on the narrow swarm-threshold case. The persisted preference means the offer happens *once* per choice, not on every trigger. The MCP-not-connected handling exists because silent fall-through under `always` prefs broke user trust in real-world testing — explicit user intent must be honored or surfaced as a blocker, never quietly ignored.
<!-- cappy:end:18-autopilot-handoff -->
