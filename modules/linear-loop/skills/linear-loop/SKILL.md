---
name: linear-loop
description: Persistent loop that acts as a full Linear teammate — a fast ~1-minute watch tier catches new tickets, comments, and replies; a work cycle triages incoming tickets, orchestrates the dependency-ordered queue, works tickets through the SDLC, reschedules blocked ones, picks up eligible unassigned tickets (with your OK), and reviews your own and other people's work in In Review / Done. Per-project, cross-session.
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Agent, Task, TaskCreate, TaskList, TaskUpdate, AskUserQuestion, CronCreate, CronList, CronDelete, ScheduleWakeup, mcp__linear
triggers:
  - linear loop
  - linear-loop
  - monitor linear
  - work my linear tickets
  - linear ticket loop
  - keep working linear
  - triage linear
---

# Linear Loop

A persistent, per-project loop that acts as a **full Linear teammate**: it
**triages** incoming tickets, **orchestrates** the dependency-ordered queue,
**works** tickets through the SDLC, and **reviews** your own and other people's
work. It runs on **two tiers**:

- A fast **watch tier** (default every **1 minute**) — a cheap, read-only poll
  that catches new tickets assigned to you, new comments, and replies on tickets
  the loop is waiting on.
- A heavier **work cycle** — triage → orchestrate → work → blocked handling →
  unassigned pickup → review pass.

It runs **cross-session** — registered as a single per-project cron job that
fires at the watch interval — and the watch tier decides when to spend a full
work cycle.

## Usage

```
/linear-loop                  # run one watch + work cycle now, self-pace in-session
/linear-loop 30m              # cron: watch every 1m, full work cycle every 30m
/linear-loop 4h               # cron: watch every 1m, full work cycle every 4h
/linear-loop watch 2m         # set the fast-watch interval (default 1m)
/linear-loop stop             # remove this project's linear-loop cron job
/linear-loop status           # show loop state, the orchestration plan, last watch/cycle
```

The interval arg sets the **work-cycle** cadence (`30m`, `1h`, `4h`, `1d`). The
**watch** interval defaults to `1m` and is set separately with `/linear-loop
watch <interval>`. With no interval, the loop runs one watch + work cycle now
and self-paces in-session with `ScheduleWakeup`; with an interval it registers a
cron job so monitoring survives session exit.

> **Cost note:** a 1-minute watch interval wakes the agent every minute, which
> has a real token cost. The watch tier is deliberately minimal so idle minutes
> are cheap, but if cost matters more than latency, raise the watch interval
> (`/linear-loop watch 5m`). Watch intervals below `1m` are not supported.

## Preflight — run at the start of every watch tick and every work cycle

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

## The watch tier — fast poll (default every 1 minute)

The watch tier is a **cheap, read-only** check. It must do almost nothing on an
idle tick: query, find nothing, update `last_watch_at`, return. It never does
SDLC work itself — it only **detects** and **triggers**.

On each tick, after preflight:

1. **New tickets** — query issues in the project scope created or changed since
   `last_watch_at`: newly assigned to the current user, **and** newly created in
   an untriaged state (these feed the triage pass). Add tickets assigned to you
   to `tracked_tickets`.
2. **New comments** — for every ticket in `tracked_tickets`, query comments
   created since `last_watch_at`. Pay special attention to blocked tickets with
   `awaiting_reply: true` — a human comment there is the reply the loop is
   waiting on.
3. **Status changes** — for every ticket in `tracked_tickets`, detect a status
   change since `last_watch_at` (e.g. a human moved a *Blocked* ticket, someone
   approved or rejected an *In Review* ticket).
4. **Decide** whether anything is **actionable**:
   - A new ticket was assigned to you, or a new ticket needs triage → actionable.
   - A new human comment landed on a blocked ticket the loop is waiting on, or a
     change-request / new instruction landed on an *In Progress* ticket →
     actionable.
   - A tracked ticket's status changed in a way the loop must reconcile →
     actionable.
   - Otherwise → **not** actionable.
