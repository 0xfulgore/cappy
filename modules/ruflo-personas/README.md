# ruflo-personas

Custom-named persona overlays for every installed ruflo agent. Replaces utilitarian names (`ruflo-core:coder`, `ruflo-swarm:architect`, ...) with named characters that carry pronouns, an MBTI archetype, and a voice instruction — and shows the custom name in the Claude Code TUI during agent runs.

## What this does

For each ruflo agent installed on your machine, this module generates a **user-scoped alias agent** at `~/.claude/agents/<slug>.md`. The alias is a self-contained fork: the same tools and same body as the underlying ruflo agent, with a persona overlay (name, pronouns, MBTI, voice) prepended. The Claude Code TUI displays the alias name during runs.

Because each alias is a **fork** — not a delegator — it keeps working even if ruflo is uninstalled later. Upgrade-safety is handled by a SessionStart hook that re-renders aliases against fresh ruflo prompts when the underlying version changes.

## Setup flow

```sh
bash ~/.cappy/repo/modules/ruflo-personas/setup-ruflo-personas.sh
```

The script enumerates every installed ruflo agent and offers four choices per agent:

1. **auto-random** — pick from a curated 50-character pool by pronouns + MBTI preference, with a fallback ladder (relax MBTI family first, then pronouns) when the strict filter is empty
2. **browse** — show all 50 grouped by source, pick one
3. **custom** — name + pronouns + MBTI + voice (≤200 chars)
4. **skip** — keep the canonical ruflo name (default)

There's also a top-level "skip everything and keep ruflo defaults" escape hatch if you don't want personas at all.

## The 50-character pool

| Source | Count | Examples |
|---|---|---|
| Star Trek | 10 | Spock, Data, Picard, Janeway, Seven of Nine, Worf |
| Star Wars | 10 | Yoda, Obi-Wan, Leia, Padmé, Luke, Ahsoka |
| LOTR | 10 | Gandalf, Aragorn, Galadriel, Éowyn, Samwise |
| Dune | 8 | Paul Atreides, Lady Jessica, Stilgar, Chani |
| Tech founders | 12 | Jobs, Wozniak, Musk, Gates, Torvalds, Ada Lovelace, Grace Hopper, Margaret Hamilton, Paul Graham, Andreessen, Altman, Patrick Collison |

Each entry has an opinionated MBTI typing + ≤150-char voice line. Tech founders are included by default; you can opt out at setup time.

## Persona fields

| Field | Format |
|---|---|
| name | 1-24 chars (used as TUI display name and alias filename slug) |
| pronouns | `he/him` / `she/her` / `they/them` / `it/its` / custom (≤30 chars) |
| MBTI | 16 standard types, grouped as Analysts / Diplomats / Sentinels / Explorers |
| voice | ≤200 chars, character-counted, sanitized of YAML-breaking sequences |

## File layout

| Path | Purpose |
|---|---|
| `~/.cappy/ruflo-personas.json` | Your persona map (managed by setup script) |
| `~/.claude/agents/<slug>.md` | Generated alias agent files (managed by alias-generator) |
| `~/.cappy/repo/modules/ruflo-personas/personas-pool.json` | The 50-character pool |
| `~/.cappy/repo/modules/ruflo-personas/hooks/driftcheck.sh` | SessionStart hook (registered via settings.json) |

## Upgrade behavior

A **SessionStart** hook runs every time you start Claude Code. It compares the ruflo version stamped in your persona map against the currently installed ruflo. Two flavors of drift:

- **Content drift** (ruflo version changed, agent set unchanged): silently re-renders alias files so they pick up upstream ruflo improvements.
- **Structural drift** (new agents, removed agents, renames): prints a one-line notice telling you to run `--sync`.

The hook is fail-soft: any error inside the hook results in a silent `exit 0`. It will never block session start.

## Commands

| Command | Effect |
|---|---|
| `bash setup-ruflo-personas.sh` | Initial setup (per-agent prompts). Re-runs are safe; existing personas are preserved. |
| `bash setup-ruflo-personas.sh --reset` | Wipe all personas + alias files, then re-run setup. |
| `bash setup-ruflo-personas.sh --sync` | Re-render aliases against current ruflo; prompt only for new agents (structural drift). |

## How Claude actually uses personas

Cappy's `section.md` injects a directive into your CLAUDE.md telling the model: when about to dispatch to a `ruflo-*` agent, check `~/.cappy/ruflo-personas.json` for an alias. If one exists, use `subagent_type: <alias_slug>` instead of the canonical ruflo name. The alias agent is invoked, the persona name shows in the TUI, and the underlying ruflo behavior runs as normal.

## Uninstall

Remove the SessionStart hook entry from `~/.claude/settings.json`, then:

```sh
rm -rf ~/.cappy/ruflo-personas.json
# Remove cappy-managed alias files only (they have a marker comment):
grep -l '<!-- cappy:ruflo-personas:managed -->' ~/.claude/agents/*.md | xargs rm -f
```

## Troubleshooting

**TUI still shows `ruflo-core:coder` even after setup** → check that `~/.claude/agents/<slug>.md` exists. If not, run `bash alias-generator.sh` directly. If the file exists but isn't being picked up, restart Claude Code to refresh its agent registry.

**Hook never fires** → check `~/.claude/settings.json`: the SessionStart hook should reference `bash ~/.cappy/repo/modules/ruflo-personas/hooks/driftcheck.sh`. Run the script manually to test: `bash ~/.cappy/repo/modules/ruflo-personas/hooks/driftcheck.sh`. Silent success is correct (no output = no drift).

**Personas reset themselves on upgrade** → the version stamp in the persona map went stale. Run `--sync` once to re-stamp. If it keeps happening, check that `get_ruflo_version` in `lib/personas-helpers.sh` is reading the right `setup-ruflo.sh`.

**"Refusing to overwrite agent file"** warning → there's a non-cappy file at `~/.claude/agents/<slug>.md`. Move or rename it manually before re-running.
