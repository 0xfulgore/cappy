#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# auto-update module — post-install
# Makes the cappy shim executable and (optionally) symlinks it
# onto PATH via ~/.local/bin/cappy.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

CAPPY_HOME="${CAPPY_HOME:-$HOME/.cappy}"

# Prefer CAPPY_REPO from env (install.sh exports it). Fall back to the
# canonical ~/.cappy/repo (curl-pipe install). Last resort: derive from
# this script's location (we sit at <repo>/modules/auto-update/setup.sh).
if [[ -z "${CAPPY_REPO:-}" || ! -d "${CAPPY_REPO}/.git" && ! -f "${CAPPY_REPO}/forge.json" ]]; then
  if [[ -d "$CAPPY_HOME/repo/.git" ]] || [[ -f "$CAPPY_HOME/repo/forge.json" ]]; then
    CAPPY_REPO="$CAPPY_HOME/repo"
  else
    derived="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    if [[ -f "$derived/forge.json" ]]; then
      CAPPY_REPO="$derived"
    fi
  fi
fi

if [[ -z "${CAPPY_REPO:-}" ]] || [[ ! -f "$CAPPY_REPO/forge.json" ]]; then
  printf '[err]  cannot locate cappy repo — set CAPPY_REPO env var to the repo root\n' >&2
  exit 1
fi

SHIM="$CAPPY_REPO/bin/cappy"
CHECKER="$CAPPY_REPO/lib/update-check.sh"

if [[ ! -f "$SHIM" ]]; then
  printf '[err]  cappy shim missing at %s — module is broken\n' "$SHIM" >&2
  exit 1
fi
if [[ ! -f "$CHECKER" ]]; then
  printf '[err]  update-check missing at %s — module is broken\n' "$CHECKER" >&2
  exit 1
fi

chmod +x "$SHIM" "$CHECKER" 2>/dev/null || true

# Symlink into ~/.local/bin if the dir already exists (most modern macOS/Linux
# setups have it on PATH via Homebrew, asdf, pipx, or a manual entry). We do
# NOT create the dir or modify rc files — that's the user's call.
LOCAL_BIN="$HOME/.local/bin"
TARGET="$LOCAL_BIN/cappy"

if [[ -d "$LOCAL_BIN" ]]; then
  if [[ -L "$TARGET" ]]; then
    # Existing symlink — refresh it (handles repo path changes after re-install)
    ln -sfn "$SHIM" "$TARGET"
    printf '[  ok]  refreshed symlink %s → %s\n' "$TARGET" "$SHIM"
  elif [[ -e "$TARGET" ]]; then
    printf '[warn]  %s exists and is not a symlink — leaving it alone\n' "$TARGET"
    printf '[info]  run cappy directly via: %s\n' "$SHIM"
  else
    ln -s "$SHIM" "$TARGET"
    printf '[  ok]  linked %s → %s\n' "$TARGET" "$SHIM"
  fi
else
  printf '[info]  ~/.local/bin not present — skipping PATH symlink\n'
  printf '[info]  add cappy to PATH manually:\n'
  printf '          mkdir -p ~/.local/bin && ln -s %s ~/.local/bin/cappy\n' "$SHIM"
  printf '          # then ensure ~/.local/bin is on PATH in your shell rc\n'
  printf '[info]  or run directly: %s\n' "$SHIM"
fi
