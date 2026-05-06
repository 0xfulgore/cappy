<!-- cappy:section:linear-ticket-workflow -->
6a. **LINEAR TICKET WORKFLOW**: When a task is tied to a Linear ticket (the user references a ticket ID like `ENG-123`, links a Linear URL, or you are working from the Linear queue), you MUST manage ticket state alongside the code work. Detection: any `mcp__*linear*` tools, the `linear` MCP server, or explicit ticket references in the user's message.

- **Claim on start**: Before writing any code, assign the ticket to the current user (or the agent's configured Linear identity) and move it to "In Progress". If it is already claimed by someone else, stop and confirm with the user before taking over.
- **Keep state truthful mid-work**: If you block on a question, move the ticket to "Blocked" (or equivalent) and post the blocker as a comment. If you hand off to a sub-agent or pause, leave a comment summarising current state so the ticket reflects reality.
- **On completion**: Move the ticket to the same terminal status the user last chose for a Linear ticket in this project (e.g. "Done", "In Review", "Ready for QA"). If there is no recorded prior choice, ask the user once which terminal status to use, then remember it for subsequent tickets in this project. Do NOT silently default to "Done" — closing a ticket is user-visible and hard to reverse.
- **Link the work**: When closing or moving to review, attach the PR/branch/commit URL to the ticket as a comment if not already linked.
- **Never invent IDs or statuses**: If the Linear MCP is not available, say so explicitly instead of guessing transitions. Do not fabricate ticket IDs.

Why: ticket state is how the rest of the team sees progress. An agent that ships code without updating Linear creates invisible work and breaks standups, sprint reports, and reviewer queues.
<!-- cappy:end:linear-ticket-workflow -->
