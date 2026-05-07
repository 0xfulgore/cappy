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

# ── Per-project init / mine ─────────────────────────────────
# Resolve the mempalace CLI even if PATH isn't refreshed yet
mempalace_cmd() {
  if command -v mempalace &>/dev/null; then
    echo "mempalace"
  elif [[ -x "${HOME}/.local/bin/mempalace" ]]; then
    echo "${HOME}/.local/bin/mempalace"
  else
    echo ""
  fi
}

palace_initialized() {
  # Two independent signals — either is sufficient.
  #   1. .mempalace/ directory exists in the project root
  #   2. `mempalace status` exits 0 when run from inside the project
  local cmd="$1" dir="$2"
  if [[ -d "${dir}/.mempalace" ]]; then
    return 0
  fi
  ( cd "$dir" && "$cmd" status >/dev/null 2>&1 )
}

palace_has_been_mined() {
  # Heuristic: any non-zero drawer / memory / document / chunk count in `status`.
  # If the format changes upstream, we err on the side of "not mined" and ask.
  local cmd="$1" dir="$2"
  local out
  out=$( cd "$dir" && "$cmd" status 2>/dev/null ) || return 1
  echo "$out" | grep -qiE '(drawer|memor(y|ies)|document|chunk|entry|entries)[s]?[[:space:]]*[:=][[:space:]]*[1-9]'
}

# Find candidate project dirs (top-level subdirs that look like git repos)
discover_project_candidates() {
  local roots=()

  # Honour the CLAUDE.md target the user picked in the main installer
  if [[ -n "${CAPPY_CLAUDE_MD_TARGET:-}" ]]; then
    local md_dir
    md_dir=$(dirname "$CAPPY_CLAUDE_MD_TARGET")
    [[ -d "$md_dir" ]] && roots+=("$md_dir")
  fi

  # Common dev roots
  for candidate in "$HOME/Development" "$HOME/dev" "$HOME/projects" "$HOME/code" "$HOME/src" "$HOME/workspace"; do
    [[ -d "$candidate" ]] && roots+=("$candidate")
  done

  # De-dupe and emit subdir candidates
  local seen_roots="" seen_dirs=""
  for root in "${roots[@]}"; do
    [[ ":$seen_roots:" == *":$root:"* ]] && continue
    seen_roots="$seen_roots:$root"
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      [[ ":$seen_dirs:" == *":$dir:"* ]] && continue
      seen_dirs="$seen_dirs:$dir"
      echo "$dir"
    done < <(find "$root" -mindepth 1 -maxdepth 2 -name .git -type d 2>/dev/null \
              | sed 's|/\.git$||' | sort)
  done
}

prompt_init_projects() {
  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    log_info "Non-interactive mode — skipping per-project init prompt"
    return 0
  fi

  local cmd
  cmd="$(mempalace_cmd)"
  if [[ -z "$cmd" ]]; then
    log_warn "mempalace CLI not on PATH yet — skipping init prompt. Restart your shell and run 'mempalace init --yes <project>' manually."
    return 0
  fi

  if ! prompt_yn "Initialize a MemPalace for any of your projects now?" "y"; then
    return 0
  fi

  # Build candidate list
  local -a candidates=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && candidates+=("$line")
  done < <(discover_project_candidates)

  # Decide between multiselect (auto-detected) and free-form path entry
  local -a chosen=()
  if (( ${#candidates[@]} == 0 )); then
    log_info "No git repos auto-detected under common dev roots."
    printf "Enter project paths to initialize (space-separated, ~ allowed), or blank to skip:\n  " >&2
    local raw
    read -r raw
    for p in $raw; do
      p="${p/#\~/$HOME}"
      [[ -d "$p" ]] && chosen+=("$p") || log_warn "Skipping '$p' — not a directory"
    done
  else
    # Annotate state per project: init'd? mined?
    local -a labels=()
    for dir in "${candidates[@]}"; do
      local tag=""
      if palace_initialized "$cmd" "$dir"; then
        if palace_has_been_mined "$cmd" "$dir"; then
          tag="  [init'd + mined — will skip both]"
        else
          tag="  [already initialized — will skip init]"
        fi
      fi
      labels+=("$(basename "$dir")${tag}   ($dir)")
    done
    labels+=("Custom path…")

    local sel_idx
    while IFS= read -r sel_idx; do
      [[ -z "$sel_idx" ]] && continue
      if (( sel_idx == ${#candidates[@]} )); then
        printf "  Enter custom path: " >&2
        local p
        read -r p
        p="${p/#\~/$HOME}"
        [[ -d "$p" ]] && chosen+=("$p") || log_warn "Skipping '$p' — not a directory"
      else
        chosen+=("${candidates[$sel_idx]}")
      fi
    done < <(prompt_multiselect "Select projects to initialize:" "${labels[@]}")
  fi

  if (( ${#chosen[@]} == 0 )); then
    log_info "No projects selected — skipping init."
    return 0
  fi

  local mine_after=0
  prompt_yn "Also run 'mempalace mine' on each to index its files?" "y" && mine_after=1

  for dir in "${chosen[@]}"; do
    local name
    name=$(basename "$dir")

    if palace_initialized "$cmd" "$dir"; then
      log_info "$name: palace already exists — skipping init"
    else
      log_info "Initializing palace in $dir ..."
      if ( cd "$dir" && "$cmd" init --yes . >/dev/null 2>&1 ); then
        log_success "Initialized: $dir"
      else
        log_warn "init failed for $dir — try manually: cd '$dir' && mempalace init --yes ."
        continue
      fi
    fi

    if (( mine_after )); then
      if palace_has_been_mined "$cmd" "$dir"; then
        log_info "$name: already mined — skipping (delete .mempalace/ and re-run to force a re-mine)"
        continue
      fi
      log_info "Mining $dir (this can take a while on large repos)..."
      if ( cd "$dir" && "$cmd" mine . >/dev/null 2>&1 ); then
        log_success "Mined: $dir"
      else
        log_warn "mine failed for $dir — try manually: cd '$dir' && mempalace mine ."
      fi
    fi
  done

  # Optional: ingest Claude Code transcripts globally
  if [[ -d "${HOME}/.claude/projects" ]] && \
     prompt_yn "Also mine your Claude Code conversation transcripts (~/.claude/projects, can be slow)?" "n"; then
    log_info "Mining ~/.claude/projects in convos mode..."
    if "$cmd" mine "${HOME}/.claude/projects" --mode convos >/dev/null 2>&1; then
      log_success "Mined Claude Code transcripts"
    else
      log_warn "convo mine failed — try manually: mempalace mine ~/.claude/projects --mode convos"
    fi
  fi
}

# ── Per-project usage hints ─────────────────────────────────
print_next_steps() {
  local cyan="$(tput setaf 6 2>/dev/null || true)"
  local bold="$(tput bold 2>/dev/null || true)"
  local rst="$(tput sgr0 2>/dev/null || true)"

  cat <<EOF

  ${bold}MemPalace usage cheatsheet${rst} (per-project — run inside each repo):

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
  prompt_init_projects || true
  log_success "MemPalace setup complete"
  print_next_steps
}

main "$@"
