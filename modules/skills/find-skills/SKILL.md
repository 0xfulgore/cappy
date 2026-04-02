---
name: find-skills
description: Discover and install agent skills from the skills.sh ecosystem
allowed-tools: Bash, WebSearch, WebFetch, Read
triggers:
  - find skills
  - search skills
  - install skill
  - skill marketplace
  - available skills
  - discover skills
---

# Find Skills

Help users discover and install Claude Code skills from the ecosystem.

## Instructions

1. Ask the user what capability they're looking for
2. Search for matching skills using:
   - `skills.sh` ecosystem: `curl -s https://skills.sh/api/search?q=QUERY`
   - GitHub: search for repos with "claude-code-skill" or "SKILL.md" in the name
   - The official plugin marketplace
3. Present results with:
   - Skill name and description
   - Install command
   - Rating/popularity if available
4. Offer to install the selected skill

## Install Methods

```bash
# From skills.sh
skills install <skill-name>

# From GitHub
claude skill install --from github:owner/repo

# Manual
mkdir -p ~/.agents/skills/<name>
# Copy SKILL.md into the directory
```
