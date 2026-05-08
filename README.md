# Cappy

**The ultimate Claude Code power-user toolkit.**

Install once. Then just use `claude` normally in any project. The SDLC pipeline kicks in automatically.

```bash
# Install (one-liner)
curl -fsSL https://raw.githubusercontent.com/0xfulgore/cappy/main/get-cappy.sh | bash

# That's it. Now in ANY project:
cd ~/your-project
claude "Add a user dashboard with analytics"
# Claude automatically: discovers → specs → designs → builds → reviews → validates
```

The bootstrap clones the repo to `~/.cappy/repo/`, hands off to `cappy boot`, and from then on you manage everything with `cappy update`, `cappy status`, etc. Prefer the manual route? `git clone https://github.com/0xfulgore/cappy.git && cd cappy && ./install.sh` still works.

The installer asks where your projects live (e.g., `~/Development`), installs a CLAUDE.md there, and Claude Code picks it up in every subdirectory. No scaffolding, no CLI tools, no team setup needed.

**To skip the pipeline**: say "just do it", "quick fix", or "skip the process".

## What You Get

17 default modules + 3 opt-in modules. Install all or pick a subset.

| Module | Description |
|--------|-------------|
| **core** | SDLC pipeline + 18 mechanical overrides (15 numbered rules + Linear ticket workflow, Ruflo swarm preference, mandatory swarm-split threshold) — the engine that drives everything |
| **auto-update** | `cappy` CLI shim + 24h-cadence update notifier in the statusline (see [The `cappy` command](#the-cappy-command)) |
| **statusline** | Animated status bar: model, context %, git, task progress, cost, ETA |
| **settings** | settings.json presets — power-user, cautious, team-lead |
| **hooks** | Post-edit typecheck, auto-lint, pre-commit gate, file guard |
| **hedge-detector** | Stop hook that rejects hedging language ("probably", "I think", "seems", "could be") in assistant output |
| **git-safety** | Block force-push to main, conventional commit format hints |
| **mcp** | MCP servers: GitHub, Linear (OAuth), PostgreSQL, Playwright |
| **teams** | 14 agent swarm templates (see below) — installs `~/.cappy/scaffold-team.sh` |
| **skills** | Task progress dashboard, skill discovery |
| **templates** | Project CLAUDE.md generators: React, Rust, Python, Expo, generic — installs `~/.cappy/scaffold-project.sh` |
| **performance** | Perf directives: bundle size, N+1 queries, lazy loading, pagination |
| **accessibility** | WCAG 2.2 AA: keyboard nav, screen readers, contrast, touch targets |
| **devops** | CI/CD awareness, env var safety, Docker best practices, migrations |
| **api-design** | REST conventions, input validation, error handling, versioning |
| **ruflo** | Ruflo agent platform: marketplace + 8 plugins + MCP server |
| **mempalace** | MemPalace local-first AI memory: pip package + MCP server (user scope). Auto-installs pipx if missing. Run `mempalace init/mine` per project. |

### Opt-in modules
These are listed in the picker but NOT included in "install all" — pick by number, or pass via `--modules`. All fetch from upstream at install time.

| Module | Description |
|--------|-------------|
| **huashu-design** | HTML hi-fi prototyping skill from [alchaincyf/huashu-design](https://github.com/alchaincyf/huashu-design). Shallow-clones into `~/.claude/skills/huashu-design`. |
| **frontend-design** | Anthropic's official production frontend skill from [anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design). Sparse-checkout into `~/.claude/skills/frontend-design`. Coexists with huashu-design (different skill name and trigger profile). |
| **cua-driver** | macOS app driver from [trycua/cua](https://github.com/trycua/cua) — Swift binary + MCP server + bundled skill pack. Delegates to upstream's official installer; auto-registers as an MCP server in Claude Code. macOS-only (skips on other OSes). Needs Accessibility + Screen Recording permissions on first use. |

## Quick Start

### One-liner (interactive)
```bash
curl -fsSL https://raw.githubusercontent.com/0xfulgore/cappy/main/get-cappy.sh | bash
```

### Pin a branch
```bash
curl -fsSL https://raw.githubusercontent.com/0xfulgore/cappy/main/get-cappy.sh | CAPPY_BRANCH=develop bash
```

### Manual clone (still supported)
```bash
git clone https://github.com/0xfulgore/cappy.git
cd cappy
./install.sh
```

This clones a self-contained copy to `~/.cappy/repo` and installs from there. Your `cd`-ed clone can be deleted afterwards — cappy survives.

### Dev mode (cappy maintainers)
```bash
cd /path/to/your/cappy/clone
./install.sh --link
```

Symlinks `~/.cappy/repo` → your clone instead of cloning fresh. Edits to your clone are live in cappy. **Footgun**: if you delete or move the clone, cappy breaks. Re-run without `--link` to switch back to a self-contained install.

### Install specific modules
```bash
cappy install --modules core,auto-update,statusline,hooks
# or, pre-install:  ./install.sh --modules ...
```

### Non-interactive (CI/automation)
```bash
cappy install --non-interactive --preset power-user
# or:  ./install.sh --non-interactive --preset power-user
```

## Modules

### Core: CLAUDE.md Mechanical Overrides

Composable rules that make Claude Code produce production-grade code. Each rule is a separately-toggleable section in your CLAUDE.md.

**Pre-Work**
1. **Evidence Before Explanation** — First action must be a tool call gathering evidence; no causal claims without citations
2. **Step 0 Cleanup** — Remove dead code before refactoring
3. **Phased Execution** — Max 5 files per phase, verify between phases

**Code Quality**
4. **Senior Dev Override** — Fix architectural flaws, don't just follow orders
5. **Fix As You Go** — Broken thing found mid-task gets fixed immediately, no defer lists
6. **Forced Verification** — Must run type-check + lint before declaring done
6a. **Linear Ticket Workflow** — Auto-claim, set in-progress, comment on blockers, transition to user's chosen terminal status; attach PR/branch URLs

**Context Management**
7. **Sub-Agent Swarming** — Parallel agents for tasks >5 files
7a. **Prefer Ruflo Swarms For Team Work** — Route team/swarm work through Ruflo if its tools/skills are present; fall back to native `TeamCreate` only when not
7b. **Mandatory Swarm Split For Large Bodies of Work** — Force a swarm when work exceeds any of: >10 files, >300 LOC, >8 design tasks, >2h, or >2 subsystems
8. **Context Decay Awareness** — Re-read files after 10+ messages
9. **File Read Budget** — 2000 line cap, chunk large files
10. **Tool Result Blindness** — Detect truncated results, narrow scope

**Edit Safety**
11. **Edit Integrity** — Read before/after every edit, verify changes applied
12. **No Semantic Search** — Grep isn't AST; search all reference types separately

**Definition of Done**
13. **Verify Before Claiming Done** — Read actual output yourself; never trust "agent said done"
14. **Definition of Done** — Type-check, lint, test, build, coverage gates must ALL pass

**Default Workflow**
15. **SDLC by Default** — All non-trivial tasks follow the 6-phase pipeline (discovery → spec → design → build → review → validate) with user approval gates. Skip with "just do it"

The `performance`, `accessibility`, `devops`, and `api-design` modules add four more rule clusters (16–19) on top of core when installed.

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
| `hedge-rejector.mjs` | Stop event | Rejects hedging language ("probably", "I think", "seems") in assistant output (separate `hedge-detector` module) |

### MCP Servers

The `mcp` module configures MCP servers for Claude Code on a per-server-opt-in basis. Choose any subset during install:

| Server | What it provides | Auth |
|--------|------------------|------|
| **GitHub** | PR/issue management, code search | Token from `gh auth` or env |
| **Linear** | Ticket claim, transition, comment, link PRs (used by rule 6a) | OAuth via browser |
| **PostgreSQL** | Database queries and exploration | Connection string |
| **Playwright** | Browser automation and testing | None |

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

All templates:

| Template | Agents | Pipeline |
|----------|--------|----------|
| `product-sdlc` | 8 | discovery → spec → design → build → review → QA |
| `audit-sweep` | 8 | 4 parallel auditors → triage → 2 fixers → verifier |
| `migration-squad` | 6 | analyze → design → migrate → validate → rollback test |
| `perf-clinic` | 5 | profile → plan → optimize (BE+FE parallel) → validate |
| `test-factory` | 5 | analyze gaps → plan → write unit+integration+e2e → validate |
| `dependency-upgrade` | 5 | scan → plan → upgrade → compatibility test |
| `incident-responder` | 5 | reproduce → root cause → hotfix → post-mortem |
| `onboarding-guide` | 5 | map → document architecture → trace flows → write guide |
| `api-versioning` | 5 | analyze contracts → design v2 → migrate → update clients |
| `monorepo-splitter` | 5 | map deps → define boundaries → extract → update CI/CD |
| `fullstack-api` | 6 | architect → build (BE+FE) → test → docs |
| `code-review` | 3 | security + quality review |
| `docs-sprint` | 4 | API docs + guides + architecture |
| `refactor-squad` | 5 | analyze → refactor → test |

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

## The `cappy` command

The `auto-update` module installs a `cappy` CLI shim and a 24h-cadence update notifier in the statusline.

```bash
cappy update           # interactive prompt, then `git pull` + reinstall
cappy update --yes     # non-interactive
cappy status           # local SHA, latest SHA, behind count, last-checked
cappy check            # force a fresh remote check now (bypasses 24h cache)
cappy version          # print installed cappy version
cappy help             # show splash + usage
```

**How notifications work:**
- The statusline reads `~/.cappy/update-status.json`. If it's missing or older than 24 hours, it fires `lib/update-check.sh` async and detached so the prompt never blocks.
- When an update is available, the statusline shows a `↑ cappy +N` segment (commits behind). The first sighting per day is bold; subsequent same-day renders are dimmer to avoid noise.
- The check is a single `git ls-remote` (~200 ms) — no clone, no fetch unless you're actually behind.
- Offline / network errors → silent, no statusline noise.

**Where the binary lives:**
- Shim: `~/.cappy/repo/bin/cappy` (the canonical path)
- PATH symlink: `~/.local/bin/cappy` (created automatically only if `~/.local/bin` already exists; install never modifies your shell rc files)
- If `~/.local/bin` isn't on your `$PATH`, run via the canonical path or add it yourself.

## Updating

```bash
cappy update          # interactive — surfaces any new modules
cappy update -y       # non-interactive — silent re-apply
```

`cappy update` pulls the latest tag, then re-runs the installer. The selector is installed-aware: existing modules are re-applied silently, and any modules added since your last install are listed so you can opt in (`a` for all, numbers for specific picks, Enter to skip).

Updates never touch your customizations. Cappy-managed sections in CLAUDE.md (inside `<!-- cappy:managed-start/end -->` markers) are replaced; your own content is preserved.

## Uninstalling

```bash
cappy uninstall
# or, directly:  ~/.cappy/repo/uninstall.sh
```

This removes cappy-managed CLAUDE.md sections and hook files. Offers to restore from backup. Your settings.json is preserved (remove cappy entries manually if needed).

## Versioning & Releases

Cappy follows [semantic versioning](https://semver.org/). The auto-update notifier is **release-based** — published tags trigger the `↑ cappy v1.2.3` segment in your statusline. Bug-fix commits between releases don't nag users until you cut a new tag.

**Pre-release fallback**: if no semver tags exist on the remote yet, the notifier falls back to **commit mode** — it shows `↑ cappy +N` (commits behind upstream `main`) so early adopters still see updates. The moment any `vX.Y.Z` tag lands, the notifier auto-switches to tag mode on the next 24 h check.

| Bump | When to use | Examples |
|------|-------------|----------|
| **MAJOR** (1.x.x → 2.0.0) | Breaking changes — module removed, incompatible config, user migration required | dropping bash 3.2 support, changing the CLAUDE.md marker format |
| **MINOR** (1.0.x → 1.1.0) | New modules, new features, backward-compatible additions | the auto-update module, new agent template |
| **PATCH** (1.0.0 → 1.0.1) | Bug fixes, docs, internal cleanups | the JSON merge fix, README updates |

### Cutting a release (maintainer)

```bash
./release.sh patch              # 1.0.0 → 1.0.1
./release.sh minor              # 1.0.0 → 1.1.0
./release.sh major              # 1.0.0 → 2.0.0
./release.sh 1.2.3              # explicit version
./release.sh patch --dry-run    # preview
./release.sh minor --gh         # also `gh release create`
```

What it does:
1. Refuses to run on a dirty tree or off `main` (unless you confirm).
2. Bumps `version` in `forge.json`.
3. Collects commits since the last tag into a changelog block.
4. Commits `release: vX.Y.Z` with the changelog in the body.
5. Creates an annotated tag `vX.Y.Z`.
6. Pushes the commit and the tag.
7. Optionally `gh release create` with auto-generated notes.

How users see the new release:
- Within 24h, `lib/update-check.sh` queries `git ls-remote --tags`, finds the new highest semver tag, writes `available: true` to `~/.cappy/update-status.json`.
- The statusline picks it up next render and shows `↑ cappy v1.2.3`.
- `cappy update` pulls and reinstalls.

## How It Works

- **Non-destructive**: Always backs up existing configs to `~/.claude/backups/cappy-<timestamp>/` before modifying
- **Marker-based CLAUDE.md**: Sections wrapped in `<!-- cappy:section:NAME -->` markers enable surgical updates — your hand-written content outside the managed block is preserved
- **JSON merging**: Settings are deep-merged via `jq` — arrays unioned, objects recursively merged. Inputs are validated up front; a malformed `settings.json` aborts the merge with a clear error rather than truncating your file
- **File collision detection**: SHA256 comparison — identical files skipped, conflicts prompt user (skip / overwrite / keep both as `.bak`)
- **Module manifests**: Each module has a `module.json` declaring its files, targets, settings fragment, and dependencies
- **Idempotent**: Re-running the installer is safe — already-installed bits are detected and skipped (e.g., MemPalace pip package, MCP servers)

## Requirements

- Claude Code CLI installed
- `jq` (installer offers to install it)
- `bash` 3.2+ — works with the macOS-shipped bash; bash 4+ also fine
- `git` for clone-based install and updates
- `node` (only for the `hedge-detector` module)
- `python3` + `pipx` (only for the `mempalace` module — installer auto-installs `pipx` if missing)

## License

MIT
