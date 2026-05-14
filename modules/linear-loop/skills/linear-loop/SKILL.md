---
name: linear-loop
description: Persistent loop that monitors Linear — works tickets assigned to you, reschedules blocked ones, picks up eligible unassigned tickets (with your OK), and runs a sign-off gap-check on In Review / Done tickets. Per-project, cross-session.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, Task, TaskCreate, TaskList, TaskUpdate, AskUserQuestion, CronCreate, CronList, CronDelete, ScheduleWakeup, mcp__linear
triggers:
  - linear loop
  - linear-loop
  - monitor linear
  - work my linear tickets
  - linear ticket loop
  - keep working linear
---

# Linear Loop

A persistent, per-project loop that monitors Linear and acts on it: works tickets
assigned to you, reschedules blocked ones, picks up eligible unassigned tickets
(after asking you), and runs an independent sign-off gap-check on tickets in
*In Review* / *Done*.

It runs **cross-session** — registered as a per-project cron job — and uses
short in-session bursts to actually do the work.

## Usage

```
/linear-loop                  # run one monitor cycle now, self-pace in-session
/linear-loop 30m              # register a per-project cron job, cycle every 30m
/linear-loop 4h               # cycle every 4 hours
/linear-loop stop             # remove this project's linear-loop cron job
/linear-loop status           # show this project's loop state + open tickets
```

`<interval>` accepts `30m`, `1h`, `4h`, `1d`. With no interval, the loop runs
one cycle and self-paces with `ScheduleWakeup` for the rest of the session only.
With an interval, it registers a cron job so monitoring survives session exit.

## Preflight — run at the start of every cycle

1. **Verify the Linear MCP is connected.** Use the `mcp__linear__*` tools
   available in your session. If the Linear MCP is **not** connected, stop
   immediately with a clear message — *never fabricate ticket IDs, statuses, or
   transitions* (CLAUDE.md rule 6a). This is a hard stop, not a guess.
2. **Identify the current user** via the Linear MCP (the authenticated viewer).
3. **Resolve project scope.** Compute the per-project slug (see *Per-project
   state*), load `~/.cappy/linear-loop/<slug>.json` if it exists. On first run,
   determine the Linear team/project this repo maps to — infer from existing
   ticket references in git history or ask the user once, then persist it.
4. **Load loop driver** — decide ruflo-autopilot vs native (see *Loop driver*).

## The monitor cycle

Run these steps in order. Each step is independent — a failure in one does not
skip the rest; surface the failure and continue.

### 1. Work assigned tickets
- Query issues **assigned to the current user** in the project scope that are
  not in a terminal state and not currently *Blocked*.
- Order by Linear priority, then by staleness (oldest update first).
- Take the top ticket. Claim it per CLAUDE.md rule 6a: assign to self (already
  true here) and move to *In Progress* before any code.
- Work it through the SDLC. For multi-file work, dispatch sub-agents per the
  CLAUDE.md swarm rules. Heartbeat: post a Linear comment or commit every
  5–10 min on long runs.
- On completion: run the Definition-of-Done gates (rule 14), move the ticket to
  the project's terminal status (rule 6a — ask once which status, then reuse it),
  and attach the PR / branch / commit URL as a comment.

