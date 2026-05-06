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
# Pin to a known-working stable release. ruflo@latest currently resolves to
# 3.7.0-alpha.6 which npm registry rejects with ETARGET, so we pin to the
# v3alpha dist-tag (currently 3.6.30) which is the most recent stable.
RUFLO_MCP_VERSION="v3alpha"

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
mcp_installed() {
  claude mcp list 2>/dev/null | grep -qE "(^|[^[:alnum:]_-])${RUFLO_MCP_NAME}([^[:alnum:]_-]|:|$)"
}

ensure_mcp() {
  if mcp_installed; then
    log_info "MCP server '$RUFLO_MCP_NAME' already configured — skipping"
    return 0
  fi

  log_info "Registering Ruflo MCP server..."
  if claude mcp add "$RUFLO_MCP_NAME" -- npx -y "ruflo@${RUFLO_MCP_VERSION}" mcp start >/dev/null 2>&1; then
    log_success "Ruflo MCP server registered"
  else
    log_warn "Failed to register Ruflo MCP server — try manually: claude mcp add $RUFLO_MCP_NAME -- npx -y ruflo@${RUFLO_MCP_VERSION} mcp start"
    return 1
  fi
}

# ── Main ─────────────────────────────────────────────────────
main() {
  log_info "Ruflo setup — installing only what's missing"
  ensure_marketplace || true
  for plugin in "${RUFLO_PLUGINS[@]}"; do
    ensure_plugin "$plugin" || true
  done
  ensure_mcp || true
  log_success "Ruflo setup complete"
  printf "  Run %sclaude plugin list%s and %sclaude mcp list%s to verify.\n" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)" \
    "$(tput setaf 6 2>/dev/null || true)" "$(tput sgr0 2>/dev/null || true)"
}

main "$@"
