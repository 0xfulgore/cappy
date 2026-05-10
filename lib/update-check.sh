#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Update check
# Background-safe: writes ~/.cappy/update-status.json
# Designed to run async from the statusline. Fails silent on any
# error so a flaky network never breaks shell rendering.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# ── Supply-chain trust notice ────────────────────────────────
# The auto-update mechanism detects new releases via git ls-remote.
# Applying an update uses `git pull --ff-only` from 0xfulgore/cappy
# (triggered by `cappy update`). This script only DETECTS availability;
# it does NOT apply changes automatically.
#
# IMPORTANT: there is currently NO signature verification on tags or
# commits. The update check trusts whatever the remote reports.
# An attacker with write access to the upstream repo could serve a
# malicious release and this script would report it as valid.
#
# Users who want stronger integrity guarantees should:
#   1. Pin to a known-good tag:
#        cd ~/.cappy/repo && git checkout vX.Y.Z
#   2. Review changes before applying:
#        git fetch origin && git log HEAD..origin/main --oneline
#        git diff HEAD origin/main
#   3. Verify the SHA-256 checksum published in each GitHub release's
#      notes before running `cappy update`.
#   4. Await GPG-signed tag support (tracked: audit-06 CRIT-4, planned
#      for a future release) — then verify with `git verify-tag vX.Y.Z`.
#
# This is a deliberate documented limitation (checksum-only path,
# introduced in v2.3.0), not an oversight.
# ────────────────────────────────────────────────────────────

CAPPY_HOME="${CAPPY_HOME:-$HOME/.cappy}"
CAPPY_REPO="${CAPPY_REPO:-$CAPPY_HOME/repo}"
STATUS_FILE="$CAPPY_HOME/update-status.json"
STAMP_FILE="$CAPPY_HOME/.last-update-check"
LOCK_TTL=3600  # never re-fire the network call within 1h regardless of TTL

[[ -d "$CAPPY_REPO/.git" ]] || exit 0
command -v git >/dev/null 2>&1 || exit 0
mkdir -p "$CAPPY_HOME" 2>/dev/null || exit 0

if [[ -f "$STAMP_FILE" ]]; then
  age=$(( $(date +%s) - $(stat -f %m "$STAMP_FILE" 2>/dev/null || stat -c %Y "$STAMP_FILE" 2>/dev/null || echo 0) ))
  (( age < LOCK_TTL )) && exit 0
fi
touch "$STAMP_FILE" 2>/dev/null || exit 0

cd "$CAPPY_REPO" 2>/dev/null || exit 0

remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
[[ -z "$remote_url" ]] && exit 0

# Strip embedded credentials (https://user:token@host → https://host)
# so they are never persisted to the world-readable status file.
remote_url=$(printf '%s' "$remote_url" | sed 's|://[^@]*@|://|')

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
[[ -z "$branch" ]] && exit 0

local_sha=$(git rev-parse HEAD 2>/dev/null || true)
[[ -z "$local_sha" ]] && exit 0

# ── Discover latest semver tag from remote ──────────────────
# Filter to refs/tags/vX.Y.Z (or X.Y.Z), strip the prefix, sort -V.
# If no tags exist yet, this is empty and we report "no release yet".
latest_tag=$(git ls-remote --tags --refs "$remote_url" 2>/dev/null \
  | awk '{print $2}' \
  | sed 's|refs/tags/||' \
  | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n 1 || true)

# ── Discover installed version ───────────────────────────────
# Prefer the version cappy actually installed (in installed.json) over
# whatever's currently on disk in forge.json — those can diverge if the
# repo was pulled but install.sh hasn't been re-run.
installed_ver=""
if [[ -f "$CAPPY_HOME/installed.json" ]] && command -v jq >/dev/null 2>&1; then
  installed_ver=$(jq -r '.cappy_version // empty' "$CAPPY_HOME/installed.json" 2>/dev/null || true)
fi
if [[ -z "$installed_ver" || "$installed_ver" == "null" ]] && [[ -f "$CAPPY_REPO/forge.json" ]] && command -v jq >/dev/null 2>&1; then
  installed_ver=$(jq -r '.version // "0.0.0"' "$CAPPY_REPO/forge.json" 2>/dev/null || echo "0.0.0")
fi
[[ -z "$installed_ver" || "$installed_ver" == "null" ]] && installed_ver="0.0.0"

# ── Tag-based comparison only ────────────────────────────────
# Releases are the source of truth. If the remote has zero semver tags
# (e.g. a fork pre-first-release), the checker stays silent — no commit
# tracking, no notifications until someone tags a release.
available=false

if [[ -n "$latest_tag" ]]; then
  inst_clean="${installed_ver#v}"
  latest_clean="${latest_tag#v}"
  if [[ "$inst_clean" != "$latest_clean" ]]; then
    newer=$(printf '%s\n%s\n' "$inst_clean" "$latest_clean" | sort -V | tail -n 1)
    [[ "$newer" == "$latest_clean" ]] && available=true
  fi
fi

dirty=false
[[ -n "$(git status --porcelain 2>/dev/null | head -1)" ]] && dirty=true

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Atomic write: temp file + mv
tmp="$STATUS_FILE.tmp.$$"
cat > "$tmp" <<EOF
{
  "checked_at": "$ts",
  "installed_version": "$installed_ver",
  "latest_version": "${latest_tag:-}",
  "available": $available,
  "current_sha": "$local_sha",
  "dirty": $dirty,
  "branch": "$branch",
  "remote_url": "$remote_url"
}
EOF
mv "$tmp" "$STATUS_FILE" 2>/dev/null || rm -f "$tmp"
chmod 600 "$STATUS_FILE" 2>/dev/null || true
