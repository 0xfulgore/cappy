#!/usr/bin/env bash
# Cappy — Ruflo setup
# Idempotent installer for the Ruflo marketplace, plugins, and MCP server.
# Skips anything already installed; only adds what is missing.
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

RUFLO_MARKETPLACE_NAME="ruflo"
RUFLO_MARKETPLACE_SOURCE="ruvnet/ruflo"
RUFLO_PLUGINS=(
  "ruflo-core"
  "ruflo-swarm"
  "ruflo-autopilot"
  "ruflo-loop-workers"
  "ruflo-rag-memory"
  "ruflo-security-audit"
  "ruflo-testgen"
  "ruflo-docs"
)
RUFLO_MCP_NAME="ruflo"
# Pinned to a specific version (not the v3alpha dist-tag) to prevent
# supply-chain compromise. Bump this in a deliberate commit when upgrading.
# Last verified: 2026-05-10 against `npm view ruflo@v3alpha version`.
RUFLO_MCP_VERSION="3.7.0-alpha.20"

# ── Prerequisites ────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  log_error "Claude Code CLI not found. Install it first: https://claude.ai/code"
  exit 1
fi

if ! command -v npx &>/dev/null; then
  log_error "npx not found. Install Node.js first: https://nodejs.org"
  exit 1
fi

# ── Marketplace ──────────────────────────────────────────────
ensure_marketplace() {
  local known="${HOME}/.claude/plugins/known_marketplaces.json"
  if [[ -f "$known" ]] && jq -e --arg n "$RUFLO_MARKETPLACE_NAME" '.[$n]' "$known" >/dev/null 2>&1; then
    log_info "Marketplace '$RUFLO_MARKETPLACE_NAME' already added — skipping"
    return 0
  fi

  log_info "Adding Ruflo marketplace ($RUFLO_MARKETPLACE_SOURCE)..."
  if claude plugin marketplace add "$RUFLO_MARKETPLACE_SOURCE" >/dev/null 2>&1; then
    log_success "Ruflo marketplace added"
  else
    log_warn "Failed to add Ruflo marketplace — check 'claude plugin marketplace list'"
    return 1
  fi
}

# ── Plugins ──────────────────────────────────────────────────
plugin_installed() {
  local plugin="$1"
  local installed="${HOME}/.claude/plugins/installed_plugins.json"
  [[ -f "$installed" ]] || return 1
  jq -e --arg key "${plugin}@${RUFLO_MARKETPLACE_NAME}" \
    '.plugins[$key] // empty | length > 0' "$installed" >/dev/null 2>&1
}

ensure_plugin() {
  local plugin="$1"
  if plugin_installed "$plugin"; then
    log_info "Plugin '$plugin' already installed — skipping"
    return 0
  fi

  log_info "Installing plugin: $plugin"
  if claude plugin install "${plugin}@${RUFLO_MARKETPLACE_NAME}" >/dev/null 2>&1; then
    log_success "Installed $plugin"
  else
    log_warn "Failed to install $plugin — try manually: claude plugin install ${plugin}@${RUFLO_MARKETPLACE_NAME}"
    return 1
  fi
}

# ── MCP server ───────────────────────────────────────────────
# Ruflo MUST be registered at user scope so it's available in every project.
# Pre-2.2.2 installs registered at default (local) scope, which limited ruflo
# to the cappy directory only — users got "Failed to reconnect to ruflo"
# in any other project. Migration: detect local-scope registration, remove
# it, re-register at user scope.

mcp_registered_anywhere() {
  claude mcp list 2>/dev/null | grep -qE "(^|[^[:alnum:]_-])${RUFLO_MCP_NAME}([^[:alnum:]_-]|:|$)"
}

mcp_registered_at_user_scope() {
  # claude mcp get reports "Scope: User config" when registered at user scope.
  claude mcp get "$RUFLO_MCP_NAME" 2>/dev/null | grep -q "Scope: User config"
}

mcp_registered_at_local_scope() {
  claude mcp get "$RUFLO_MCP_NAME" 2>/dev/null | grep -q "Scope: Local config"
}

ensure_mcp() {
  # Already at user scope — nothing to do.
  if mcp_registered_at_user_scope; then
    log_info "MCP server '$RUFLO_MCP_NAME' already at user scope — skipping"
    return 0
  fi

  # Migrate from pre-2.2.2 local-scope registration.
  # Capture stderr so failures show the actual claude error, not just "failed".
  if mcp_registered_at_local_scope; then
    log_info "Migrating '$RUFLO_MCP_NAME' from local scope to user scope (so it works in every project)..."
    local _err
    if _err=$(claude mcp remove "$RUFLO_MCP_NAME" 2>&1); then
      log_success "Removed local-scope registration"
    else
      log_warn "Failed to remove local-scope ruflo: $_err"
      log_warn "Continuing — user-scope add may fail. If it does, run: claude mcp remove $RUFLO_MCP_NAME"
    fi
  fi

  # Some other shape exists (HTTP / project-scope / etc.) — leave it alone.
  if mcp_registered_anywhere && ! mcp_registered_at_local_scope; then
    log_info "MCP server '$RUFLO_MCP_NAME' present at non-local scope — leaving as-is"
    return 0
  fi

  log_info "Registering Ruflo MCP server at user scope..."
  local _err
  if _err=$(claude mcp add --scope user "$RUFLO_MCP_NAME" -- npx -y "ruflo@${RUFLO_MCP_VERSION}" mcp start 2>&1); then
    log_success "Ruflo MCP server registered (user scope — works in every project)"
  else
    log_warn "Failed to register Ruflo MCP server: $_err"
    log_warn "Try manually: claude mcp add --scope user $RUFLO_MCP_NAME -- npx -y ruflo@${RUFLO_MCP_VERSION} mcp start"
    return 1
  fi

  # Post-action verification: report what claude actually has registered.
  if mcp_registered_at_user_scope; then
    log_success "Verified: ruflo is at user scope (available in every project)"
  else
    log_warn "Verification failed — claude mcp get $RUFLO_MCP_NAME does not show user scope. Run it manually to inspect."
  fi
}

