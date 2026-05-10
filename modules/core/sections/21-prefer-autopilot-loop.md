<!-- cappy:section:21-prefer-autopilot-loop -->
## Prefer Autopilot Loop (over direct sub-agent dispatch)

28. **WHEN AUTOPILOT IS ENABLED, PREFER THE AUTOPILOT-LOOP MECHANISM**: When autopilot is active (per rule 25 detection) and you're about to dispatch multi-agent work, the **default** path is the `ruflo-autopilot:autopilot-loop` skill (`ScheduleWakeup`-paced iteration with state tracking). Direct parallel sub-agent dispatch is permitted ONLY when sub-agents have zero inter-dependencies, AND you must articulate the no-dependency justification in the same turn.

    ### The two mechanisms
    - **Autopilot-loop pattern** (`ruflo-autopilot:autopilot-loop` skill): one iteration per `ScheduleWakeup` cycle (270s default), state tracked in autopilot MCP, queue-empty terminates the loop. Cache-warm. Observable via `autopilot_status`. Slow but auditable.
    - **Direct parallel dispatch** (multiple `Agent` calls in one message with `run_in_background: true`): N concurrent sub-agents, each in its own context. Fast. Bypasses autopilot's iteration tracking entirely.

    ### Default: autopilot-loop
    When **all** of the following hold, you MUST use the autopilot-loop skill, not direct parallel dispatch:
    - Autopilot is enabled in this session (`mcp__ruflo__autopilot_status` reports `enabled: true`)
    - The work is multi-step (>1 sub-agent or >1 iteration)
    - Sub-agents would have inter-dependencies (any agent's input depends on another agent's output, OR the order of execution affects correctness)

    ### Exception: parallel dispatch when independent
    Direct parallel sub-agent dispatch is allowed ONLY when sub-agents are fully independent:
    - Each agent's input is fixed at dispatch time (not produced by another agent)
    - Each agent's output goes to a distinct destination (own file, own report, own subsystem)
    - No agent reads or depends on another agent's output to do its work
    - Reordering or rerunning any agent does not change the final result

    ### Required justification
    When choosing parallel dispatch over loop, you MUST state the no-dependency justification in the same turn — one sentence naming the specific independence property. Examples of valid justifications:

    - *"Dispatching 10 audit agents in parallel — each writes its own /tmp/cappy-audit/NN-*.md report; no agent reads another's output."*
    - *"5 module migration agents in parallel — each touches its own modules/<name>/ subtree; the manifest format is fixed at dispatch time, no cross-module reads."*
    - *"3 fix agents in parallel — Fix-A on lib/, Fix-B on docs/, Fix-C on tests/; non-overlapping file sets."*

    Examples of INSUFFICIENT justifications (use the loop instead):
    - *"Faster this way."* — speed alone is not a reason; loop forces observability for a reason.
    - *"They probably won't conflict."* — "probably" means dependencies exist; loop them.
    - *"User wants it now."* — user can disable autopilot if loop pacing is unacceptable.

    ### Why this rule exists
    Autopilot's value is in `autopilot_status` / `autopilot_progress` observability, the queue-empty heuristic, learned-pattern prediction, and `ScheduleWakeup` cache-warm pacing. Direct parallel dispatch bypasses ALL of those — autopilot's iteration counter stays at 0, the queue isn't tracked, no learning happens. If the user enabled autopilot, they're paying for that observability and pacing. Bypassing it for "speed" defeats the user's explicit choice.

    The audit cycle that produced cappy 2.2.3+ shipped via parallel dispatch (10 audit agents → reports → 4 + 3 + 3 fix agents → 3 patch releases) — that was the right call because each batch was independent. But the autopilot iteration counter stayed at 0 the entire time, meaning the autopilot machinery was effectively unused. **That's the trap this rule prevents going forward.**

    ### Below threshold
    For single-agent or single-step work, neither mechanism applies — just dispatch normally. This rule activates only when multi-agent orchestration is in play AND autopilot is enabled.
<!-- cappy:end:21-prefer-autopilot-loop -->
