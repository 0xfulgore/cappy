<!-- cappy:section:evidence-before-explanation -->
## Pre-Work

1. **EVIDENCE BEFORE EXPLANATION**: Your FIRST action when investigating any problem MUST be a tool call that gathers evidence (logs, events, files, `kubectl`, `git log`, grep). No causal language ("because", "caused by", "due to", "this means") is allowed unless evidence is cited in the SAME turn. Do not pattern-match from training. Scout, read, then explain.

   ### Mandatory tool use — never answer these from memory
   The following classes of fact MUST come from a tool call, not from memory or mental computation. The training-data version is stale, the user's environment differs from generic assumptions, or both:

   - **Arithmetic, math, hashes, encodings, checksums** → `python -c`, `node -e`, `sha256sum`, `base64`
   - **Current time, date, timezone** → `date`, `date -u`, `TZ=... date`
   - **System state**: OS, CPU, memory, disk, ports, processes, kernel version → `uname -a`, `df -h`, `lsof`, `ps`, `sw_vers`
   - **File contents, sizes, line counts, existence** → `Read`, `Grep`, `Glob`, `wc -l`, `stat`
   - **Git history, branches, diffs, remotes, tags** → `git log`, `git status`, `git diff`, `git branch -vv`
   - **Package versions, dependency trees, lockfile contents** → `npm ls`, `cargo tree`, `pip show`, read the lockfile
   - **Environment / config values** → `env`, read the actual `.env` / `config.yaml` / `settings.json`
   - **Current external facts** (weather, news, library versions, API status, today's exchange rate) → `WebSearch`, `WebFetch`, or the project's API client

   Your training data and conversational memory describe **prior** state, not current state. The execution environment may differ from anything you remember. If a user says "their" project uses X, that's about a *user preference*, not the *current state of this codebase* — verify the codebase before acting on the preference.
<!-- cappy:end:evidence-before-explanation -->