5. **Act:**
   - If a blocked ticket got a reply that resolves its blocker → clear
     `awaiting_reply`, move it back to *In Progress*, and mark a work cycle due.
   - If anything else is actionable → mark a work cycle due.
   - If a work cycle is due **or** `cycle_interval` has elapsed since
     `last_cycle_at` → run **The work cycle** now.
   - If nothing is actionable and `cycle_interval` has not elapsed → do nothing
     else this tick.
6. **Persist** `last_watch_at = now` and any `tracked_tickets` changes.

## The work cycle

Run these steps in order. Each step is independent — a failure in one does not
skip the rest; surface the failure and continue. Set `last_cycle_at = now` when
the cycle finishes.

### 1. Triage pass
- Query untriaged tickets in the project scope (in a *Triage* / *Backlog*
  workflow state, or missing priority). For each, apply the **triage rules**
  below: completeness check, duplicate detection, classification.

### 2. Build the orchestration plan
- Gather every actionable ticket: assigned to you and not terminal, plus any
  newly unblocked. Build the **orchestration plan** per the **orchestration
  rules** below — a dependency-ordered, epic-aware queue with an explicitly
  parallelizable set.

### 3. Work tickets — orchestrated
- Work tickets **in the order the plan dictates**, not by raw priority alone.
  Never start a ticket whose blocking issues are still open.
- For each ticket worked: claim it per CLAUDE.md rule 6a (assign to self, move
  to *In Progress* before any code), add it to `tracked_tickets`, work it
  through the SDLC. For multi-file work, and for the plan's parallelizable set,
  dispatch sub-agents / a ruflo swarm per CLAUDE.md rules 7 / 7a / 7b.
  Heartbeat: post a Linear comment or commit every 5–10 min on long runs.
- On completion: run the Definition-of-Done gates (rule 14), move the ticket to
  the project's terminal status (rule 6a — ask once which status, then reuse it),
  and attach the PR / branch / commit URL as a comment. When a worked ticket is
  a child of an epic, post epic-level progress on the parent.

