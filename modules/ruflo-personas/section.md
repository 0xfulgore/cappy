<!-- cappy:section:ruflo-personas -->
## Ruflo Personas — Custom Agent Names

29. **PREFER PERSONA ALIASES OVER CANONICAL RUFLO NAMES**: When you would dispatch to a ruflo agent (`ruflo-core:coder`, `ruflo-swarm:architect`, `ruflo-testgen:tester`, etc.), check `~/.cappy/ruflo-personas.json` first. If a persona is configured for that agent, dispatch through the alias instead.

    ### Detection
    The persona map lives at `~/.cappy/ruflo-personas.json`. Schema:
    ```json
    {
      "_version": 1,
      "personas": {
        "ruflo-core:coder": { "name": "Spock", "alias_slug": "spock", ... }
      }
    }
    ```
    For each ruflo agent you might dispatch to, look up the entry by full agent ID (e.g. `ruflo-core:coder`). If the entry exists, use `alias_slug` as the `subagent_type` (so `subagent_type: "spock"`, not `"ruflo-core:coder"`). The alias agent file at `~/.claude/agents/<slug>.md` is a self-contained fork with the same tools + behavior as the underlying ruflo agent, plus a persona overlay (name, pronouns, MBTI, voice).

    ### When no persona is configured
    If `~/.cappy/ruflo-personas.json` doesn't exist, or the specific agent ID has no entry, dispatch to the canonical `ruflo-*` name as usual. No persona → no change in behavior.

    ### Forbidden
    - Mixing persona and canonical names in the same conversation (pick one consistently per agent invocation).
    - Revealing the underlying ruflo identity in agent output ("I am ruflo-core:coder running as Spock") — the persona IS the identity for that run.
    - Calling personas by their canonical ruflo name when the user has named them — that's the whole point of the system.
    - Hard-coding persona names — always read the current map, since users can rename/reset at any time.

    ### Scope boundary: personas vs. ruflo internal orchestration
    Personas are a **presentation layer for direct user-facing dispatch only**. When ruflo's own coordinator / autopilot / swarm agents orchestrate work internally (i.e. one ruflo agent spawning another ruflo agent), they MUST continue to use canonical `ruflo-*:*` agent IDs — do NOT rewrite their internal dispatch targets to aliases. The persona-overlay file is a user-scoped alias, not a plugin override; ruflo's MCP tools (`mcp__ruflo__agent_spawn`, `swarm_init`, `autopilot_enable`, etc.) reference canonical names and would not resolve a persona slug.

    Rule of thumb:
    - **Top-level Claude → first sub-agent dispatch**: prefer the alias when a persona is configured.
    - **Ruflo coordinator → its workers**: stay canonical. The coordinator's system prompt is authoritative for its own dispatch decisions.
    - **Anywhere ruflo MCP tools take an `agent_type` / `subagent_type` arg**: pass the canonical name only.

    This boundary keeps personas as additive UX without breaking ruflo's swarm, autopilot, or coordinator behavior.

    ### How users manage personas
    - Initial setup: `bash ~/.cappy/repo/modules/ruflo-personas/setup-ruflo-personas.sh`
    - Re-pick all: `... setup-ruflo-personas.sh --reset`
    - Re-render after ruflo upgrade: `... setup-ruflo-personas.sh --sync`

    A SessionStart hook detects ruflo upgrades and re-renders alias files silently; only structural drift (new agent added, agent removed) surfaces a one-line notice telling the user to run `--sync`.
