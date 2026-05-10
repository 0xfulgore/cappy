<!-- cappy:section:18-autopilot-handoff -->
## Autopilot Handoff (when rule 7b/5c trips)

25. **OFFER AUTOPILOT WHEN A SWARM IS REQUIRED**: When rule 7b ("MANDATORY SWARM SPLIT") triggers, you MUST also surface autopilot as an option to the user — large tasks are exactly the situations where autonomous loop-driven completion pays off. Do not silently spawn the swarm without offering. Do not nag the user every time once they've answered.

    ### Detection
    Autopilot is **available** if any of the following are present in this session:
    - The `/autopilot` slash command (from `ruflo-autopilot` plugin)
    - The `ruflo-autopilot:autopilot` skill
    - The `ruflo-autopilot:autopilot-coordinator` agent type
    - Any `mcp__ruflo*` tool with "autopilot" in its name

    If autopilot is NOT available, skip this rule entirely — proceed with the swarm per rule 7b.

    ### Preference resolution
    Read user preference from **`~/.cappy/ruflo-preferences.json`** (created by the cappy installer). Schema:

    ```json
    {
      "_version": 1,
      "autopilot_offer_mode": "always" | "ask" | "never",
      "autopilot_post_completion": "auto_disable" | "stay_paused" | "stay_on"
    }
    ```

    Behavior by mode:
    - **`always`** → enable autopilot immediately (`/autopilot enable`), then init the swarm. Notify the user in one line: *"Autopilot enabled per saved preference. Run starts now."*
    - **`ask`** → use `AskUserQuestion` with the three options below. Persist the answer back to the file under the same key.
    - **`never`** → skip the offer entirely. Init the swarm without autopilot.

    If the file is **missing** or `_version` is older than the current schema, treat it as `ask` for this turn. After the user answers, write the file with the current `_version`.

    ### The inline question (when mode is `ask`)
    Use exactly this structure with `AskUserQuestion`:

    > **Question:** "This task hits the swarm threshold ({N} files / ~{M} LOC / {K} subsystems). Run on autopilot so I work through it iteratively without you needing to prompt each turn?"
    >
    > **Options:**
    > 1. *"Yes, this task only"* — autopilot enabled now, auto-disabled when this task completes.
    > 2. *"Yes, always for large tasks"* — saves `autopilot_offer_mode: "always"` so future large tasks skip this prompt.
    > 3. *"No, just run the swarm"* — no autopilot loop. Saves nothing (next large task will ask again).
    >
    > **Optional 4th option** *"Never offer autopilot"* — saves `autopilot_offer_mode: "never"`. Only include this option if the user has previously declined twice in the same session.

    ### Post-completion behavior
    Read `autopilot_post_completion` from the same file:
    - **`auto_disable`** (default) → run `/autopilot disable` immediately after the swarm reports complete. Post a one-line summary: *"Autopilot disabled. Task complete: {summary}."*
    - **`stay_paused`** → leave autopilot enabled but don't start a new loop. Next large task re-engages without re-enabling.
    - **`stay_on`** → leave autopilot fully active. Warn the user once: *"Autopilot remains active. Token usage continues until you `/autopilot disable`."*

    ### Forbidden shortcuts
    - Do **not** enable autopilot without surfacing it to the user (unless mode is `always`).
    - Do **not** ask every turn — once per task, persisted thereafter.
    - Do **not** leave autopilot enabled silently after task completion when the saved preference is `auto_disable`.
    - Do **not** invent a 4th "remind me later" option — three options is the contract.
    - Do **not** assume autopilot is available. Verify per the detection list above.

    ### Why this rule exists
    Cappy installs ruflo-autopilot as part of the default module set, but discoverability is poor — most users never learn `/autopilot enable` exists. Tying the offer to the swarm trigger surfaces the feature exactly when it's most valuable, with zero need for users to read docs. The persisted preference means the offer happens *once* per choice, not on every large task.
<!-- cappy:end:18-autopilot-handoff -->
