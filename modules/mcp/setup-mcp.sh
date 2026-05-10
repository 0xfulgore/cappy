#!/usr/bin/env bash
# Cappy — MCP Server Setup
# Interactive installer for MCP servers.
# Registers all servers at --scope user so they are available in every project.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="${SCRIPT_DIR}/configs"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../../lib/common.sh" ]]; then
  source "${SCRIPT_DIR}/../../lib/common.sh"
  detect_os
else
  log_info()    { printf "[info]  %s\n" "$*"; }
  log_success() { printf "[  ok]  %s\n" "$*"; }
  log_warn()    { printf "[warn]  %s\n" "$*"; }
  log_error()   { printf "[ err]  %s\n" "$*" >&2; }
fi

# Check prerequisites
if ! command -v npx &>/dev/null; then
  log_error "npx not found. Install Node.js first: https://nodejs.org"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  log_error "Claude Code CLI not found. Install it first: https://claude.ai/code"
  exit 1
fi

# ── Scope-aware MCP helpers ───────────────────────────────────
# MCP servers MUST be registered at user scope so they are available in every
# project. Pre-fix installs registered at default (local) scope, which limits
# the server to the cappy directory only. Migration: detect local-scope
# registration, remove it, re-register at user scope.

mcp_server_at_user_scope() {
  local server_id="$1"
  claude mcp get "$server_id" 2>/dev/null | grep -q "Scope: User config"
}

mcp_server_at_local_scope() {
  local server_id="$1"
  claude mcp get "$server_id" 2>/dev/null | grep -q "Scope: Local config"
}

mcp_server_registered_anywhere() {
  local server_id="$1"
  claude mcp list 2>/dev/null | grep -qE "(^|[^[:alnum:]_-])${server_id}([^[:alnum:]_-]|:|$)"
}

setup_server() {
  local config_file="$1"
  local name desc transport url
  name=$(jq -r '.name' "$config_file")
  desc=$(jq -r '.description' "$config_file")
  transport=$(jq -r '.transport // "stdio"' "$config_file")
  url=$(jq -r '.url // ""' "$config_file")

  local server_id
  server_id=$(basename "$config_file" .json)

  printf "\n━━ %s\n" "$name"
  printf "   %s\n\n" "$desc"

  # Already at user scope — nothing to do.
  if mcp_server_at_user_scope "$server_id"; then
    log_info "$name already at user scope — skipping (run 'claude mcp remove $server_id' to reinstall)"
    return 0
  fi

  # Migrate from local-scope registration.
  if mcp_server_at_local_scope "$server_id"; then
    log_info "Migrating '$server_id' from local scope to user scope (so it works in every project)..."
    if claude mcp remove "$server_id" >/dev/null 2>&1; then
      log_success "Removed local-scope registration for $server_id"
    else
      log_warn "Failed to remove local-scope $server_id — continuing, user-scope add may fail"
    fi
  fi

  # Some other shape exists (project-scope / etc.) — leave it alone.
  if mcp_server_registered_anywhere "$server_id" && ! mcp_server_at_local_scope "$server_id"; then
    log_info "$name present at non-local scope — leaving as-is"
    return 0
  fi

  # Remote transports (sse/http) — no env vars, OAuth handled in browser on first use
  if [[ "$transport" == "sse" || "$transport" == "http" ]]; then
    if [[ -z "$url" ]]; then
      log_error "$name: transport=$transport requires a .url field in the config"
      return 1
    fi
    log_info "Adding $name (transport: $transport, scope: user)"
    if claude mcp add --scope user --transport "$transport" "$server_id" "$url" 2>&1; then
      log_success "$name configured. First use will open a browser for OAuth."
    else
      log_warn "$name setup may have failed — check 'claude mcp list'"
    fi
    return 0
  fi

  # Local stdio transport — collect env vars, then register via array exec (no eval)
  local env_args=()
  local env_keys
  env_keys=$(jq -r '.env_vars | keys[]' "$config_file" 2>/dev/null)

  for key in $env_keys; do
    local description required help_text
    description=$(jq -r ".env_vars.\"$key\".description" "$config_file")
    required=$(jq -r ".env_vars.\"$key\".required // false" "$config_file")
    help_text=$(jq -r ".env_vars.\"$key\".help // \"\"" "$config_file")

    printf "  %s\n" "$description"
    [[ -n "$help_text" ]] && printf "  Help: %s\n" "$help_text"

    # Check if already set in environment
    if [[ -n "${!key:-}" ]]; then
      printf "  (found in environment: %s...)\n" "${!key:0:8}"
      env_args+=("-e" "$key")
      continue
    fi

    if [[ "$required" == "true" ]]; then
      printf "  Enter %s: " "$key"
      read -r value
      if [[ -z "$value" ]]; then
        log_warn "Skipping $name — required variable not provided"
        return 1
      fi
      export "$key=$value"
      env_args+=("-e" "$key")
    fi
  done

  log_info "Adding $name to Claude Code (user scope)..."

  # Build argument array — no eval, values are never interpolated as shell code.
  local cmd_args=("claude" "mcp" "add" "--scope" "user" "$server_id")
  for env_arg in "${env_args[@]}"; do
    cmd_args+=("$env_arg")
  done
  cmd_args+=("--" "npx" "-y" "@modelcontextprotocol/server-${server_id}")

  if "${cmd_args[@]}" 2>&1; then
    log_success "$name configured successfully"
  else
    log_warn "$name setup may have failed — check claude mcp list"
  fi
}

# Main
main() {
  local servers="${CAPPY_MCP_SERVERS:-}"

  if [[ -z "$servers" ]]; then
    printf "Available MCP servers:\n"
    for config in "$CONFIGS_DIR"/*.json; do
      local name
      name=$(jq -r '.name' "$config")
      local id
      id=$(basename "$config" .json)
      printf "  - %s (%s)\n" "$name" "$id"
    done
    printf "\nWhich servers to set up? (comma-separated, e.g., github,playwright): "
    read -r servers
  fi

  IFS=',' read -ra selected <<< "$servers"
  for server in "${selected[@]}"; do
    server=$(echo "$server" | xargs)  # trim whitespace
    local config="$CONFIGS_DIR/${server}.json"
    if [[ -f "$config" ]]; then
      setup_server "$config" || true
    else
      log_warn "Unknown server: $server"
    fi
  done

  printf "\nDone! Run 'claude mcp list' to verify.\n"
}

main "$@"
