#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Environment detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CLAUDE_HOME="${HOME}/.claude"
CAPPY_HOME="${HOME}/.cappy"
CAPPY_INSTALLED_JSON="${CAPPY_HOME}/installed.json"

detect_claude_home() {
  if [[ ! -d "$CLAUDE_HOME" ]]; then
    log_error "Claude Code config directory not found at $CLAUDE_HOME"
    log_info "Make sure Claude Code is installed: https://claude.ai/code"
    exit 1
  fi
  log_success "Found Claude Code at $CLAUDE_HOME"
}

detect_existing_config() {
  EXISTING_SETTINGS=0
  EXISTING_CLAUDE_MD=0
  EXISTING_HOOKS=0
  EXISTING_SKILLS=0

  [[ -f "$CLAUDE_HOME/settings.json" ]] && EXISTING_SETTINGS=1 && log_info "Existing settings.json found"
  [[ -f "$(pwd)/CLAUDE.md" ]] && EXISTING_CLAUDE_MD=1 && log_info "Existing CLAUDE.md found in $(pwd)"

  if [[ -d "$CLAUDE_HOME/hooks" ]] && ls "$CLAUDE_HOME/hooks"/*.sh &>/dev/null; then
    EXISTING_HOOKS=1
    log_info "Existing hooks found"
  fi

  if [[ -d "${HOME}/.agents/skills" ]] && ls "${HOME}/.agents/skills"/*/ &>/dev/null 2>&1; then
    EXISTING_SKILLS=1
    log_info "Existing skills found"
  fi

  export EXISTING_SETTINGS EXISTING_CLAUDE_MD EXISTING_HOOKS EXISTING_SKILLS
}

detect_installed_modules() {
  CAPPY_PREVIOUSLY_INSTALLED=0
  if [[ -f "$CAPPY_INSTALLED_JSON" ]]; then
    CAPPY_PREVIOUSLY_INSTALLED=1
    local ver
    ver=$(jq -r '.cappy_version // "unknown"' "$CAPPY_INSTALLED_JSON" 2>/dev/null)
    log_info "Previous cappy installation detected (v${ver})"
  fi
  export CAPPY_PREVIOUSLY_INSTALLED
}

print_detection_summary() {
  log_step "Environment Summary"
  printf "  OS:           %s\n" "$CAPPY_OS"
  printf "  Shell:        %s\n" "$CAPPY_SHELL"
  printf "  Claude home:  %s\n" "$CLAUDE_HOME"
  printf "  Settings:     %s\n" "$( (( EXISTING_SETTINGS )) && echo "found" || echo "none" )"
  printf "  CLAUDE.md:    %s\n" "$( (( EXISTING_CLAUDE_MD )) && echo "found" || echo "none" )"
  printf "  Hooks:        %s\n" "$( (( EXISTING_HOOKS )) && echo "found" || echo "none" )"
  printf "  Skills:       %s\n" "$( (( EXISTING_SKILLS )) && echo "found" || echo "none" )"
  printf "  Prior cappy:  %s\n" "$( (( CAPPY_PREVIOUSLY_INSTALLED )) && echo "yes" || echo "no" )"
}
