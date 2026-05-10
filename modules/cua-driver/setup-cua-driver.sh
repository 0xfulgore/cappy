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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/../../lib/common.sh" ]]; then
  # shellcheck source=../../lib/common.sh
  source "${SCRIPT_DIR}/../../lib/common.sh"
else
  # Standalone fallback (common.sh missing — testing this script
  # directly outside the cappy install flow). Always default "no" on
  # prompts so we never block on a missing dependency.
  log_info()    { printf '[info] %s\n' "$*"; }
  log_success() { printf '[ ok] %s\n' "$*"; }
  log_warn()    { printf '[warn] %s\n' "$*" >&2; }
  log_error()   { printf '[err]  %s\n' "$*" >&2; }
  prompt_yn()   { return 1; }
fi

# macOS-only. On other OSes, log and exit cleanly so the rest of the
# install isn't blocked by an opt-in module that doesn't apply.
if [[ "$(uname -s)" != "Darwin" ]]; then
  log_info "cua-driver is macOS-only — skipping on $(uname -s)"
  exit 0
fi

# Pinned to a specific commit SHA (not the mutable `main` branch ref) to
# prevent supply-chain compromise. Bump this in a deliberate commit when
# upgrading. Last verified: 2026-05-10 against
# `git ls-remote https://github.com/trycua/cua.git main`.
_CUA_PINNED_SHA="708b4233b8161e8e404bdbc7dd8b8a5e4e0dd054"
_CUA_PINNED_URL="https://raw.githubusercontent.com/trycua/cua/${_CUA_PINNED_SHA}/libs/cua-driver/scripts/install.sh"

# CUA_DRIVER_INSTALLER override is allowed ONLY when it points to the
# official trycua/cua raw content host. Any other value is an injection
# vector (e.g. a malicious .envrc) and is rejected.
if [[ -n "${CUA_DRIVER_INSTALLER:-}" ]]; then
  if [[ "${CUA_DRIVER_INSTALLER}" != https://raw.githubusercontent.com/trycua/cua/* ]]; then
    log_error "CUA_DRIVER_INSTALLER override rejected: must start with"
    log_error "  https://raw.githubusercontent.com/trycua/cua/"
    log_error "Got: ${CUA_DRIVER_INSTALLER}"
    exit 1
  fi
  UPSTREAM_INSTALLER="${CUA_DRIVER_INSTALLER}"
else
  UPSTREAM_INSTALLER="${_CUA_PINNED_URL}"
fi

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
# cua-driver MUST be at user scope so it's available in every project.
# Pre-user-scope installs registered at default (local) scope. Migration:
# detect local-scope registration, remove it, re-register at user scope.

CUA_DRIVER_MCP_NAME="cua-driver"

_cua_mcp_registered_anywhere() {
  claude mcp list 2>/dev/null | grep -qi "$CUA_DRIVER_MCP_NAME"
}

_cua_mcp_registered_at_user_scope() {
  # claude mcp get reports "Scope: User config" when registered at user scope.
  claude mcp get "$CUA_DRIVER_MCP_NAME" 2>/dev/null | grep -q "Scope: User config"
}

_cua_mcp_registered_at_local_scope() {
  claude mcp get "$CUA_DRIVER_MCP_NAME" 2>/dev/null | grep -q "Scope: Local config"
}

if command -v claude >/dev/null 2>&1; then
  # Already at user scope — nothing to do.
  if _cua_mcp_registered_at_user_scope; then
    log_info "cua-driver already registered as an MCP server at user scope — skipping"
  else
    # Migrate from pre-user-scope local-scope registration.
    if _cua_mcp_registered_at_local_scope; then
      log_info "Migrating '$CUA_DRIVER_MCP_NAME' from local scope to user scope (so it works in every project)..."
      if claude mcp remove "$CUA_DRIVER_MCP_NAME" >/dev/null 2>&1; then
        log_success "Removed local-scope registration"
      else
        log_warn "Failed to remove local-scope cua-driver — continuing, user-scope add may fail"
      fi
    fi

    # Some other shape exists (HTTP / project-scope / etc.) — leave it alone.
    if _cua_mcp_registered_anywhere && ! _cua_mcp_registered_at_local_scope; then
      log_info "cua-driver present at non-local scope — leaving as-is"
    else
      log_info "Registering cua-driver as an MCP server at user scope (claude mcp add)"
      if claude mcp add --scope user --transport stdio "$CUA_DRIVER_MCP_NAME" -- cua-driver mcp 2>/dev/null; then
        log_success "cua-driver registered with Claude Code (user scope — works in every project)"
      else
        log_warn "claude mcp add failed — register manually:"
        log_warn "  claude mcp add --scope user --transport stdio $CUA_DRIVER_MCP_NAME -- cua-driver mcp"
      fi
    fi
  fi
else
  log_info "claude CLI not found — skipping MCP registration"
  log_info "Register later with:"
  log_info "  claude mcp add --scope user --transport stdio $CUA_DRIVER_MCP_NAME -- cua-driver mcp"
fi

# ── Permissions: trigger the macOS dialogs ──────────────────
# cua-driver needs Accessibility + Screen Recording before it can do
# anything useful. The system only raises the dialogs when an app
# actually tries to use the APIs — `open … CuaDriver --args serve`
# does that. Then `check_permissions` confirms the grants stuck.
#
# We offer to do this for the user instead of just printing a reminder
# they'll skim past. Skip the prompt under --non-interactive.
printf '\n'
log_info "cua-driver needs macOS permissions before first use:"
log_info "  • Accessibility (System Settings → Privacy & Security → Accessibility)"
log_info "  • Screen Recording (System Settings → Privacy & Security → Screen Recording)"

if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
  log_info "Non-interactive mode — skipping permission prompt."
  log_info "Trigger the system dialogs later with:"
  log_info "  open -n -g -a CuaDriver --args serve"
  log_info "  cua-driver check_permissions"
  exit 0
fi

if ! prompt_yn "Open the macOS permission dialogs now?" "y"; then
  log_info "Skipped. Trigger them later with:"
  log_info "  open -n -g -a CuaDriver --args serve"
  log_info "  cua-driver check_permissions"
  exit 0
fi

# Launch CuaDriver in the background so the macOS API calls fire and
# the system raises Accessibility + Screen Recording dialogs. -g keeps
# focus in the terminal; -n forces a fresh instance.
log_info "Launching CuaDriver to raise permission dialogs..."
if ! open -n -g -a CuaDriver --args serve 2>/dev/null; then
  log_warn "Could not launch CuaDriver via 'open -a' — the app may not be installed yet."
  log_info "Run manually after installation completes:"
  log_info "  open -n -g -a CuaDriver --args serve"
  log_info "  cua-driver check_permissions"
  exit 0
fi

log_info "Grant Accessibility + Screen Recording in the system dialogs."
log_info "Press Enter once you've granted both, or Ctrl+C to skip verification."
read -r _ || true

# Confirm. cua-driver check_permissions returns non-zero if anything
# is still missing, which is fine — we surface it instead of failing
# the install.
if command -v cua-driver >/dev/null 2>&1; then
  log_info "Verifying permissions with: cua-driver check_permissions"
  if cua-driver check_permissions; then
    log_success "cua-driver permissions confirmed"
  else
    log_warn "Some permissions are still missing — re-run check after granting:"
    log_warn "  cua-driver check_permissions"
  fi
else
  log_warn "cua-driver CLI not on PATH yet — restart your shell, then:"
  log_warn "  cua-driver check_permissions"
fi