# ── Preferences ──────────────────────────────────────────────
# Captured once at install / update; honored by core directive #25
# (autopilot-handoff). File schema is versioned so future installs
# can detect stale prefs and re-prompt only when needed.
PREFS_DIR="${HOME}/.cappy"
PREFS_FILE="${PREFS_DIR}/ruflo-preferences.json"
PREFS_VERSION=1

read_existing_pref() {
  local key="$1"
  [[ -f "$PREFS_FILE" ]] || return 1
  jq -re --arg k "$key" '.[$k] // empty' "$PREFS_FILE" 2>/dev/null
}

write_prefs() {
  local offer_mode="$1"
  local post_completion="$2"
  mkdir -p "$PREFS_DIR"
  local tmp
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' RETURN
  jq -n \
    --argjson v "$PREFS_VERSION" \
    --arg om "$offer_mode" \
    --arg pc "$post_completion" \
    '{_version: $v, autopilot_offer_mode: $om, autopilot_post_completion: $pc}' \
    > "$tmp"
  mv "$tmp" "$PREFS_FILE"
  log_success "Saved preferences to $PREFS_FILE"
}

prompt_preferences() {
  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not found — skipping preference prompts (defaults will apply at runtime)"
    return 0
  fi

  # Skip silently in non-interactive mode (CI, piped install).
  if [[ ! -t 0 || ! -t 1 ]]; then
    if [[ ! -f "$PREFS_FILE" ]]; then
      write_prefs "ask" "auto_disable"
      log_info "Non-interactive install — wrote default prefs (offer=ask, post=auto_disable)"
    fi
    return 0
  fi

  # Skip if prefs already at current schema version.
  if [[ -f "$PREFS_FILE" ]]; then
    local existing_version
    existing_version=$(jq -re '._version // 0' "$PREFS_FILE" 2>/dev/null || echo 0)
    if (( existing_version >= PREFS_VERSION )); then
      log_info "Existing ruflo preferences found (v${existing_version}) — skipping prompts"
      return 0
    fi
    log_info "Prefs schema bumped (v${existing_version} → v${PREFS_VERSION}) — re-prompting"
  fi

  printf "\n"
  printf "  %sCappy installs Ruflo's autopilot — autonomous task completion via /loop.%s\n" \
    "$(tput bold 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "  %sTwo quick preferences (saved to ~/.cappy/ruflo-preferences.json):%s\n" \
    "$(tput dim 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "\n"

  # ── Question 1: when should Claude offer autopilot? ──────
  printf "  %s1. When a task is large enough to need a swarm, when should Claude offer autopilot?%s\n" \
    "$(tput bold 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "     [a] always   — auto-enable autopilot for every large task (no prompt)\n"
  printf "     [b] ask      — prompt me each time (recommended)\n"
  printf "     [c] never    — never offer; just spawn the swarm\n"
  printf "     Choice [a/b/c, default b]: "
  local offer_choice
  read -r offer_choice
  local offer_mode
  case "$(printf '%s' "$offer_choice" | tr '[:upper:]' '[:lower:]')" in
    a|always) offer_mode="always" ;;
    c|never)  offer_mode="never"  ;;
    *)        offer_mode="ask"    ;;
  esac

  printf "\n"

  # ── Question 2: post-completion behavior ─────────────────
  printf "  %s2. When autopilot finishes a task, what should happen?%s\n" \
    "$(tput bold 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "     [a] auto-disable — turn autopilot off, predictable token usage (recommended)\n"
  printf "     [b] stay paused  — keep enabled but don't loop until next large task\n"
  printf "     [c] stay on      — leave autopilot fully active until I disable it\n"
  printf "     Choice [a/b/c, default a]: "
  local post_choice
  read -r post_choice
  local post_completion
  case "$(printf '%s' "$post_choice" | tr '[:upper:]' '[:lower:]')" in
    b|paused) post_completion="stay_paused" ;;
    c|on)     post_completion="stay_on"     ;;
    *)        post_completion="auto_disable" ;;
  esac

  write_prefs "$offer_mode" "$post_completion"
  printf "\n"
}

# ── Main ─────────────────────────────────────────────────────
main() {
  log_info "Ruflo setup — installing only what's missing"
  ensure_marketplace || true
  for plugin in "${RUFLO_PLUGINS[@]}"; do
    ensure_plugin "$plugin" || true
  done
  ensure_mcp || true
  prompt_preferences || true
  log_success "Ruflo setup complete"
  printf "\n"
  printf "  %sQuick reference:%s\n" \
    "$(tput bold 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "    %s/autopilot enable%s         start the autonomous completion loop\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "    %s/autopilot-status%s         show progress + iteration count\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "    %s/autopilot disable%s        stop the loop\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "    %s/swarm init%s               manually initialize a multi-agent swarm\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "    %s/watch%s                    live event stream from active swarms\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "\n"
  printf "  %sClaude will also offer autopilot automatically when a task is large enough.%s\n" \
    "$(tput dim 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "  %sFull invocation guide: ~/.cappy/ruflo-QUICKSTART.md%s\n" \
    "$(tput dim 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
  printf "  %sVerify install: claude plugin list && claude mcp list%s\n" \
    "$(tput dim 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
}

main "$@"