### 4. Handle a blocker
- If a ticket you are working hits a blocker you cannot resolve (missing creds,
  a product/UX decision, a peer dependency, a destructive action on shared
  state — CLAUDE.md rule 26):
  - Move the ticket to *Blocked*.
  - Post the specific, actionable blocker as a Linear comment (bad: "need more
    info"; good: names the exact decision and what you already checked).
  - Record `{ "blocked_at": <now>, "recheck_at": <now + blocked_recheck_hours>,
    "awaiting_reply": true }` in `blocked_tickets`. Default `blocked_recheck_hours`
    is 4. The `awaiting_reply` flag tells the watch tier to watch this ticket for
    a human reply every minute — so a reply is picked up fast, not at the next
    4-hour recheck.

### 5. Recheck blocked tickets
- For each entry in `blocked_tickets` whose `recheck_at` has passed: re-read the
  ticket. If the blocker is resolved (a human answered the comment, creds
  landed, the dependency shipped), clear `awaiting_reply`, move it back to
  *In Progress*, and feed it into the next plan. If still blocked, push
  `recheck_at` forward by `blocked_recheck_hours`. (The watch tier usually
  catches a reply long before `recheck_at` — this step is the backstop for
  blockers resolved by something other than a comment.)

### 6. Scan unassigned tickets for pickup
- Query **unassigned** issues in the project scope that are not in a terminal
  state. For each, apply the **pickup heuristic** below. If eligible, use
  `AskUserQuestion` to ask whether to pick it up:
  - **Yes** → assign it to the current user, move to *In Progress*, fold it into
    the orchestration plan.
  - **No** → add the ticket ID to `skipped_this_run`; do not ask again this cycle.
- Never self-assign an unassigned ticket without asking first.

### 7. Review pass — your work and others'
- Query issues in *In Review* and *Done* in the project scope — **both yours and
  other people's**. For each, see *Review / sign-off pass*.

### 8. Schedule the next cycle
- See *Loop driver*. Persist `last_cycle_at` and the orchestration plan.

## Triage rules

For each untriaged ticket. The split between **apply** and **propose** keeps the
loop from steamrolling a PM's or reporter's intent — `triage_mode` in state
tunes it (`conservative` default, or `bold` to apply everything).

**Apply directly** (low-risk grooming, easily reversible):
- **Labels** — add labels the content clearly warrants (`bug`, `api`, area tags).
- **Un-triage** — move a ticket out of *Triage* into *Backlog* / *Todo* **only
  when it is complete enough** to act on (clear problem statement + acceptance
  criteria).

**Propose via one structured comment** (judgement calls — leave the decision to
a human):
- **Priority** and **estimate** — suggest values with a one-line rationale.
- **Routing** — suggest a different project/team if the ticket looks misfiled.
- **Duplicates** — if a likely duplicate exists, link the candidate and explain
  the overlap. Never auto-close — closing is forbidden (see *Safety*).
- **Missing info** — if the ticket lacks a problem statement or acceptance
  criteria, comment asking for the *specific* missing pieces. Never invent them.

In `bold` mode, priority/estimate/routing are applied instead of proposed;
duplicate-flagging and missing-info requests stay comment-only either way.

## Orchestration rules

Treat the ticket queue as a project to coordinate, not a flat list.

- **Dependency graph** — build it from Linear's *blocking* / *blocked-by*
  relations plus *parent* / *child* links. Work tickets in topological order;
  never start a ticket with an open blocker.
- **Epic-aware** — when a parent/epic has multiple children, treat the epic as
  the unit: sequence its children, and post epic-level progress as a comment on
  the parent as children complete.
- **Parallelism** — tickets with no dependency between them **and** no expected
  shared-file overlap form the *parallelizable set*. Dispatch them to parallel
  sub-agents or a ruflo swarm per CLAUDE.md rules 7 / 7a / 7b — do not force
  strictly one-at-a-time work when the queue allows parallelism.
- **Plan visibility** — `/linear-loop status` prints the current plan: the
  ordered queue, the parallelizable set, and what is blocked on what.

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

For each ticket in *In Review* or *Done* — **yours and other people's**:

1. **Check for an explicit human sign-off first.** If a person (not this loop,
   not an agent) has explicitly signed off — a comment like "approved", "code is
   fine", "LGTM", "ship it", or a human-set approved/merged state — the ticket
   is **hands-off**. Do not gap-check it, do not comment, do not change its
   state. Record it as signed-off and move on.
2. **Otherwise, review it.** Pull the linked PR / branch and run:
   - A **Definition-of-Done gap-check** — trace the ticket's acceptance criteria
     against the actual change: type-check, lint, tests, build, coverage
     (rule 14), plus the conditional gates that apply (migration safety, API
     contract, security).
   - A **code review** — quality, naming, duplication, error handling, OWASP
     Top 10, architecture fit. Post substantive review feedback as a comment.
3. **Whose ticket is it?**
   - **Your own work** — if a gap is found, move the ticket **back to
     *In Progress*** and comment exactly which gate failed and the evidence. It
     re-enters the work cycle as assigned work. If clean, comment "linear-loop
     sign-off gap-check passed: <gates run>" and leave the state untouched.
   - **Someone else's ticket** — comment the review and any gap findings, but
     **do not change their ticket's state** — re-opening someone else's work is
     their call, not the loop's. (`review_mode: bold` in state lets it move
     others' tickets too; default is `conservative` — comment only.)

The pass **never closes a ticket** and **never re-opens a ticket a human has
signed off on.**

## Loop driver — ruflo autopilot preferred

Pick the driver at the start of each run:

- **If ruflo autopilot is available** (the `mcp__ruflo__autopilot_*` tools are
  loaded and the `ruflo-autopilot:autopilot-loop` skill is listed): this is the
  **preferred** driver. Enable autopilot if not already on, register the watch
  tier as the per-iteration task, pace iterations at `watch_interval`, and let
  the autopilot loop carry state across iterations.
- **If ruflo autopilot is not available**: fall back to native scheduling —
  - With an `<interval>` arg: `CronCreate` a **single** per-project job that
    fires at `watch_interval` (cross-session). Each fire runs the watch tier,
    which gatekeeps the work cycle.
  - Without an interval: `ScheduleWakeup` at `watch_interval` to self-pace
    **within the session only**.

There is **one** cron job per project, firing at the watch interval — not one
per tier. The `cycle_interval` is enforced inside the watch tier, not by a
second cron. Before creating a job, `CronList` and check whether a `linear-loop`
job already exists for this project slug — if so, update it instead of creating
a duplicate. `/linear-loop stop` calls `CronDelete` for this project's job.

## Per-project state

State lives at `~/.cappy/linear-loop/<slug>.json`, where `<slug>` is the repo
basename plus the first 8 hex chars of `sha256(<absolute project root path>)` —
e.g. `cappy-a1b2c3d4`. Compute it with a Bash call; create the
`~/.cappy/linear-loop/` directory if missing.

```json
{
  "_version": 2,
  "project_path": "/abs/path/to/project",
  "linear_scope": { "team_id": "...", "project_id": null },
  "watch_interval": "1m",
  "cycle_interval": "30m",
  "blocked_recheck_hours": 4,
  "triage_mode": "conservative",
  "review_mode": "conservative",
  "terminal_status": "In Review",
  "cron_job_id": "linear-loop-<slug>",
  "loop_mechanism": "ruflo-autopilot",
  "tracked_tickets": ["ENG-123", "ENG-200"],
  "blocked_tickets": {
    "ENG-123": {
      "blocked_at": "2026-05-15T09:00:00Z",
      "recheck_at": "2026-05-15T13:00:00Z",
      "awaiting_reply": true
    }
  },
  "skipped_this_run": ["ENG-456"],
  "last_watch_at": "2026-05-15T09:34:00Z",
  "last_cycle_at": "2026-05-15T09:30:00Z"
}
```

- `tracked_tickets` — the set the watch tier polls for new comments and status
  changes: tickets assigned to you that are active or blocked, plus any the loop
  is reviewing.
- `awaiting_reply` — set when the loop posts a blocker comment; tells the watch
  tier to treat a human reply on that ticket as actionable.
- `triage_mode` / `review_mode` — `conservative` (default) or `bold`. See
  *Triage rules* and *Review / sign-off pass*.
- `terminal_status` — the status the user chose for completed work (rule 6a);
  asked once, then reused.
- `skipped_this_run` is cleared at the start of each **work cycle**.
- `_version` lets future schema changes migrate cleanly — treat a missing or
  lower `_version` as a fresh state file, seeding any new fields with defaults.

## Safety — what the loop never does

This loop touches shared state (Linear tickets other people see). It is
deliberately conservative:

- **Never closes a ticket** autonomously — not even an obvious duplicate. It
  flags; a human closes.
- **Never re-opens a ticket a human has signed off on.**
- **Never changes another person's ticket state** in `conservative` mode —
  triage and review on others' tickets are comment-only.
- **Never self-assigns an unassigned ticket** without asking first.
- **Never invents** acceptance criteria, priorities, or estimates — it proposes
  with rationale, or asks for the specific missing pieces.
- **Never force-pushes**, never deletes branches, never sends external messages
  without surfacing it first.
- **The watch tier never mutates** beyond the state file and unblocking a ticket
  whose blocker a human just answered — all heavier action goes through the work
  cycle.
- **Blocks instead of guessing** (CLAUDE.md rule 26): on a decision it cannot
  infer — missing creds, a real UX/product tradeoff, an architectural call
  outside scope, a peer dependency — it moves the ticket to *Blocked*, comments
  the specific blocker, and reschedules. It does not fabricate and does not
  proceed on a placeholder.
- **Heartbeats** every 5–10 min during long autonomous runs so a quiet loop is
  not mistaken for a dead one.
