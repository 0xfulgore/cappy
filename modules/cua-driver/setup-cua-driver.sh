#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# setup-cua-driver.sh — install the cua-driver macOS app + skill
#
# cua-driver is a signed/notarized Swift app bundle from trycua/cua.
# It ships a CLI, an MCP stdio server, and a bundled Claude Code
# skill pack. macOS only.
#
# We delegate to upstream's official installer rather than re-implement
# it (binary download, signing, symlinks, skill-pack drop). After the
# binary is in place, we register it as an MCP server in Claude Code if
# the `claude` CLI is on PATH.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

if ! type log_info >/dev/null 2>&1; then
  log_info()    { printf '[info] %s\n' "$*"; }
  log_success() { printf '[ ok] %s\n' "$*"; }
  log_warn()    { printf '[warn] %s\n' "$*" >&2; }
  log_error()   { printf '[err]  %s\n' "$*" >&2; }
fi

# macOS-only. On other OSes, log and exit cleanly so the rest of the
# install isn't blocked by an opt-in module that doesn't apply.
if [[ "$(uname -s)" != "Darwin" ]]; then
  log_info "cua-driver is macOS-only — skipping on $(uname -s)"
  exit 0
fi

UPSTREAM_INSTALLER="${CUA_DRIVER_INSTALLER:-https://raw.githubusercontent.com/trycua/cua/main/libs/cua-driver/scripts/install.sh}"

log_info "cua-driver: running upstream installer from trycua/cua"
log_info "  source: ${UPSTREAM_INSTALLER}"

if ! command -v curl >/dev/null 2>&1; then
  log_error "curl not found — cannot fetch upstream installer"
  exit 1
fi

# Use process substitution so bash sees a real script file rather than
# stdin (matches `bash <(curl …)` in upstream docs and avoids the same
# stdin-from-pipe footgun cappy hit in v1.2.x).
if ! bash <(curl -fsSL "${UPSTREAM_INSTALLER}"); then
  log_error "upstream cua-driver installer failed"
  log_info "retry manually: bash <(curl -fsSL ${UPSTREAM_INSTALLER})"
  exit 1
fi

# ── MCP wire-up ─────────────────────────────────────────────
# Register cua-driver as an MCP server so Claude Code picks it up.
# Idempotent: skip if already registered.
if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -qi 'cua-driver'; then
    log_info "cua-driver already registered as an MCP server — skipping"
  else
    log_info "Registering cua-driver as an MCP server (claude mcp add)"
    if claude mcp add --transport stdio cua-driver -- cua-driver mcp 2>/dev/null; then
      log_success "cua-driver registered with Claude Code"
    else
      log_warn "claude mcp add failed — register manually:"
      log_warn "  claude mcp add --transport stdio cua-driver -- cua-driver mcp"
    fi
  fi
else
  log_info "claude CLI not found — skipping MCP registration"
  log_info "Register later with:"
  log_info "  claude mcp add --transport stdio cua-driver -- cua-driver mcp"
fi

# ── Permissions reminder ───────────────────────────────────
printf '\n'
log_info "cua-driver needs macOS permissions before first use:"
log_info "  • Accessibility (System Settings → Privacy & Security → Accessibility)"
log_info "  • Screen Recording (System Settings → Privacy & Security → Screen Recording)"
log_info "Trigger system prompts with: cua-driver check_permissions"
