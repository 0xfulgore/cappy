#!/usr/bin/env bash
# Cappy — MCP Server Setup
# Interactive installer for MCP servers
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

setup_server() {
  local config_file="$1"
  local name desc
  name=$(jq -r '.name' "$config_file")
  desc=$(jq -r '.description' "$config_file")

  printf "\n━━ %s\n" "$name"
  printf "   %s\n\n" "$desc"

  # Collect environment variables
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

  # Build and run the claude mcp add command
  local server_id
  server_id=$(basename "$config_file" .json)

  local args
  args=$(jq -r '.args | join(" ")' "$config_file")

  log_info "Adding $name to Claude Code..."

  # Use claude mcp add with environment variables
  local cmd="claude mcp add $server_id"
  for env_arg in "${env_args[@]}"; do
    cmd+=" $env_arg"
  done
  cmd+=" -- npx -y @modelcontextprotocol/server-$server_id"

  if eval "$cmd" 2>&1; then
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
