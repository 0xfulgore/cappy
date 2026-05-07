#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Update check
# Background-safe: writes ~/.cappy/update-status.json
# Designed to run async from the statusline. Fails silent on any
# error so a flaky network never breaks shell rendering.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
[[ -z "$branch" ]] && exit 0

upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "origin/$branch")
upstream_branch="${upstream#*/}"

remote_sha=$(git ls-remote --quiet "$remote_url" "refs/heads/$upstream_branch" 2>/dev/null | awk 'NR==1{print $1}')
[[ -z "$remote_sha" ]] && exit 0

local_sha=$(git rev-parse HEAD 2>/dev/null || true)
[[ -z "$local_sha" ]] && exit 0

behind=0
available=false
if [[ "$local_sha" != "$remote_sha" ]]; then
  available=true
  git fetch --quiet origin "$upstream_branch" 2>/dev/null || true
  behind=$(git rev-list --count "HEAD..$remote_sha" 2>/dev/null || echo 0)
  [[ -z "$behind" ]] && behind=0
fi

dirty=false
[[ -n "$(git status --porcelain 2>/dev/null | head -1)" ]] && dirty=true

ver="?"
if [[ -f "$CAPPY_REPO/forge.json" ]] && command -v jq >/dev/null 2>&1; then
  ver=$(jq -r '.version // "?"' "$CAPPY_REPO/forge.json" 2>/dev/null || echo "?")
fi

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Atomic write: temp file + mv
tmp="$STATUS_FILE.tmp.$$"
cat > "$tmp" <<EOF
{
  "checked_at": "$ts",
  "current_sha": "$local_sha",
  "latest_sha": "$remote_sha",
  "behind_count": $behind,
  "available": $available,
  "dirty": $dirty,
  "version": "$ver",
  "branch": "$branch",
  "remote_url": "$remote_url"
}
EOF
mv "$tmp" "$STATUS_FILE" 2>/dev/null || rm -f "$tmp"
