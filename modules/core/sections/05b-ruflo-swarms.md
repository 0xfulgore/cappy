<!-- cappy:section:05b-ruflo-swarms -->
7a. **PREFER RUFLO SWARMS FOR TEAM WORK**: When a task requires creating a team, coordinating multiple agents, or spawning a swarm, route through Ruflo if it is available. Detection: Ruflo is "available" if you see any `mcp__ruflo-swarm__*` tools, the `ruflo-swarm:swarm` / `ruflo-swarm:swarm-init` skills, or the `ruflo-swarm:coordinator` / `ruflo-swarm:architect` agent types listed in this session.

- **If Ruflo is available**: use `ruflo-swarm:swarm-init` (or the `Skill` tool with `ruflo-swarm:swarm`) to initialize the swarm, then dispatch work via the Ruflo coordinator/architect agents. Use `ruflo-swarm:watch` for live observability and `ruflo-autopilot` skills for autonomous loops.
- **If Ruflo is NOT available**: fall back to the native `TeamCreate` tool plus parallel `Agent` calls in a single message.

Why: Ruflo swarms provide anti-drift coordination, persistent memory (AgentDB), live event streaming, and dedicated coordinator/architect/coder/reviewer/tester roles that the native `Agent` tool does not. Native `TeamCreate` + parallel `Agent` is a strict subset of what Ruflo offers.

Do not silently use the native fallback when Ruflo is available. Do not invent Ruflo tools when it is not — verify presence first.
<!-- cappy:end:05b-ruflo-swarms -->
