#!/usr/bin/env bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Uninstall
# Remove cappy-installed files and optionally restore backup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if ! command -v jq >/dev/null 2>&1; then
  printf '[err]  jq is required to uninstall cappy. Install jq first.\n' >&2
  exit 1
fi

CAPPY_HOME="${HOME}/.cappy"
CAPPY_INSTALLED_JSON="${CAPPY_HOME}/installed.json"
CLAUDE_HOME="${HOME}/.claude"

RST=$'\e[0m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
CYAN=$'\e[36m'
BOLD=$'\e[1m'

log_info()    { printf "%s[info]%s  %s\n" "$CYAN"   "$RST" "$*"; }
log_success() { printf "%s[  ok]%s  %s\n" "$GREEN"  "$RST" "$*"; }
log_warn()    { printf "%s[warn]%s  %s\n" "$YELLOW" "$RST" "$*"; }

main() {
  printf "\n%s  Cappy Uninstaller%s\n\n" "$BOLD" "$RST"

  if [[ ! -f "$CAPPY_INSTALLED_JSON" ]]; then
    log_warn "No cappy installation found at $CAPPY_INSTALLED_JSON"
    exit 0
  fi

  local version
  version=$(jq -r '.cappy_version // "unknown"' "$CAPPY_INSTALLED_JSON")
  local backup_path
  backup_path=$(jq -r '.backup_path // "none"' "$CAPPY_INSTALLED_JSON")

  log_info "Found cappy v${version}"

  # Remove cappy-managed sections from CLAUDE.md
  local claude_md="$(pwd)/CLAUDE.md"
  if [[ -f "$claude_md" ]] && grep -q 'cappy:managed-start' "$claude_md"; then
    log_info "Removing cappy sections from CLAUDE.md"
    local before after
    before=$(sed -n '1,/<!-- cappy:managed-start -->/p' "$claude_md" | sed '$ d')
    after=$(sed -n '/<!-- cappy:managed-end -->/,$p' "$claude_md" | sed '1 d')
    # Also remove the separator line
    before=$(echo "$before" | sed '$ { /^---$/d; }')
    echo "${before}${after}" > "$claude_md"
    log_success "Cleaned CLAUDE.md"
  fi

  # Remove installed hook files
  local hooks=(
    "post-edit-typecheck.sh"
    "post-edit-lint.sh"
    "pre-commit-check.sh"
    "file-guard.sh"
  )
  for hook in "${hooks[@]}"; do
    local hook_file="$CLAUDE_HOME/hooks/$hook"
    if [[ -f "$hook_file" ]]; then
      rm "$hook_file"
      log_success "Removed hook: $hook"
    fi
  done

  # Offer to restore backup
  if [[ "$backup_path" != "none" ]] && [[ -d "$backup_path" ]]; then
    printf "\n  A backup exists at: %s\n" "$backup_path"
    printf "  Restore it? [y/N] "
    read -r ans
    case "$ans" in [Yy]|[Yy][Ee][Ss]) is_yes=1 ;; *) is_yes=0 ;; esac
    if (( is_yes )); then
      # Source backup lib if available
      local repo_dir="${CAPPY_HOME}/repo"
      if [[ -f "$repo_dir/lib/backup.sh" ]]; then
        source "$repo_dir/lib/common.sh"
        source "$repo_dir/lib/backup.sh"
        CLAUDE_HOME="$CLAUDE_HOME" restore_backup "$backup_path"
      else
        log_info "Manual restore: copy files from $backup_path"
      fi
    fi
  fi

  # Clean up cappy home
  rm -f "$CAPPY_INSTALLED_JSON"
  log_success "Removed installation record"

  printf "\n  Cappy has been removed.\n"
  printf "  Your settings.json was NOT modified (remove cappy entries manually if needed).\n"
  printf "  Backup preserved at: %s\n\n" "$backup_path"
}

main "$@"
