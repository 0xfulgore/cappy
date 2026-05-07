#!/usr/bin/env bash
# Cappy — MemPalace setup
# Idempotent installer for the MemPalace pip package + MCP server.
# Skips anything already installed; only adds what is missing.
#
# Upstream: https://github.com/MemPalace/mempalace
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/../../lib/common.sh" ]]; then
  # shellcheck source=../../lib/common.sh
  source "${SCRIPT_DIR}/../../lib/common.sh"
else
  log_info()    { printf "[info]  %s\n" "$*"; }
  log_success() { printf "[  ok]  %s\n" "$*"; }
  log_warn()    { printf "[warn]  %s\n" "$*"; }
  log_error()   { printf "[ err]  %s\n" "$*" >&2; }
fi

MEMPALACE_PKG="mempalace"
MEMPALACE_MCP_NAME="mempalace"
MEMPALACE_MCP_BIN="mempalace-mcp"

# ── Prerequisites ────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  log_error "Claude Code CLI not found. Install it first: https://claude.ai/code"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  log_error "python3 not found. MemPalace requires Python 3.9+. Install from https://python.org"
  exit 1
fi

PY_VERSION_OK=$(python3 -c 'import sys; print("1" if sys.version_info >= (3, 9) else "0")' 2>/dev/null || echo "0")
if [[ "$PY_VERSION_OK" != "1" ]]; then
  log_error "Python 3.9+ required. Found: $(python3 --version 2>&1)"
  exit 1
fi

