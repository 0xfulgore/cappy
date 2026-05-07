#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# get-cappy — one-shot bootstrap
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/0xfulgore/cappy/main/get-cappy.sh | bash
#
# Pin a branch:
#   curl -fsSL .../get-cappy.sh | CAPPY_BRANCH=develop bash
#
# This script does the minimum: clone the repo, then exec `cappy boot`
# which is the real installer. The split keeps the curl-pipe surface
# tiny and lets the bulk of install logic live in the cloned tree.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

CAPPY_HOME="${CAPPY_HOME:-$HOME/.cappy}"
CAPPY_REPO="${CAPPY_REPO:-$CAPPY_HOME/repo}"
CAPPY_GIT_URL="${CAPPY_GIT_URL:-https://github.com/0xfulgore/cappy.git}"
CAPPY_BRANCH="${CAPPY_BRANCH:-main}"

if [[ -t 1 ]]; then
  RST=$'\e[0m'; BOLD=$'\e[1m'; DIM=$'\e[2m'
  CYAN=$'\e[36m'; BRIGHT_CYAN=$'\e[96m'
  GREEN=$'\e[32m'; RED=$'\e[31m'
  BRIGHT_MAGENTA=$'\e[95m'
else
  RST=""; BOLD=""; DIM=""; CYAN=""; BRIGHT_CYAN=""
  GREEN=""; RED=""; BRIGHT_MAGENTA=""
fi

err()  { printf '%s[err]%s  %s\n' "$RED" "$RST" "$*" >&2; }
ok()   { printf '%s[ ok]%s  %s\n' "$GREEN" "$RST" "$*"; }
info() { printf '%s[info]%s %s\n' "$CYAN" "$RST" "$*"; }
step() { printf '\n%s━━ %s%s\n' "$BRIGHT_CYAN" "$*" "$RST"; }

printf '\n   %s%scappy%s %s— bootstrapping...%s\n' "$BRIGHT_MAGENTA" "$BOLD" "$RST" "$DIM" "$RST"

# ── Dep check ────────────────────────────────────────────────
for cmd in git bash; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "'$cmd' is required but not on PATH"
    exit 1
  fi
done

# ── Clone or update ──────────────────────────────────────────
if [[ -d "$CAPPY_REPO/.git" ]]; then
  step "Cappy repo already at $CAPPY_REPO — pulling latest"
  if ! git -C "$CAPPY_REPO" pull --ff-only --quiet; then
    err "git pull failed (non-fast-forward?). Resolve in $CAPPY_REPO and re-run."
    exit 2
  fi
  ok "up to date"
else
  step "Cloning Cappy → $CAPPY_REPO"
  mkdir -p "$CAPPY_HOME"
  if ! git clone --quiet --branch "$CAPPY_BRANCH" "$CAPPY_GIT_URL" "$CAPPY_REPO"; then
    err "git clone failed for $CAPPY_GIT_URL (branch: $CAPPY_BRANCH)"
    exit 3
  fi
  ok "cloned"
fi

# ── Hand off to cappy boot ───────────────────────────────────
chmod +x "$CAPPY_REPO/bin/cappy" "$CAPPY_REPO/lib/update-check.sh" 2>/dev/null || true

if [[ ! -x "$CAPPY_REPO/bin/cappy" ]]; then
  err "cappy shim missing or not executable at $CAPPY_REPO/bin/cappy"
  err "this branch may predate the auto-update module — run install.sh manually:"
  err "  bash $CAPPY_REPO/install.sh"
  exit 4
fi

step "Running cappy boot"
exec "$CAPPY_REPO/bin/cappy" boot "$@"
