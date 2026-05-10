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
  GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'
  BRIGHT_MAGENTA=$'\e[95m'
else
  RST=""; BOLD=""; DIM=""; CYAN=""; BRIGHT_CYAN=""
  GREEN=""; RED=""; YELLOW=""; BRIGHT_MAGENTA=""
fi

err()  { printf '%s[err]%s  %s\n' "$RED" "$RST" "$*" >&2; }
ok()   { printf '%s[ ok]%s  %s\n' "$GREEN" "$RST" "$*"; }
info() { printf '%s[info]%s %s\n' "$CYAN" "$RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$RST" "$*" >&2; }
step() { printf '\n%s━━ %s%s\n' "$BRIGHT_CYAN" "$*" "$RST"; }

# ── CAPPY_BRANCH validation ───────────────────────────────────
# Permit conventional git branch names: letters, digits, . _ / -
# Reject shell-metachar payloads (semicolons, spaces, $, backticks, etc.)
if [[ ! "$CAPPY_BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  err "CAPPY_BRANCH contains invalid characters: '$CAPPY_BRANCH'"
  err "Allowed characters: letters, digits, . _ / -"
  exit 1
fi

# Warn and require explicit interactive confirmation for non-main branches.
if [[ "$CAPPY_BRANCH" != "main" ]]; then
  warn "CAPPY_BRANCH is set to '$CAPPY_BRANCH' (not main)."
  warn "You will install code from a non-default branch."
  if [[ -t 0 ]]; then
    printf '         Continue? (y/N) ' >&2
    read -r _branch_confirm
    case "$_branch_confirm" in
      y|Y|yes|YES) ;;
      *)
        err "Aborted by user."
        exit 1
        ;;
    esac
  else
    err "Non-interactive mode: cannot confirm non-main branch."
    err "Set CAPPY_BRANCH=main or run interactively."
    exit 1
  fi
fi

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

  # The canonical clone is machine-managed — users shouldn't be
  # editing it directly. If we find dirty state (typical cause: an
  # earlier failed install or someone testing locally), stash it
  # automatically so we can fast-forward. The stash is recoverable
  # via `git -C ~/.cappy/repo stash list`. Better than aborting and
  # telling the user to fix a directory they don't own.
  if [[ -n "$(git -C "$CAPPY_REPO" status --porcelain)" ]]; then
    info "Local changes detected in $CAPPY_REPO — auto-stashing before pull"
    if ! git -C "$CAPPY_REPO" stash push --include-untracked \
         -m "cappy auto-rescue $(date +%Y%m%d-%H%M%S)" --quiet; then
      err "could not stash local changes in $CAPPY_REPO"
      err "recover manually: cd $CAPPY_REPO && git status"
      exit 2
    fi
    ok "stashed (recover via: git -C $CAPPY_REPO stash list)"
  fi

  if ! git -C "$CAPPY_REPO" pull --ff-only --quiet; then
    # Still failing after stash — likely diverged history. Last
    # resort: hard-reset to origin/main. The clone is meant to be
    # canonical, so any divergence here is unexpected and recoverable
    # via the stash above (if that's what was lost).
    info "fast-forward failed — resetting to origin/$CAPPY_BRANCH"
    if ! git -C "$CAPPY_REPO" fetch --quiet origin "$CAPPY_BRANCH" || \
       ! git -C "$CAPPY_REPO" reset --hard --quiet "origin/$CAPPY_BRANCH"; then
      err "could not sync $CAPPY_REPO with origin/$CAPPY_BRANCH"
      err "wipe and reclone: rm -rf $CAPPY_REPO && rerun this command"
      exit 2
    fi
    ok "reset to origin/$CAPPY_BRANCH"
  else
    ok "up to date"
  fi
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

# DO NOT redirect stdin here. Under `curl … | bash`, bash is reading
# this script from fd 0 (the curl pipe). Redirecting fd 0 mid-script
# would make bash try to read the rest of get-cappy.sh from the new
# source (e.g. /dev/tty), which silently hangs waiting for keyboard
# "input" that's really meant to be more script. install.sh handles
# stdin reattachment itself — and it's safe there because install.sh
# is loaded from a real file, not stdin.
exec "$CAPPY_REPO/bin/cappy" boot "$@"
