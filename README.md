# Cappy

**The ultimate Claude Code power-user toolkit.**

Install once. Then just use `claude` normally in any project. The SDLC pipeline kicks in automatically.

```bash
# Install
git clone https://github.com/garyshannon/cappy.git && cd cappy && ./install.sh

# That's it. Now in ANY project:
cd ~/your-project
claude "Add a user dashboard with analytics"
# Claude automatically: discovers → specs → designs → builds → reviews → validates
```

The installer asks where your projects live (e.g., `~/Development`), installs a CLAUDE.md there, and Claude Code picks it up in every subdirectory. No scaffolding, no CLI tools, no team setup needed.

**To skip the pipeline**: say "just do it", "quick fix", or "skip the process".

## What You Get

| Module | Description |
|--------|-------------|
| **core** | 12 CLAUDE.md mechanical overrides — context decay awareness, edit integrity, forced verification, definition of done gates (type-check, lint, test, build, coverage) |
| **statusline** | Animated terminal status bar showing model, context %, git status, task progress, cost, duration, ETAs |
| **settings** | Curated settings.json presets — power-user, cautious, team-lead — with safety rails built in |
| **hooks** | Post-edit type-checking, auto-lint, pre-commit verification, sensitive file guards |
| **mcp** | One-command setup for GitHub, PostgreSQL, and Playwright MCP servers |
| **teams** | Multi-agent swarm templates — **product SDLC (8 agents)**, fullstack API (6), code review (3), docs sprint (4), refactor squad (5) |
| **skills** | Task progress dashboard, skill discovery |
| **templates** | Project CLAUDE.md generators for React/Next.js, Rust, Python/ML, Expo, and generic fullstack |

## Quick Start

### Install everything (interactive)
```bash
git clone https://github.com/garyshannon/cappy.git
cd cappy
./install.sh
```

### Install specific modules
```bash
./install.sh --modules core,statusline,hooks
```

### Non-interactive (CI/automation)
```bash
./install.sh --non-interactive --preset power-user
```

## Modules

### Core: CLAUDE.md Mechanical Overrides

12 composable rules that make Claude Code produce production-grade code:

1. **Step 0 Cleanup** — Remove dead code before refactoring
2. **Phased Execution** — Max 5 files per phase, verify between phases
3. **Senior Dev Override** — Fix architectural flaws, don't just follow orders
4. **Forced Verification** — Must run type-check + lint before declaring done
5. **Sub-Agent Swarming** — Parallel agents for tasks >5 files
6. **Context Decay Awareness** — Re-read files after 10+ messages
7. **File Read Budget** — 2000 line cap, chunk large files
8. **Tool Result Blindness** — Detect truncated results, narrow scope
9. **Edit Integrity** — Read before/after every edit, verify changes applied
10. **No Semantic Search** — Grep isn't AST; search all reference types separately
11. **Definition of Done** — Type-check, lint, test, build, coverage gates must ALL pass
12. **SDLC by Default** — All non-trivial tasks follow the 6-phase pipeline (discovery → spec → design → build → review → validate) with user approval gates. Skip with "just do it"

### Statusline

Animated terminal status bar with:
- Model name and context window usage (color-coded)
- Git branch, dirty state, ahead/behind
- Lines changed, session cost, duration
- Task progress bar with animated spinner and ETA
- Team-aware task tracking

### Hooks

| Hook | Trigger | What it does |
|------|---------|-------------|
| `post-edit-typecheck.sh` | After .ts/.tsx edits | Runs `tsc --noEmit` |
| `post-edit-lint.sh` | After file edits | Auto-runs ESLint/Biome/Ruff/Clippy |
| `pre-commit-check.sh` | Before `git commit` | Type-check + lint + tests gate |
| `file-guard.sh` | Before file writes | Blocks edits to .env, credentials, keys |

### Team Templates

#### Product SDLC (flagship template)

A complete 8-agent software development lifecycle with defined handoffs and approval gates:

```
User Idea → Scout (discovery) → Spec (PRD) → 🔒 USER APPROVAL
→ Architect (design) → 🔒 USER APPROVAL → Engineers (parallel build)
→ Reviewer (code quality + security) → QA (final validation) → Ship
```

| Agent | Role | Phase |
|-------|------|-------|
| **Lead** | Orchestrates pipeline, manages approval gates | All |
| **Scout** | Explores codebase, researches competitors, surfaces questions | 1: Discovery |
| **Spec** | Writes PRD with user stories + acceptance criteria | 2: Specification |
| **Architect** | Technical design, schema, API contracts, task breakdown | 3: Design |
| **Backend-Eng** | Implements backend tasks (APIs, services, data) | 4: Build |
| **Frontend-Eng** | Implements frontend tasks (UI, state, routing) | 4: Build |
| **Reviewer** | Code quality + OWASP security audit (PASS/FAIL) | 5: Review |
| **QA** | Runs all DoD gates, traces acceptance criteria (PASS/FAIL) | 6: Validate |

Review and QA failures loop back to engineers until all issues are fixed.

```bash
~/.cappy/scaffold-team.sh product-sdlc \
  --name dashboard-feature \
  --description "User analytics dashboard" \
  --tech "Next.js 15, TypeScript, Supabase"
```

#### Other templates

```bash
~/.cappy/scaffold-team.sh fullstack-api \
  --name payments-api \
  --description "Building the payments service" \
  --tech "Rust with Actix-Web and SQLx"
```

Templates: `product-sdlc`, `fullstack-api`, `code-review`, `docs-sprint`, `refactor-squad`

### Project Templates

Generate per-project CLAUDE.md files:

```bash
~/.cappy/scaffold-project.sh react-nextjs --name my-app
```

Templates: `react-nextjs`, `rust-api`, `python-ml`, `expo-mobile`, `generic-fullstack`

## Settings Presets

| Preset | Permissions | Agent Teams | Auto-Dream | Safety |
|--------|-----------|-------------|------------|--------|
| **power-user** | Full (Bash, Read, Write, Edit, Web) | Enabled | On | rm -rf blocked |
| **cautious** | Read + Edit only | Disabled | Off | Bash restricted, secrets blocked |
| **team-lead** | Full | Enabled | On | rm -rf blocked |

## Updating

```bash
~/.cappy/repo/update.sh
```

Or from a cloned repo:
```bash
cd cappy && git pull && ./update.sh
```

Updates re-apply installed modules without touching your customizations. Cappy-managed sections in CLAUDE.md (inside `<!-- cappy:managed-start/end -->` markers) are replaced; your own content is preserved.

## Uninstalling

```bash
~/.cappy/repo/uninstall.sh
```

This removes cappy-managed CLAUDE.md sections and hook files. Offers to restore from backup. Your settings.json is preserved (remove cappy entries manually if needed).

## How It Works

- **Non-destructive**: Always backs up existing configs before modifying
- **Marker-based CLAUDE.md**: Sections wrapped in `<!-- cappy:section:NAME -->` markers enable surgical updates
- **JSON merging**: Settings are deep-merged via `jq` — arrays unioned, objects recursively merged
- **File collision detection**: SHA256 comparison — identical files skipped, conflicts prompt user
- **Module manifests**: Each module has a `module.json` declaring its files, targets, and dependencies

## Requirements

- Claude Code CLI installed
- `jq` (installer offers to install it)
- `bash` 4+ (macOS ships 3.2 — `brew install bash` if needed)
- `git` for curl-pipe install and updates

## License

MIT
