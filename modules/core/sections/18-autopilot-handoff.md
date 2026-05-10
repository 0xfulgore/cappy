<!-- cappy:section:18-autopilot-handoff -->
## Autopilot Handoff

25. **OFFER OR ENABLE AUTOPILOT WHEN AUTONOMOUS-WORTHY WORK IS IN FLIGHT**: Multi-step / multi-ticket work proceeds without per-turn prompting via autopilot. Surface it (or, when prefs allow, enable it directly) on any of the triggers below. Do not silently spawn a swarm or work through a multi-ticket plan without engaging this rule.

    ### Triggers (any one)
    1. Rule 7b trips (>10 files / >300 LOC / >8 tasks / >2h / >2 subsystems).
    2. 2+ tickets in active state.
    3. SDLC Phase 4 begins (rule 15).
    4. **Session resume with a plan already in flight** — evaluate at the **start of your first assistant turn**, not later.

    ### Detection
    Autopilot is available iff: `/autopilot` is callable, `mcp__ruflo__autopilot_*` tools are loaded (verify via `ToolSearch +autopilot`), and the `ruflo-autopilot:autopilot-coordinator` agent or `ruflo-autopilot:autopilot-loop` skill is listed.

    ### Preference resolution — `~/.cappy/ruflo-preferences.json`
    ```json
    {
      "_version": 1,
      "autopilot_offer_mode": "always" | "ask" | "never",
      "autopilot_post_completion": "auto_disable" | "stay_paused" | "stay_on"
    }
    ```
    - `always` + autopilot available → enable immediately, one-line notice, proceed.
    - `ask` → use `AskUserQuestion` (see options below); persist the answer.
    - `never` → proceed without autopilot.
    - Missing file or stale `_version` → treat as `ask`, write current `_version` after answering.

    ### MCP not connected under `always` prefs
    If prefs are `always` but autopilot MCP tools are not present, **surface as a blocker** (do NOT silently fall through to `never`). Offer two paths: reconnect (`claude mcp list`, restart Claude Code if `ruflo` missing) or proceed without autopilot for this session. Never fabricate autopilot tool calls. Under `ask`/`never`, MCP-not-connected is a non-event.

    ### Question (when mode = `ask`)
    Phrase the trigger ("This task hits the swarm threshold (12 files / ~450 LOC)") then offer:
    1. *Yes, this batch only* — auto-disable when the trigger clears.
    2. *Yes, always* — saves `offer_mode: "always"`.
    3. *No, dispatch synchronously* — saves nothing.
    4. *Never offer* — only include after the user has declined twice in this session; saves `offer_mode: "never"`.

    ### Post-completion
    Read `autopilot_post_completion`:
    - `auto_disable` (default) → `/autopilot disable` after trigger clears + one-line summary.
    - `stay_paused` → leave enabled, no new loop until next trigger.
    - `stay_on` → leave fully active, warn the user once at run start.

    ### Forbidden
    - Enabling autopilot silently unless `always` AND MCP connected.
    - Silently skipping under `always` when MCP is missing.
    - Asking on every trigger after the user has answered.
    - Leaving autopilot on after task completion when prefs say `auto_disable`.
    - Waiting for rule 7b's threshold when triggers 2/3/4 already apply (triggers are OR-gated).
<!-- cappy:end:18-autopilot-handoff -->
