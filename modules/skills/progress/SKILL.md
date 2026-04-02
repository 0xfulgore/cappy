---
name: progress
description: Show visual progress bars for all tasks with status, owners, dependencies, and rough ETAs
allowed-tools: Bash, Read, Glob, TaskList, TaskGet
triggers:
  - progress
  - progress bar
  - task progress
  - show progress
  - status report
  - task status
---

# Progress Dashboard

Show a visual progress dashboard for the current task list.

## Instructions

1. Call `TaskList` to get all current tasks
2. For each task, display:
   - Status icon: pending (○), in_progress (▶), completed (✓), blocked (⏸)
   - Task subject
   - Owner (if assigned)
   - Dependencies (blockedBy)
3. Show an overall progress bar
4. Calculate rough ETA based on completed vs remaining tasks

## Output Format

```
━━ Task Progress ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[████████████░░░░░░░░] 60% (3/5 complete)

  ✓ #1  Set up database schema         @architect
  ✓ #2  Create API endpoints           @backend
  ✓ #3  Write unit tests               @tester
  ▶ #4  Build frontend components      @frontend
  ○ #5  Deploy to staging              (blocked by #4)

ETA: ~20 min remaining
```