### 2. Handle a blocker
- If the ticket you are working hits a blocker you cannot resolve (missing
  creds, a product/UX decision, a peer dependency, a destructive action on
  shared state — CLAUDE.md rule 26):
  - Move the ticket to *Blocked*.
  - Post the specific, actionable blocker as a Linear comment (bad: "need more
    info"; good: names the exact decision and what you already checked).
  - Record `{ "blocked_at": <now>, "recheck_at": <now + blocked_recheck_hours> }`
    in `blocked_tickets` in the state file. Default `blocked_recheck_hours` is 4.

### 3. Recheck blocked tickets
- For each entry in `blocked_tickets` whose `recheck_at` has passed: re-read the
  ticket. If the blocker is resolved (a human answered the comment, creds
  landed, the dependency shipped), move it back to *In Progress* and feed it
  into step 1 on the next cycle. If still blocked, push `recheck_at` forward by
  `blocked_recheck_hours`.

### 4. Scan unassigned tickets for pickup
- Query **unassigned** issues in the project scope that are not in a terminal
  state.
- For each, apply the **pickup heuristic** (below). If eligible, use
  `AskUserQuestion` to ask whether to pick it up:
  - **Yes** → assign it to the current user, move to *In Progress*, work it
    (step 1 flow).
  - **No** → add the ticket ID to `skipped_this_run` in the state file; do not
    ask about it again this cycle.
- Never self-assign an unassigned ticket without asking first.

### 5. Review / sign-off pass
- Query issues in *In Review* and *Done*. For each, see *Review / sign-off pass*.

### 6. Schedule the next cycle
- See *Loop driver*. Persist `last_iteration_at` to the state file.

## Unassigned pickup heuristic

An unassigned ticket is **eligible for pickup** only when **all** hold:

- It has **no assignee**.
- Its **parent issue** (if any) is unassigned, or assigned to the current user.
- **No sibling** under the same parent is currently *In Progress* (or any active
  working state) assigned to **someone else**.
- It is **not** in `skipped_this_run`.

The intent: do not poach work that is part of a ticket tree another person is
actively driving. When a ticket is part of someone else's in-flight tree, leave
it. When in doubt about eligibility, treat it as **not** eligible and skip it —
do not ask, do not pick up.

## Review / sign-off pass

For each ticket in *In Review* or *Done*:

1. **Check for an explicit human sign-off first.** If a person (not this loop,
   not an agent) has explicitly signed off — a comment like "approved", "code is
   fine", "LGTM", "ship it", or a human-set approved/merged state — the ticket
   is **hands-off**. Do not gap-check it, do not comment, do not change its
   state. Record it as signed-off and move on.
2. **Otherwise, run a Definition-of-Done gap-check.** Trace the ticket's
   acceptance criteria against the actual change: type-check, lint, tests,
   build, coverage (rule 14), plus the conditional gates that apply (migration
   safety, API contract, security).
3. **If a gap is found:** move the ticket **back to *In Progress*** and post a
   comment listing exactly which gate failed and the evidence (the failing
   command output, the missing test, the uncovered branch). It then re-enters
   step 1 of the monitor cycle as assigned work.
4. **If no gap is found:** post a brief comment — "linear-loop sign-off
   gap-check passed: <gates run>" — and leave the ticket's state untouched.

The pass **never closes a ticket** and **never re-opens a ticket a human has
signed off on.**

## Loop driver — ruflo autopilot preferred

Pick the driver at the start of each run:

- **If ruflo autopilot is available** (the `mcp__ruflo__autopilot_*` tools are
  loaded and the `ruflo-autopilot:autopilot-loop` skill is listed): this is the
  **preferred** driver. Enable autopilot if not already on, register the Linear
  monitor cycle as the task source, and let the autopilot loop pace iterations
  with its own state tracking.
- **If ruflo autopilot is not available**: fall back to native scheduling —
  - With an `<interval>` arg: `CronCreate` a per-project job (cross-session).
  - Without an interval: `ScheduleWakeup` to self-pace **within the session only**.

Either way the cron registration is **per-project**: before creating a job,
`CronList` and check whether a `linear-loop` job already exists for this project
slug — if so, update it instead of creating a duplicate. `/linear-loop stop`
calls `CronDelete` for this project's job.

## Per-project state

State lives at `~/.cappy/linear-loop/<slug>.json`, where `<slug>` is the repo
basename plus the first 8 hex chars of `sha256(<absolute project root path>)` —
e.g. `cappy-a1b2c3d4`. Compute it with a Bash call; create the
`~/.cappy/linear-loop/` directory if missing.

```json
{
  "_version": 1,
  "project_path": "/abs/path/to/project",
  "linear_scope": { "team_id": "...", "project_id": null },
  "blocked_recheck_hours": 4,
  "cron_job_id": "linear-loop-<slug>",
  "loop_mechanism": "ruflo-autopilot",
  "blocked_tickets": {
    "ENG-123": { "blocked_at": "2026-05-15T09:00:00Z", "recheck_at": "2026-05-15T13:00:00Z" }
  },
  "skipped_this_run": ["ENG-456"],
  "last_iteration_at": "2026-05-15T09:30:00Z"
}
```

`skipped_this_run` is cleared at the start of each cycle. `_version` lets future
schema changes migrate cleanly — treat a missing or stale `_version` as a fresh
state file.

## Safety — what the loop never does

This loop touches shared state (Linear tickets other people see). It is
deliberately conservative:

- **Never closes a ticket** autonomously. Moving to a terminal status only
  happens for work *this loop* completed and verified, using the user's chosen
  terminal status.
- **Never re-opens a ticket a human has signed off on.**
- **Never self-assigns an unassigned ticket** without asking first.
- **Never force-pushes**, never deletes branches, never sends external messages
  without surfacing it first.
- **Blocks instead of guessing** (CLAUDE.md rule 26): on a decision it cannot
  infer — missing creds, a real UX/product tradeoff, an architectural call
  outside scope, a peer dependency — it moves the ticket to *Blocked*, comments
  the specific blocker, and reschedules. It does not fabricate and does not
  proceed on a placeholder.
- **Heartbeats** every 5–10 min during long autonomous runs so a quiet loop is
  not mistaken for a dead one.
