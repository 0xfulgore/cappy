<!-- cappy:section:21-prefer-autopilot-loop -->
## Prefer Autopilot Loop (over direct sub-agent dispatch)

28. **WHEN AUTOPILOT IS ENABLED, PREFER THE AUTOPILOT-LOOP MECHANISM**: When autopilot is active and you're about to dispatch multi-agent work, the default is the `ruflo-autopilot:autopilot-loop` skill (`ScheduleWakeup`-paced iteration with state tracking). Direct parallel sub-agent dispatch is permitted ONLY when sub-agents have zero inter-dependencies, and you must state the no-dependency justification in the same turn.

    ### Default: autopilot-loop
    Use the loop when ALL hold:
    - Autopilot is enabled (`mcp__ruflo__autopilot_status.enabled == true`).
    - Work is multi-step (>1 sub-agent or >1 iteration).
    - Sub-agents have inter-dependencies (any agent's input depends on another's output, or order affects correctness).

    ### Exception: parallel dispatch when fully independent
    Each agent's input is fixed at dispatch time, output goes to a distinct destination, no agent reads another's output, and reordering/rerunning any agent doesn't change the final result.

    ### Required justification (parallel dispatch only)
    State the independence property in one sentence, e.g.:
    - *"10 audit agents — each writes its own `/tmp/cappy-audit/NN-*.md`, no cross-reads."*
    - *"5 module migration agents — each touches its own `modules/<name>/` subtree, manifest fixed at dispatch."*

    Insufficient: "faster", "probably won't conflict", "user wants it now".

    ### Below threshold
    Single-agent / single-step work: dispatch normally; this rule is inactive.
<!-- cappy:end:21-prefer-autopilot-loop -->
