<!-- cappy:section:05d-ruflo-opus-override -->
7c. **RUFLO SUB-AGENTS DEFAULT TO SONNET — OVERRIDE TO OPUS**: Every plugin agent under `ruflo-*` has `model: sonnet` hardcoded in its frontmatter (verified 2026-05-12: 24 occurrences across `~/.claude/plugins/marketplaces/ruflo/plugins/*/agents/`). When you dispatch via `Agent({subagent_type: "ruflo-*:..."})` without passing `model:`, the sub-agent runs on Sonnet (200K context) regardless of the parent's model. This is the documented Agent tool resolution order: Agent-call `model:` > agent-file frontmatter > parent inheritance — the frontmatter wins when you omit `model:`.

This caused 4 of 5 NIT-64 coder sub-agents (2026-05-12) to bail mid-Write on existing-file rewrites — Sonnet's budget exhausted when staging a >300 LOC `Write` against a freshly-`Read` file. The 5th agent succeeded only because its prompt naturally drove many small Edits rather than one big Write.

### Default: pass `model: "opus"` on every ruflo-* Agent dispatch

```
Agent({
  subagent_type: "ruflo-core:coder",
  model: "opus",
  prompt: "...",
})
```

Applies to all of `ruflo-core:*`, `ruflo-swarm:*`, `ruflo-autopilot:*`, `ruflo-testgen:*`, `ruflo-docs:*`, `ruflo-rag-memory:*`, `ruflo-security-audit:*`. The frontmatter is bypassed per Agent tool spec.

### When Sonnet is acceptable

State the reason in the same turn when you choose Sonnet. Acceptable cases:

- **Append-only work** — creating new files, no large in-place rewrites (e.g., new test file, new helper module).
- **Pure read/search work** — `ruflo-core:researcher` doing grep/find with no file writes.
- **Known-cheap pattern you've tested on Sonnet without bails** — cite the prior verification.

### Forbidden

- Dispatching a `ruflo-*` agent for an existing-file rewrite without `model: "opus"`.
- Assuming model inherits from parent — it does not when the agent file specifies one.
- Spawning ≥3 parallel `ruflo-core:coder` agents on existing-file rewrites without `model: "opus"`. The bail-cascade is the failure mode.

### Verification before claiming a ruflo sub-agent succeeded

Per `feedback_subagent_big_writes.md`: a "completed" notification with a mid-thought summary text (e.g. *"Now I'll do a single Write…"*) is a bail, not a completion. Always verify via `git log --oneline origin/main..HEAD` and `gh pr view` before trusting the status. Same rule applies regardless of model — Opus reduces bail rate, doesn't eliminate it.
<!-- cappy:end:05d-ruflo-opus-override -->
