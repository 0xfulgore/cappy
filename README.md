<div align="center">

```
   ██████╗ █████╗ ██████╗ ██████╗ ██╗   ██╗
  ██╔════╝██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
  ██║     ███████║██████╔╝██████╔╝ ╚████╔╝
  ██║     ██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝
  ╚██████╗██║  ██║██║     ██║        ██║
   ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝
```

### **Stop letting Claude ship vibes-as-code.**

[![CI](https://github.com/0xfulgore/cappy/actions/workflows/ci.yml/badge.svg)](https://github.com/0xfulgore/cappy/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/0xfulgore/cappy?label=version&color=blue)](https://github.com/0xfulgore/cappy/releases)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Made for Claude Code](https://img.shields.io/badge/made%20for-Claude%20Code-7c3aed)](https://claude.com/claude-code)
[![Stars](https://img.shields.io/github/stars/0xfulgore/cappy?style=social)](https://github.com/0xfulgore/cappy/stargazers)

One install. Then Claude **plans before it codes**, **gathers evidence before it explains**, **verifies before it claims done**, and **blocks instead of guesses** when it gets stuck. Plus 14 agent swarm templates, an animated statusline, surgical hooks, and curated MCP servers — all wired up automatically.

```bash
curl -fsSL https://raw.githubusercontent.com/0xfulgore/cappy/main/get-cappy.sh | bash
```

![cappy demo](assets/demo.gif)

</div>

---

## The 30-Second Pitch

You've felt it. Claude confidently says *"This is probably caused by..."* — without reading a single log. It writes 400 lines, declares "all tests pass" without running them, and silently invents `process.env.STRIPE_KEY = "sk_test_xxx"` because it didn't want to bother you for the real one.

Cappy fixes that. Mechanically.

It installs a layered set of guardrails into your CLAUDE.md, hooks, and settings — and a 6-phase SDLC pipeline that turns *"add a user dashboard"* into a real product workflow with approval gates, parallel build agents, and a green Definition-of-Done check before anything is called "done".

Skip any of it any time with `"just do it"`, `"quick fix"`, or `"skip the process"`.

## Before vs. After Cappy

<table>
<tr>
<th>Vanilla Claude Code</th>
<th>Cappy Claude Code</th>
</tr>
<tr>
<td>

```
You: why does the API return 500?

Claude: This is probably caused by
a misconfigured CORS header. Let me
fix that for you...

[edits 4 files, breaks auth]
```

</td>
<td>

```
You: why does the API return 500?

Claude: [reads logs first]
        [greps for the error]
        [opens the handler]

→ Cited: api/orders.ts:84
→ NULL value crashes JSON.stringify
  on the audit_log path.
```

</td>
</tr>
<tr>
<td>

```
Claude: All done! Tests pass. ✅
```

</td>
<td>

```
Claude: BLOCKED.

  ✗ tsc --noEmit  (3 errors)
  ✓ eslint --quiet
  ✗ vitest run    (2 failing)

Won't say "done" until gates pass.
```

</td>
</tr>
</table>

## What Cappy Stops Claude From Doing

> The whole toolkit can be summed up by what it forbids.

- ✗ Pattern-matching causes from training → **must cite a tool call in the same turn**
- ✗ Hedging with *"probably"*, *"I think"*, *"seems"* → **rejected by a Stop hook**
- ✗ Claiming "done" before tests run → **blocked by a 5-gate Definition of Done**
- ✗ Burning context on 50-file refactors → **mandatory swarm split above the threshold**
- ✗ Editing files from stale memory after compaction → **forced re-reads**
- ✗ Inventing placeholder credentials in autopilot → **emits `BLOCKED:` instead**
- ✗ Force-pushing to main → **git-safety hook stops it**
- ✗ Writing to `.env` or credentials files → **file-guard hook stops it**

## Quick Start

```bash
# install once
curl -fsSL https://raw.githubusercontent.com/0xfulgore/cappy/main/get-cappy.sh | bash

# then in any project, just use Claude normally
cd ~/your-project
claude "add a user dashboard with analytics"
# → discovers → specs → designs → 🔒 approval → builds → reviews → validates
```

The bootstrap clones cappy to `~/.cappy/repo/` and hands off to `cappy boot`. The installer asks where your projects live (e.g. `~/Development`), drops a CLAUDE.md there, and Claude Code picks it up in every subdirectory below.

Manual: `git clone https://github.com/0xfulgore/cappy.git && cd cappy && ./install.sh`
Branch pin: `CAPPY_BRANCH=develop bash`
CI mode: `cappy install --non-interactive --preset power-user`
Subset: `--modules core,statusline,hooks`

## The 6-Phase SDLC Pipeline

Type a feature request. Claude refuses to start coding. Instead it produces a Research Brief with open questions, then a PRD with Given/When/Then acceptance criteria, then a numbered task design — each with an explicit user approval gate. Then it builds, reviews, and validates against the gates.

```
User idea
   ↓
[ Scout ]      Discovery — codebase scan + research brief
   ↓
[ Spec ]       PRD with Given/When/Then       🔒 USER APPROVAL
   ↓
[ Architect ]  Schema, API contracts, tasks   🔒 USER APPROVAL
   ↓
[ Engineers ]  Backend + Frontend in parallel
   ↓
[ Reviewer ]   Code quality + OWASP audit
   ↓
[ QA ]         All Definition-of-Done gates run
   ↓
   Ship.
```

## 14 Ready-Made Agent Swarms

```bash
~/.cappy/scaffold-team.sh product-sdlc \
  --name dashboard \
  --description "User analytics dashboard" \
  --tech "Next.js 15, Supabase"
```

| Use when… | Template | Agents |
|---|---|---|
| Shipping a real feature | `product-sdlc` | 8 |
| Auditing a codebase | `audit-sweep` | 8 |
| Production is on fire | `incident-responder` | 5 |
| Migrating schema or framework | `migration-squad` | 6 |
| Pages are slow | `perf-clinic` | 5 |
| Coverage is shrinking | `test-factory` | 5 |
| Bumping major versions | `dependency-upgrade` | 5 |
| Versioning an API v1 → v2 | `api-versioning` | 5 |
| Onboarding a new dev | `onboarding-guide` | 5 |
| Writing docs in a sprint | `docs-sprint` | 4 |
| …plus | `monorepo-splitter`, `code-review`, `refactor-squad`, `fullstack-api` | 3–6 |

Each swarm has named handoffs, role-specific context, and approval gates baked in. Failures from Review or QA loop back to engineers until clean.

## The Animated Statusline

Every Claude session sits inside this:

```
opus-4.7  ▓▓▓▓▓▓▓░░░ 71%   main ✓+3   tasks ▓▓▓▓░░ 4/6   $0.42   12m   ↑ cappy v3.2.0
```

Model · context window % · git branch · dirty state · lines changed · live task progress with ETA · session cost · duration · update notifier (single `git ls-remote`, ~200 ms, async — never blocks your prompt).

## Hooks That Catch You In The Act

| Hook | Trigger | What it does |
|---|---|---|
| `post-edit-typecheck.sh` | After `.ts`/`.tsx` edits | Runs `tsc --noEmit` |
| `post-edit-lint.sh` | After file edits | Auto-runs ESLint / Biome / Ruff / Clippy |
| `pre-commit-check.sh` | Before `git commit` | Type-check + lint + tests gate |
| `file-guard.sh` | Before file writes | Blocks edits to `.env`, credentials, keys |
| `hedge-rejector.mjs` | Stop event | Rejects responses containing *"probably / I think / seems / could be"* |

## Curated MCP Servers

Opt in per server during install — cappy wires the auth.

| Server | What it provides | Auth |
|---|---|---|
| **GitHub** | PR/issue management, code search | `gh auth` token or env |
| **Linear** | Auto-claim tickets, transition status, comment on blockers, attach PR URLs | OAuth via browser |
| **PostgreSQL** | Database queries and exploration | Connection string |
| **Playwright** | Browser automation and testing | None |

> Mention `ENG-123` in a prompt and Claude claims the ticket, moves it to In Progress, comments on blockers, and transitions it to your chosen terminal status with the PR URL attached. No fabricated IDs — if Linear MCP isn't connected, it says so.

## Persistent Memory & Autopilot

The opt-in `ruflo` and `mempalace` modules add:

- **`/autopilot enable`** — autonomous task loops that schedule their own wake-ups
- **`/swarm init`** — multi-agent dispatch with persistent AgentDB
- **`/watch`** — live event stream from running agents
- **MemPalace** — local-first semantic memory that survives across sessions

Claude offers autopilot inline whenever a task hits the swarm threshold (>10 files, >300 LOC, or >2 subsystems). Configure prompting via `~/.cappy/ruflo-preferences.json` (`always` / `ask` / `never`).

## All 17 Modules

Install all by default, or pick a subset with `--modules`.

| Module | What it adds |
|---|---|
| **core** | SDLC pipeline + 19 mechanical overrides — the engine |
| **auto-update** | `cappy` CLI shim + 24 h update notifier |
| **statusline** | Animated status bar with progress, cost, ETA |
| **settings** | settings.json presets — power-user, cautious, team-lead |
| **hooks** | Post-edit typecheck, auto-lint, pre-commit gate, file guard |
| **hedge-detector** | Stop hook that rejects hedging language |
| **git-safety** | Block force-push to main, conventional commit hints |
| **mcp** | GitHub, Linear (OAuth), PostgreSQL, Playwright |
| **teams** | 14 agent swarm templates |
| **skills** | Task progress dashboard, skill discovery |
| **templates** | Per-project CLAUDE.md generators (React, Rust, Python, Expo, generic) |
| **performance** | Bundle size, N+1 queries, lazy loading, pagination |
| **accessibility** | WCAG 2.2 AA defaults |
| **devops** | CI/CD, env var safety, Docker, migration discipline |
| **api-design** | REST conventions, input validation, versioning |
| **ruflo** | Ruflo agent platform: marketplace + 8 plugins + MCP |
| **mempalace** | Local-first AI memory with semantic search |

**Opt-in (not in "install all")**

| Module | What it adds |
|---|---|
| **huashu-design** | HTML hi-fi prototyping skill ([alchaincyf/huashu-design](https://github.com/alchaincyf/huashu-design)) |
| **frontend-design** | Anthropic's official frontend skill ([anthropics/claude-code](https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design)) |
| **cua-driver** | macOS app driver ([trycua/cua](https://github.com/trycua/cua)) |

## Settings Presets

| Preset | Permissions | Teams | Auto-Dream | Safety |
|---|---|---|---|---|
| **power-user** | Full | ✓ | On | `rm -rf` blocked |
| **cautious** | Read + Edit only | ✗ | Off | Bash restricted, secrets blocked |
| **team-lead** | Full | ✓ | On | `rm -rf` blocked |

<details>
<summary><b>The 19 mechanical overrides (full list)</b></summary>

Each rule is a separately-toggleable section in your CLAUDE.md.

**Pre-Work**
1. **Evidence Before Explanation** — first action must be a tool call gathering evidence; no causal claims without citations
2. **Step 0 Cleanup** — remove dead code before refactoring
3. **Phased Execution** — max 5 files per phase, verify between phases

**Code Quality**
4. **Senior Dev Override** — fix architectural flaws, don't just follow orders
5. **Fix As You Go** — broken thing found mid-task gets fixed immediately, no defer lists
6. **Forced Verification** — must run type-check + lint before declaring done
6a. **Linear Ticket Workflow** — auto-claim, transition status, comment on blockers, attach PR URLs

**Context Management**
7. **Sub-Agent Swarming** — parallel agents for tasks >5 files
7a. **Prefer Ruflo Swarms For Team Work** — route team/swarm work through Ruflo when present
7b. **Mandatory Swarm Split** — force a swarm when work exceeds >10 files / >300 LOC / >8 design tasks / >2 h / >2 subsystems
8. **Context Decay Awareness** — re-read files after 10+ messages
9. **File Read Budget** — 2,000-line cap, chunk large files
10. **Tool Result Blindness** — detect truncated results, narrow scope

**Edit Safety**
11. **Edit Integrity** — read before/after every edit, verify changes applied
12. **No Semantic Search** — grep isn't AST; search all reference types separately

**Definition of Done**
13. **Verify Before Claiming Done** — read actual output yourself; never trust "agent said done"
14. **Definition of Done** — type-check, lint, test, build, coverage gates must ALL pass

**Default Workflow**
15. **SDLC by Default** — all non-trivial tasks follow the 6-phase pipeline with user approval gates

The `performance`, `accessibility`, `devops`, and `api-design` modules add four more rule clusters (16–19) on top of core when installed.

</details>

<details>
<summary><b>The <code>cappy</code> CLI</b></summary>

```bash
cappy update           # interactive: pull latest tag + reinstall
cappy update --yes     # non-interactive
cappy status           # local SHA, latest SHA, behind count, last-checked
cappy check            # force fresh remote check (bypasses 24 h cache)
cappy version          # print installed cappy version
cappy help             # splash + usage
cappy uninstall        # remove cappy-managed sections, restore from backup
```

**Update notifications**
- Statusline reads `~/.cappy/update-status.json`. If older than 24 h, it fires a single `git ls-remote` async/detached so the prompt never blocks.
- When an update is available, the statusline shows `↑ cappy v1.2.3`. First sighting per day is bold; later same-day renders are dimmer to avoid noise.
- Offline / network errors → silent.

**Where the binary lives**
- Shim: `~/.cappy/repo/bin/cappy`
- PATH symlink: `~/.local/bin/cappy` (auto-created only if `~/.local/bin` already exists; install never modifies your shell rc files)

</details>

<details>
<summary><b>How updates and uninstalls work (non-destructive)</b></summary>

- **Marker-based CLAUDE.md** — sections wrapped in `<!-- cappy:section:NAME -->` are replaced surgically; your hand-written content outside the markers is preserved
- **JSON merging** — settings deep-merged via `jq`; arrays unioned, objects recursively merged. Malformed `settings.json` aborts the merge with a clear error rather than truncating
- **File collision detection** — SHA256 comparison. Identical files skipped; conflicts prompt (skip / overwrite / keep both as `.bak`)
- **Backups** — every install writes to `~/.claude/backups/cappy-<timestamp>/` first
- **Idempotent** — re-running the installer is safe; already-installed bits are detected and skipped
- **Module manifests** — each module has a `module.json` declaring its files, targets, settings fragment, and dependencies

`cappy update` pulls the latest tag, then re-runs the installer. Existing modules are re-applied silently; modules added since your last install are listed so you can opt in. `cappy uninstall` removes cappy-managed CLAUDE.md sections and hook files; offers to restore from backup. Your `settings.json` is preserved (remove cappy entries manually if needed).

</details>

<details>
<summary><b>Versioning & releases</b></summary>

Cappy follows [semantic versioning](https://semver.org/). The auto-update notifier is **release-based** — published tags trigger the `↑ cappy v1.2.3` segment. Bug-fix commits between releases don't nag users until you cut a new tag.

If no semver tags exist on the remote yet, the notifier falls back to commit mode (`↑ cappy +N` commits behind `main`). The moment any `vX.Y.Z` tag lands, it auto-switches to tag mode on the next 24 h check.

| Bump | When | Examples |
|---|---|---|
| **MAJOR** | Breaking changes — module removed, incompatible config | dropping bash 3.2, marker-format change |
| **MINOR** | New modules, new features, backward-compatible | new agent template, the auto-update module |
| **PATCH** | Bug fixes, docs, internal cleanups | jq merge fix, README updates |

```bash
./release.sh patch              # 1.0.0 → 1.0.1
./release.sh minor              # 1.0.0 → 1.1.0
./release.sh major              # 1.0.0 → 2.0.0
./release.sh 1.2.3              # explicit version
./release.sh patch --dry-run    # preview
./release.sh minor --gh         # also `gh release create`
```

The script refuses dirty trees and off-`main` (unless you confirm), bumps `forge.json`, builds a changelog from commits since the last tag, commits `release: vX.Y.Z`, creates an annotated tag, pushes both, and optionally creates a GitHub release.

</details>

<details>
<summary><b>Verifying release integrity</b></summary>

Each cappy release publishes a SHA-256 checksum of its source tarball in the GitHub release notes.

```bash
gh release view v3.2.0 --json body | jq -r .body | grep -A2 "SHA-256"
```

Manual:
1. Download: `https://github.com/0xfulgore/cappy/archive/refs/tags/vX.Y.Z.tar.gz`
2. `shasum -a 256 cappy-X.Y.Z.tar.gz` (macOS) or `sha256sum` (Linux)
3. Compare against the `SHA-256` value in the release notes — must match exactly.

**Honest limitation:** checksum-only verification confirms the tarball wasn't corrupted in transit, but isn't a full chain-of-trust guarantee. An attacker who compromises the GitHub repository can publish both a malicious tarball and a matching checksum. GPG-signed tags verifiable with `git verify-tag` is tracked as a future improvement.

</details>

<details>
<summary><b>Regenerating the demo GIF</b></summary>

The demo at the top is generated from [`assets/demo.sh`](assets/demo.sh) (the visual content) and [`.github/demo.tape`](.github/demo.tape) (the VHS recording script):

```bash
brew install vhs
vhs .github/demo.tape       # writes assets/demo.gif
```

Edit `assets/demo.sh` to change what's shown. It's pure `printf` with no network or side effects, so re-recording is deterministic.

</details>

## Requirements

- Claude Code CLI installed
- `jq` (installer offers to install it)
- `bash` 3.2+ — works with macOS-shipped bash; bash 4+ also fine
- `git` for clone-based install and updates
- `node` (only for `hedge-detector`)
- `python3` + `pipx` (only for `mempalace` — auto-installs `pipx` if missing)

## Contributing

Issues, PRs, and new agent swarm templates are welcome. CI runs `bash -n`, `shellcheck`, and `jq` validation on every push.

## License

[MIT](LICENSE) — go nuts.
