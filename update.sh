#!/usr/bin/env bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Update
# Pull latest changes and re-apply modules
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAPPY_HOME="${HOME}/.cappy"
CAPPY_REPO_DIR="${CAPPY_HOME}/repo"
CAPPY_INSTALLED_JSON="${CAPPY_HOME}/installed.json"

main() {
  # Find the repo (either local clone or script directory)
  local repo_dir
  if [[ -d "$CAPPY_REPO_DIR/.git" ]]; then
    repo_dir="$CAPPY_REPO_DIR"
  else
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ ! -f "$repo_dir/forge.json" ]]; then
      echo "Error: Cannot find cappy repo. Run install.sh first."
      exit 1
    fi
  fi

  # Source libraries
  source "$repo_dir/lib/common.sh"
  source "$repo_dir/lib/detect.sh"
  source "$repo_dir/lib/backup.sh"
  source "$repo_dir/lib/merge.sh"
  source "$repo_dir/lib/modules.sh"
  detect_os

  CAPPY_MODULES_DIR="${repo_dir}/modules"
  export CAPPY_MODULES_DIR

  local old_version="unknown"
  if [[ -f "$CAPPY_INSTALLED_JSON" ]]; then
    old_version=$(jq -r '.cappy_version // "unknown"' "$CAPPY_INSTALLED_JSON")
  fi

  # Pull latest
  if [[ -d "$repo_dir/.git" ]]; then
    log_step "Pulling latest changes"
    git -C "$repo_dir" pull --quiet
  fi

  local new_version
  new_version=$(jq -r '.version' "$repo_dir/forge.json")

  if [[ "$old_version" == "$new_version" ]]; then
    log_success "Already up to date (v${new_version})"
    return
  fi

  log_info "Updating v${old_version} → v${new_version}"

  # Re-install previously installed modules
  if [[ -f "$CAPPY_INSTALLED_JSON" ]]; then
    detect_claude_home

    local modules
    modules=$(jq -r '.modules | keys[]' "$CAPPY_INSTALLED_JSON" 2>/dev/null)

    log_step "Re-applying installed modules"
    CAPPY_NON_INTERACTIVE=1
    export CAPPY_NON_INTERACTIVE

    while IFS= read -r mod; do
      [[ -z "$mod" ]] && continue
      if [[ -d "${CAPPY_MODULES_DIR}/${mod}" ]]; then
        install_module "$mod"
      else
        log_warn "Module '$mod' no longer exists — skipping"
      fi
    done <<< "$modules"

    # Update installed.json with new version
    local tmp
    tmp=$(jq --arg ver "$new_version" --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      '.cappy_version = $ver | .updated_at = $ts' "$CAPPY_INSTALLED_JSON")
    echo "$tmp" > "$CAPPY_INSTALLED_JSON"
  fi

  log_success "Updated to v${new_version}"
}

main "$@"
