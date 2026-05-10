# Ruflo Quickstart

Cappy installs the Ruflo agent platform — marketplace, 8 plugins, and the Ruflo MCP server. Most of the time you do not need to invoke Ruflo manually: when a task is large enough to warrant a swarm, Claude offers autopilot inline (governed by your prefs in `~/.cappy/ruflo-preferences.json`).

This file is the reference for the situations where you *do* want to drive Ruflo by hand.

## Slash commands

| Command | What it does |
|---|---|
| `/autopilot enable` | Turn on autonomous loop-driven task completion. Claude works through the queue iteratively, scheduling its own next iterations via `ScheduleWakeup`. |
| `/autopilot disable` | Stop the loop. Use this if a run goes sideways or you need to intervene. |
| `/autopilot config --max-iterations 50 --timeout 30` | Set ceilings on iteration count and per-iteration timeout (minutes). |
| `/autopilot reset` | Reset the iteration counter and restart the timer for the current task. |
| `/autopilot learn` | Mine completed tasks for success patterns; stored in AgentDB for future prediction. |
| `/autopilot history KEYWORD` | Search past completion episodes for a keyword. |
| `/autopilot-status` | One-line progress summary — current task, iteration count, time elapsed. |
| `/swarm init` | Manually initialize a multi-agent swarm. Cappy's directive #7b normally triggers this for you on large tasks. |
| `/swarm status` | Active swarm health + agent activity. |
| `/swarm health` | Diagnostic check — agent reachability, MCP connection, AgentDB integrity. |
| `/swarm shutdown` | Stop the active swarm. |
| `/watch` | Live event stream from the active swarm — see agent decisions, tool calls, and results in real time. |

## Preferences

Captured at install time, stored at `~/.cappy/ruflo-preferences.json`:

```json
{
  "_version": 1,
  "autopilot_offer_mode": "ask",
  "autopilot_post_completion": "auto_disable"
}
```

| Key | Values | Effect |
|---|---|---|
| `autopilot_offer_mode` | `always` / `ask` / `never` | Whether Claude offers autopilot when a task crosses the swarm threshold (>10 files / >300 LOC / >8 tasks / >2h / >2 subsystems). |
| `autopilot_post_completion` | `auto_disable` / `stay_paused` / `stay_on` | What happens when autopilot finishes a task. `auto_disable` is the safe default — predictable token usage. |

To change prefs after install, either edit the file directly or re-run `bash ~/Development/cappy/modules/ruflo/setup-ruflo.sh` (it detects the existing prefs and re-prompts only if the schema version has bumped).

## When does Claude offer autopilot automatically?

Per cappy core directive #25 (autopilot-handoff), Claude offers autopilot when **any** of these is true for the current task:

- More than 10 files will be touched
- More than 300 LOC of net new or changed code
- More than 8 numbered tasks in the Phase 3 design
- More than 2 hours of focused work estimated
- More than 2 distinct subsystems (e.g., backend + frontend + migrations)

The offer respects your `autopilot_offer_mode` pref:
- `always` → enables autopilot, notifies you, starts the swarm.
- `ask` → uses `AskUserQuestion` to give you 3 options: this task only / always for large tasks / no, just swarm.
- `never` → spawns the swarm without autopilot, no prompt.

## How autonomous mode behaves (relevant directives)

When autopilot is enabled, Claude operates under additional rules from cappy core:
- **Directive #22** (tool-use enforcement) — never end a turn with a promise; execute now.
- **Directive #23** (act-don't-ask) — pick the obvious default in interactive mode.
- **Directive #26** (block-on-ambiguity) — in autonomous mode, block instead of guess on real decisions (missing creds, UX choices, destructive actions on shared state).

These three rules together are the difference between autonomous mode that ships work and autonomous mode that produces silently-wrong output.

## Verifying install

```bash
claude plugin list                     # all 8 ruflo-* plugins listed
claude mcp list                        # 'ruflo' MCP server registered
cat ~/.cappy/ruflo-preferences.json    # prefs file present + valid
```

## Troubleshooting

**`/autopilot enable` not recognized** → the `ruflo-autopilot` plugin isn't installed. Run `claude plugin install ruflo-autopilot@ruflo`.

**Claude never offers autopilot on big tasks** → check `autopilot_offer_mode` is not `"never"`. If it's `"ask"` and you're still not getting prompts, the rule fires only when *all* swarm-threshold criteria are evaluated — small multi-file tasks (5–10 files, <300 LOC) intentionally don't trigger it.

**Autopilot drains tokens after a task completes** → set `autopilot_post_completion: "auto_disable"` (the default). If you previously chose `stay_on`, re-run setup-ruflo.sh and pick option `a` for question 2.

**Need to interrupt a running autopilot loop** → `/autopilot disable` immediately stops the loop. The current iteration finishes; no new iterations are scheduled.
