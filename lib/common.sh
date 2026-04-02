#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Shared shell utilities
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── ANSI Colors ──────────────────────────────────────────────
RST=$'\e[0m'
DIM=$'\e[2m'
BOLD=$'\e[1m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
MAGENTA=$'\e[35m'
CYAN=$'\e[36m'
WHITE=$'\e[37m'
BRIGHT_GREEN=$'\e[92m'
BRIGHT_YELLOW=$'\e[93m'
BRIGHT_CYAN=$'\e[96m'
BRIGHT_WHITE=$'\e[97m'

# ── Logging ──────────────────────────────────────────────────
log_info()    { printf "%s[info]%s  %s\n" "$CYAN"   "$RST" "$*"; }
log_success() { printf "%s[  ok]%s  %s\n" "$GREEN"  "$RST" "$*"; }
log_warn()    { printf "%s[warn]%s  %s\n" "$YELLOW" "$RST" "$*"; }
log_error()   { printf "%s[ err]%s  %s\n" "$RED"    "$RST" "$*" >&2; }
log_step()    { printf "\n%s━━ %s%s\n"    "$BRIGHT_CYAN" "$*" "$RST"; }

# ── Dependency checks ────────────────────────────────────────
require_cmd() {
  local cmd="$1"
  local install_hint="${2:-}"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "'$cmd' is required but not found."
    [[ -n "$install_hint" ]] && log_info "Install it: $install_hint"
    return 1
  fi
}

ensure_jq() {
  if command -v jq &>/dev/null; then return 0; fi
  log_warn "jq is required for config merging but not found."
  if [[ "$CAPPY_OS" == "macos" ]]; then
    if prompt_yn "Install jq via Homebrew?"; then
      brew install jq && return 0
    fi
  elif [[ "$CAPPY_OS" == "linux" ]]; then
    if prompt_yn "Install jq via apt?"; then
      sudo apt-get install -y jq && return 0
    fi
  fi
  log_error "Cannot continue without jq. Install it manually and re-run."
  exit 1
}

# ── OS / Shell detection ─────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin*) CAPPY_OS="macos" ;;
    Linux*)  CAPPY_OS="linux" ;;
    *)       CAPPY_OS="unknown"; log_warn "Unknown OS: $(uname -s)" ;;
  esac
  export CAPPY_OS
}

detect_shell() {
  CAPPY_SHELL="$(basename "${SHELL:-/bin/bash}")"
  export CAPPY_SHELL
}

# ── Prompts ──────────────────────────────────────────────────
prompt_yn() {
  local question="$1"
  local default="${2:-y}"
  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    [[ "$default" == "y" ]] && return 0 || return 1
  fi
  local hint
  [[ "$default" == "y" ]] && hint="[Y/n]" || hint="[y/N]"
  printf "%s %s " "$question" "$hint"
  read -r ans
  ans="${ans:-$default}"
  [[ "${ans,,}" == "y" ]]
}

prompt_select() {
  local prompt="$1"
  shift
  local options=("$@")
  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    echo 0; return
  fi
  printf "\n%s%s%s\n" "$BOLD" "$prompt" "$RST" >&2
  for i in "${!options[@]}"; do
    printf "  %s%d)%s %s\n" "$CYAN" $((i + 1)) "$RST" "${options[$i]}" >&2
  done
  while true; do
    printf "%sChoose [1-%d]: %s" "$BRIGHT_CYAN" "${#options[@]}" "$RST" >&2
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo $((choice - 1))
      return
    fi
    log_warn "Invalid selection."
  done
}

prompt_multiselect() {
  local prompt="$1"
  shift
  local options=("$@")

  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    for i in "${!options[@]}"; do echo "$i"; done
    return
  fi

  printf "\n%s%s%s\n\n" "$BOLD" "$prompt" "$RST" >&2
  for i in "${!options[@]}"; do
    printf "  %s%2d)%s %s\n" "$CYAN" $((i + 1)) "$RST" "${options[$i]}" >&2
  done
  printf "  %s 0)%s All of the above (recommended)\n" "$GREEN" "$RST" >&2

  printf "\n%sEnter numbers separated by spaces, or 0 for all [0]: %s" "$BRIGHT_CYAN" "$RST" >&2
  read -r input
  input="${input:-0}"

  if [[ "$input" == "0" ]]; then
    for i in "${!options[@]}"; do echo "$i"; done
    return
  fi

  for num in $input; do
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#options[@]} )); then
      echo $((num - 1))
    fi
  done
}

# ── File utilities ───────────────────────────────────────────
sha256_file() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  fi
}

ensure_dir() {
  [[ -d "$1" ]] || mkdir -p "$1"
}