# ── pipx (preferred installer for Python CLI apps) ──────────
prompt_yn_default_yes() {
  local q="$1"
  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    return 0
  fi
  printf "  %s [Y/n]: " "$q"
  local ans
  read -r ans || ans=""
  case "$ans" in
    n|N|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

install_pipx() {
  log_info "pipx not found. pipx is the recommended installer for Python CLI tools."
  if ! prompt_yn_default_yes "Install pipx now?"; then
    log_warn "Skipping pipx install — will fall back to pip --user"
    return 1
  fi

  # Pick the best installer for this OS/distro
  if [[ "$(uname -s)" == "Darwin" ]] && command -v brew &>/dev/null; then
    log_info "Installing pipx via Homebrew..."
    if brew install pipx >/dev/null 2>&1; then
      log_success "pipx installed via brew"
    else
      log_warn "brew install pipx failed — trying pip fallback"
    fi
  elif command -v apt-get &>/dev/null && [[ "$(id -u)" == "0" || -n "${SUDO_USER:-}" ]]; then
    log_info "Installing pipx via apt..."
    if sudo apt-get update -qq && sudo apt-get install -y -qq pipx >/dev/null 2>&1; then
      log_success "pipx installed via apt"
    else
      log_warn "apt install pipx failed — trying pip fallback"
    fi
  fi

  # Pip fallback (works everywhere)
  if ! command -v pipx &>/dev/null; then
    log_info "Installing pipx via 'python3 -m pip install --user pipx'..."
    if ! python3 -m pip install --user --quiet pipx; then
      log_error "Failed to install pipx via pip"
      return 1
    fi
    log_success "pipx installed via pip --user"
  fi

  # Ensure pipx's bin dir is on PATH for this session and future ones
  log_info "Running 'pipx ensurepath' to update shell PATH..."
  if command -v pipx &>/dev/null; then
    pipx ensurepath >/dev/null 2>&1 || python3 -m pipx ensurepath >/dev/null 2>&1 || true
  else
    python3 -m pipx ensurepath >/dev/null 2>&1 || true
  fi

  # Make pipx's bin dir available to the rest of THIS script run
  local pipx_bin="${HOME}/.local/bin"
  if [[ -d "$pipx_bin" ]] && [[ ":$PATH:" != *":$pipx_bin:"* ]]; then
    export PATH="$pipx_bin:$PATH"
  fi

  if ! command -v pipx &>/dev/null && ! python3 -m pipx --version >/dev/null 2>&1; then
    log_warn "pipx still not on PATH. You may need to restart your shell."
    return 1
  fi

  log_warn "If commands like 'mempalace' aren't found after this script, restart your shell (pipx updated PATH in your rc file)."
  return 0
}

# Wrapper that calls pipx whether it's on PATH yet or only via 'python3 -m pipx'
run_pipx() {
  if command -v pipx &>/dev/null; then
    pipx "$@"
  else
    python3 -m pipx "$@"
  fi
}

# ── Package install (pipx preferred, pip --user fallback) ────
package_installed() {
  # pipx installation check
  if command -v pipx &>/dev/null || python3 -m pipx --version >/dev/null 2>&1; then
    if run_pipx list --short 2>/dev/null | grep -qE "^${MEMPALACE_PKG}([[:space:]]|$)"; then
      return 0
    fi
  fi
  # pip / pip --user check (covers either install path)
  if python3 -m pip show "$MEMPALACE_PKG" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

ensure_package() {
  if package_installed; then
    log_info "MemPalace package already installed — skipping"
    return 0
  fi

  # Make sure pipx is available before trying to use it
  local have_pipx=0
  if command -v pipx &>/dev/null || python3 -m pipx --version >/dev/null 2>&1; then
    have_pipx=1
  else
    if install_pipx; then
      have_pipx=1
    fi
  fi

  if (( have_pipx )); then
    log_info "Installing $MEMPALACE_PKG via pipx (isolated venv)..."
    if run_pipx install "$MEMPALACE_PKG" >/dev/null 2>&1; then
      log_success "Installed $MEMPALACE_PKG via pipx"
      return 0
    fi
    log_warn "pipx install failed — falling back to pip --user"
  fi

  log_info "Installing $MEMPALACE_PKG via pip --user..."
  if python3 -m pip install --user --quiet "$MEMPALACE_PKG"; then
    log_success "Installed $MEMPALACE_PKG via pip --user"
  else
    log_error "Failed to install $MEMPALACE_PKG. Try manually: pipx install $MEMPALACE_PKG"
    return 1
  fi
}

# ── PATH check for the mempalace-mcp binary ─────────────────
ensure_binary_on_path() {
  if command -v "$MEMPALACE_MCP_BIN" &>/dev/null; then
    return 0
  fi

  # Common install locations
  local candidates=(
    "${HOME}/.local/bin"
    "${HOME}/Library/Python/$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)/bin"
  )
  local found=""
  for dir in "${candidates[@]}"; do
    if [[ -x "${dir}/${MEMPALACE_MCP_BIN}" ]]; then
      found="$dir"
      break
    fi
  done

  if [[ -n "$found" ]]; then
    log_warn "$MEMPALACE_MCP_BIN found at $found but not on PATH."
    log_warn "Add to your shell rc:  export PATH=\"$found:\$PATH\""
    log_warn "Then re-run this installer (or 'claude mcp add' will fail to launch the server)."
    return 1
  fi

  log_warn "$MEMPALACE_MCP_BIN not found on PATH after install. MCP registration will be skipped."
  return 1
}

# ── MCP server (user scope so it works in every project) ────
mcp_installed() {
  claude mcp list 2>/dev/null | grep -qE "(^|[^[:alnum:]_-])${MEMPALACE_MCP_NAME}([^[:alnum:]_-]|:|$)"
}

ensure_mcp() {
  if mcp_installed; then
    log_info "MCP server '$MEMPALACE_MCP_NAME' already configured — skipping"
    return 0
  fi

  ensure_binary_on_path || return 1

  log_info "Registering MemPalace MCP server (user scope)..."
  if claude mcp add -s user "$MEMPALACE_MCP_NAME" -- "$MEMPALACE_MCP_BIN" >/dev/null 2>&1; then
    log_success "MemPalace MCP server registered (available in every project)"
  else
    log_warn "Failed to register MCP server — try manually: claude mcp add -s user $MEMPALACE_MCP_NAME -- $MEMPALACE_MCP_BIN"
    return 1
  fi
}

# ── Per-project usage hints ─────────────────────────────────
print_next_steps() {
  local cyan="$(tput setaf 6 2>/dev/null || true)"
  local bold="$(tput bold 2>/dev/null || true)"
  local rst="$(tput sgr0 2>/dev/null || true)"

  cat <<EOF

  ${bold}MemPalace is per-project.${rst} Run these inside each repo you want indexed:

    ${cyan}cd ~/Development/your-project${rst}
    ${cyan}mempalace init --yes .${rst}                       # create palace for this project
    ${cyan}mempalace mine .${rst}                             # index project files
    ${cyan}mempalace mine ~/.claude/projects --mode convos${rst}  # index Claude Code transcripts
    ${cyan}mempalace status${rst}                             # verify health
    ${cyan}mempalace search "auth flow"${rst}                 # semantic recall

  Inside Claude Code you can also use the ${bold}/mempalace:init${rst}, ${bold}/mempalace:mine${rst},
  ${bold}/mempalace:search${rst}, and ${bold}/mempalace:status${rst} skills (loaded via the MCP server).

EOF
}

# ── Main ─────────────────────────────────────────────────────
main() {
  log_info "MemPalace setup — installing only what's missing"
  ensure_package || { log_error "MemPalace package install failed — aborting"; exit 1; }
  ensure_mcp || true
  log_success "MemPalace setup complete"
  print_next_steps
}

main "$@"
