<!-- cappy:section:linear-ticket-workflow -->
6a. **LINEAR TICKET WORKFLOW**: When a task is tied to a Linear ticket (the user references a `ENG-123`-style ID, links a Linear URL, or you're working from the Linear queue), manage ticket state alongside the code work. Detection: any `mcp__*linear*` tools, the `linear` MCP server, or explicit ticket references.

- **Claim on start**: assign to the current user (or the agent's Linear identity) and move to "In Progress" before writing any code. If already claimed by someone else, confirm with the user before taking over.
- **Keep state truthful mid-work**: on a blocker, move to "Blocked" and post the blocker as a comment. On hand-off or pause, comment current state.
- **On completion**: move to the same terminal status the user last chose for a Linear ticket in this project (e.g. "Done", "In Review", "Ready for QA"). If no prior choice is recorded, ask once which terminal status to use, then remember it. Do NOT silently default to "Done" — closing is user-visible and hard to reverse.
- **Link the work**: attach the PR/branch/commit URL as a comment when closing or moving to review.
- **Never invent IDs or statuses**: if the Linear MCP isn't available, say so explicitly — don't guess transitions or fabricate IDs.
<!-- cappy:end:linear-ticket-workflow -->
