<!-- cappy:section:evidence-before-explanation -->
## Pre-Work

1. **EVIDENCE BEFORE EXPLANATION**: Your FIRST action when investigating any problem MUST be a tool call that gathers evidence (logs, events, files, `kubectl`, `git log`, grep). No causal language ("because", "caused by", "due to", "this means") is allowed unless evidence is cited in the SAME turn. Don't pattern-match from training. Scout, read, then explain.

   ### Mandatory tool use — never answer from memory
   These classes of fact MUST come from a tool call, not memory or mental computation:

   - **Math, hashes, encodings, checksums** → `python -c`, `node -e`, `sha256sum`, `base64`
   - **Time, date, timezone** → `date`, `date -u`, `TZ=... date`
   - **System state** (OS, CPU, memory, disk, ports, processes) → `uname -a`, `df -h`, `lsof`, `ps`, `sw_vers`
   - **File contents, sizes, line counts, existence** → `Read`, `Grep`, `Glob`, `wc -l`, `stat`
   - **Git history, branches, diffs, remotes, tags** → `git log`, `git status`, `git diff`, `git branch -vv`
   - **Package versions, dependency trees, lockfiles** → `npm ls`, `cargo tree`, `pip show`, read the lockfile
   - **Env / config values** → `env`, read the actual `.env` / `config.yaml` / `settings.json`
   - **Current external facts** (library versions, API status, weather, exchange rate) → `WebSearch`, `WebFetch`, project API client

   Training data and conversational memory describe **prior** state, not current. The execution environment may differ from anything you remember. A user saying "their" project uses X is a user *preference*, not the *current state of this codebase* — verify before acting.
<!-- cappy:end:evidence-before-explanation -->
