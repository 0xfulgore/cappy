#!/usr/bin/env bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Claude Code Power-User Toolkit Installer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAPPY_VERSION="1.0.0"
CAPPY_REPO="https://github.com/garyshannon/cappy.git"

# ── Banner ───────────────────────────────────────────────────
print_banner() {
  cat << 'BANNER'

  ██████╗ █████╗ ██████╗ ██████╗ ██╗   ██╗
 ██╔════╝██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
 ██║     ███████║██████╔╝██████╔╝ ╚████╔╝
 ██║     ██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝
 ╚██████╗██║  ██║██║     ██║        ██║
  ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝

BANNER
  printf "  Claude Code Power-User Toolkit v%s\n\n" "$CAPPY_VERSION"
}

# ── Usage ────────────────────────────────────────────────────
print_usage() {
  cat << 'USAGE'
Usage: install.sh [options]

Options:
  --modules LIST    Comma-separated modules to install (default: all)
                    Available: core,auto-update,statusline,settings,hooks,mcp,teams,skills,templates
  --preset NAME     Settings preset: power-user, cautious, team-lead (default: power-user)
  --claude-md PATH  Where to install CLAUDE.md (default: current directory)
  --no-backup       Skip backup step
  --non-interactive Skip all prompts, use defaults
  --link            Dev mode: symlink ~/.cappy/repo → this clone
                    instead of cloning fresh. Cappy will break if you
                    delete or move this clone — use only for cappy
                    development. Without --link, the default is to
                    clone the remote into ~/.cappy/repo so cappy is
                    self-contained.
  --help            Show this help

Examples:
  # Interactive install (recommended)
  ./install.sh

  # Install everything non-interactively
  ./install.sh --non-interactive

  # Install only core directives and statusline
  ./install.sh --modules core,statusline

  # Curl-pipe install
  curl -fsSL https://raw.githubusercontent.com/garyshannon/cappy/main/install.sh | bash
USAGE
}

# ── Resolve script location ─────────────────────────────────
resolve_cappy_dir() {
  # If we have lib/ locally, we're running from a cloned repo
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -d "$script_dir/lib" ]] && [[ -d "$script_dir/modules" ]]; then
    CAPPY_DIR="$script_dir"
    return
  fi

  # Running from curl pipe — clone the repo first
  local clone_target="${HOME}/.cappy/repo"
  printf "Downloading cappy...\n"

  if [[ -d "$clone_target/.git" ]]; then
    git -C "$clone_target" pull --quiet 2>/dev/null || true
  else
    mkdir -p "$(dirname "$clone_target")"
    git clone --quiet "$CAPPY_REPO" "$clone_target"
  fi

  CAPPY_DIR="$clone_target"
}

# ── Parse arguments ──────────────────────────────────────────
parse_args() {
  CAPPY_SELECTED_MODULES=""
  CAPPY_SETTINGS_PRESET="power-user"
  CAPPY_CLAUDE_MD_TARGET=""
  CAPPY_SKIP_BACKUP=0
  CAPPY_NON_INTERACTIVE=""
  CAPPY_LINK_MODE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --modules)     CAPPY_SELECTED_MODULES="$2"; shift 2 ;;
      --preset)      CAPPY_SETTINGS_PRESET="$2"; shift 2 ;;
      --claude-md)   CAPPY_CLAUDE_MD_TARGET="$2"; shift 2 ;;
      --no-backup)   CAPPY_SKIP_BACKUP=1; shift ;;
      --non-interactive) CAPPY_NON_INTERACTIVE=1; shift ;;
      --link)        CAPPY_LINK_MODE=1; shift ;;
      --help)        print_usage; exit 0 ;;
      *)             printf "Unknown option: %s\n" "$1"; print_usage; exit 1 ;;
    esac
  done

  export CAPPY_SETTINGS_PRESET CAPPY_CLAUDE_MD_TARGET CAPPY_NON_INTERACTIVE
}

# ── Module selection ─────────────────────────────────────────
select_modules() {
  local all_modules=(
    "core"
    "auto-update"
    "statusline"
    "settings"
    "hooks"
    "hedge-detector"
    "git-safety"
    "mcp"
    "teams"
    "skills"
    "templates"
    "performance"
    "accessibility"
    "devops"
    "api-design"
    "ruflo"
    "mempalace"
  )

  if [[ -n "$CAPPY_SELECTED_MODULES" ]]; then
    IFS=',' read -ra MODULES <<< "$CAPPY_SELECTED_MODULES"
    return
  fi

  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    MODULES=("${all_modules[@]}")
    return
  fi

  local descriptions=(
    "core           SDLC pipeline + 18 mechanical overrides (the engine)"
    "auto-update    cappy CLI shim + 24h-cadence update notifier in statusline"
    "statusline     Animated status bar: git, context %, tasks, cost, ETA"
    "settings       settings.json presets: power-user / cautious / team-lead"
    "hooks          Auto typecheck, lint, pre-commit gate, file guard"
    "hedge-detector Stop hook that rejects hedging (probably/I think/seems/could be)"
    "git-safety     Block force-push to main, conventional commit hints"
    "mcp            MCP servers: GitHub, Linear, PostgreSQL, Playwright"
    "teams          Agent swarm templates: SDLC, API, review, docs, refactor"
    "skills         Task progress dashboard + skill discovery"
    "templates      Project CLAUDE.md generators: React, Rust, Python, Expo"
    "performance    Perf directives: bundle size, N+1 queries, lazy loading"
    "accessibility  WCAG 2.2 AA: keyboard nav, screen readers, contrast"
    "devops         CI/CD awareness, env var safety, Docker, migrations"
    "api-design     REST conventions, validation, pagination, error handling"
    "ruflo          Ruflo agent platform: marketplace + 8 plugins + MCP server"
    "mempalace      MemPalace local-first AI memory (pip + MCP server, user scope)"
  )

  local selected
  selected=$(prompt_multiselect "Which modules would you like to install?" "${descriptions[@]}")

  MODULES=()
  while IFS= read -r idx; do
    [[ -n "$idx" ]] && MODULES+=("${all_modules[$idx]}")
  done <<< "$selected"

  if [[ ${#MODULES[@]} -eq 0 ]]; then
    log_error "No modules selected. Nothing to install."
    exit 1
  fi

  printf "\n  %sSelected:%s %s\n" "$BOLD" "$RST" "${MODULES[*]}"
}

# ── CLAUDE.md location selection ──────────────────────────────
select_claude_md_target() {
  local has_core=0
  for mod in "${MODULES[@]}"; do
    [[ "$mod" == "core" ]] && has_core=1 && break
  done
  (( !has_core )) && return

  # If already specified via flag, use that
  if [[ -n "${CAPPY_CLAUDE_MD_TARGET:-}" ]]; then return; fi

  # Auto-detect the best default:
  # 1. Find an existing CLAUDE.md walking up from cwd
  # 2. Find a common dev root directory (~/Development, ~/dev, ~/projects, etc.)
  # 3. Fall back to home directory
  local default_dir=""

  # Check for existing CLAUDE.md up the tree (highest one wins)
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]] && [[ "$dir" != "$HOME" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      default_dir="$dir"
    fi
    dir=$(dirname "$dir")
  done

  # If none found, check common dev root directories
  if [[ -z "$default_dir" ]]; then
    for candidate in "$HOME/Development" "$HOME/dev" "$HOME/projects" "$HOME/code" "$HOME/src" "$HOME/workspace"; do
      if [[ -d "$candidate" ]]; then
        default_dir="$candidate"
        break
      fi
    done
  fi

  # Last resort: home directory
  [[ -z "$default_dir" ]] && default_dir="$HOME"

  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    CAPPY_CLAUDE_MD_TARGET="${default_dir}/CLAUDE.md"
    export CAPPY_CLAUDE_MD_TARGET
    return
  fi

  printf "\n"
  log_info "Cappy installs a CLAUDE.md with the SDLC pipeline directives."
  log_info "Claude Code walks UP the directory tree to find CLAUDE.md files."
  log_info "So installing at your top-level projects folder makes it active EVERYWHERE."
  printf "\n"
  printf "  Where do all your projects live? [%s]: " "$default_dir"
  read -r user_input
  local chosen="${user_input:-$default_dir}"

  # Expand ~ if user typed it
  chosen="${chosen/#\~/$HOME}"

  if [[ ! -d "$chosen" ]]; then
    log_warn "$chosen doesn't exist. Creating it."
    mkdir -p "$chosen"
  fi

  CAPPY_CLAUDE_MD_TARGET="${chosen}/CLAUDE.md"
  export CAPPY_CLAUDE_MD_TARGET
  log_success "CLAUDE.md → $CAPPY_CLAUDE_MD_TARGET (covers all projects under $chosen/)"
}

# ── Settings preset selection ────────────────────────────────
select_preset() {
  # Only ask if settings module is selected
  local has_settings=0
  for mod in "${MODULES[@]}"; do
    [[ "$mod" == "settings" ]] && has_settings=1 && break
  done
  (( !has_settings )) && return

  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then return; fi

  local choice
  choice=$(prompt_select "Settings preset:" \
    "power-user  — Full permissions, agent teams, auto-dream" \
    "cautious    — Restricted permissions, safer defaults" \
    "team-lead   — Optimized for multi-agent coordination")

  case "$choice" in
    0) CAPPY_SETTINGS_PRESET="power-user" ;;
    1) CAPPY_SETTINGS_PRESET="cautious" ;;
    2) CAPPY_SETTINGS_PRESET="team-lead" ;;
  esac
  export CAPPY_SETTINGS_PRESET
}

# ── MCP server selection ─────────────────────────────────────
select_mcp_servers() {
  local has_mcp=0
  for mod in "${MODULES[@]}"; do
    [[ "$mod" == "mcp" ]] && has_mcp=1 && break
  done
  (( !has_mcp )) && return

  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    CAPPY_MCP_SERVERS="github,linear,postgres,playwright"
    export CAPPY_MCP_SERVERS
    return
  fi

  local descriptions=(
    "GitHub     — PR/issue management, code search"
    "Linear     — Ticket claim/transition/comment (OAuth via browser)"
    "PostgreSQL — Database queries and exploration"
    "Playwright — Browser automation and testing"
  )

  log_step "MCP Server Selection"
  local selected
  selected=$(prompt_multiselect "Select MCP servers to configure:" "${descriptions[@]}")

  local servers=("github" "linear" "postgres" "playwright")
  local chosen=()
  while IFS= read -r idx; do
    [[ -n "$idx" ]] && chosen+=("${servers[$idx]}")
  done <<< "$selected"

  CAPPY_MCP_SERVERS=$(IFS=','; echo "${chosen[*]}")
  export CAPPY_MCP_SERVERS
}

# ── Verification ─────────────────────────────────────────────
verify_installation() {
  log_step "Verification"
  local errors=0

  # Check settings.json is valid JSON
  if [[ -f "$CLAUDE_HOME/settings.json" ]]; then
    if jq '.' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1; then
      log_success "settings.json is valid JSON"
    else
      log_error "settings.json is invalid JSON!"
      errors=$((errors + 1))
    fi
  fi

  # Check scripts are executable
  if [[ -f "$CLAUDE_HOME/hooks/task-progress-statusline.sh" ]]; then
    if [[ -x "$CLAUDE_HOME/hooks/task-progress-statusline.sh" ]]; then
      log_success "Statusline hook is executable"
    else
      log_error "Statusline hook is not executable"
      errors=$((errors + 1))
    fi
  fi

  # Check CLAUDE.md was written
  local target="${CAPPY_CLAUDE_MD_TARGET:-$(pwd)/CLAUDE.md}"
  if [[ -f "$target" ]]; then
    log_success "CLAUDE.md installed at $target"
  fi

  return $errors
}

# ── Summary ──────────────────────────────────────────────────
print_summary() {
  log_step "Installation Complete!"

  printf "\n  %sModules installed:%s\n" "$BOLD" "$RST"
  for mod in "${MODULES[@]}"; do
    printf "    %s✓%s %s\n" "$GREEN" "$RST" "$mod"
  done

  if [[ -n "${BACKUP_DIR:-}" ]]; then
    printf "\n  %sBackup:%s %s\n" "$BOLD" "$RST" "$BACKUP_DIR"
  fi

  if [[ -n "${CAPPY_CLAUDE_MD_TARGET:-}" ]]; then
    local md_dir
    md_dir=$(dirname "$CAPPY_CLAUDE_MD_TARGET")
    printf "\n  %sSDLC Pipeline:%s Active in ALL projects under %s/\n" "$BOLD" "$RST" "$md_dir"
    printf "  Just run %sclaude%s in any project directory and start working.\n" "$CYAN" "$RST"
    printf "  The SDLC pipeline kicks in automatically for non-trivial tasks.\n"
    printf "  Say %s\"just do it\"%s or %s\"skip the process\"%s to bypass.\n" "$CYAN" "$RST" "$CYAN" "$RST"
  fi

  printf "\n  %sNext steps:%s\n" "$BOLD" "$RST"
  printf "    1. Restart Claude Code to pick up new settings\n"
  printf "    2. Open any project and try: %sclaude \"Add a user dashboard\"%s\n" "$CYAN" "$RST"
  printf "    3. Claude will automatically: discover → spec → design → build → review → validate\n"

  printf "\n  %sLearn more:%s https://github.com/garyshannon/cappy\n\n" "$DIM" "$RST"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Canonical-repo location
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# Cappy needs a stable on-disk location that survives the user
# deleting or moving the source they ran install.sh from. We default
# to a self-contained clone at ~/.cappy/repo. --link opts into a
# symlink for cappy maintainers (footgun: deleting the source breaks
# the install).

# Real-path comparison that works whether realpath exists or not.
_cappy_same_path() {
  local a b
  if command -v realpath >/dev/null 2>&1; then
    a=$(realpath "$1" 2>/dev/null) || return 1
    b=$(realpath "$2" 2>/dev/null) || return 1
  else
    a=$(cd "$1" 2>/dev/null && pwd -P) || return 1
    b=$(cd "$2" 2>/dev/null && pwd -P) || return 1
  fi
  [[ "$a" == "$b" ]]
}

# Symlink path (--link mode). Warns about fragility.
_cappy_link_repo() {
  local target="$1"
  log_warn "Dev mode: symlinking $target → $CAPPY_DIR"
  log_warn "If you delete or move $CAPPY_DIR, cappy will break."
  log_warn "To switch to a self-contained install: bash $CAPPY_DIR/install.sh (without --link)"
  rm -f "$target" 2>/dev/null || true
  ln -s "$CAPPY_DIR" "$target"
  log_success "linked $target → $CAPPY_DIR"
}

# Fresh clone path (default). Pulls if target already a real clone.
# Re-execs install.sh from the canonical path so the rest of the run
# operates on the self-contained copy, not the source.
ensure_cappy_repo() {
  local home="$HOME/.cappy"
  local target="$home/repo"
  mkdir -p "$home"

  # Already running from the canonical path — nothing to canonicalize.
  if _cappy_same_path "$CAPPY_DIR" "$target"; then
    return
  fi

  # Re-entry guard so we don't loop after exec.
  if [[ "${CAPPY_REPO_CANONICAL:-}" == "1" ]]; then
    return
  fi

  # --link opt-in: symlink and continue from the source (no re-exec).
  if (( ${CAPPY_LINK_MODE:-0} )); then
    if [[ -L "$target" ]]; then
      _cappy_link_repo "$target"
    elif [[ -d "$target" ]]; then
      log_warn "$target exists as a real directory — refusing to replace with a symlink"
      log_warn "remove it first if you really want --link mode: rm -rf $target"
      exit 1
    elif [[ -e "$target" ]]; then
      log_warn "$target exists and isn't a directory or symlink — skipping --link"
      exit 1
    else
      _cappy_link_repo "$target"
    fi
    return
  fi

  # Default: clone-fresh (or pull if a real clone already exists)
  if [[ -L "$target" ]]; then
    log_info "Replacing existing symlink at $target with a fresh clone"
    rm -f "$target"
  fi

  if [[ -d "$target/.git" ]]; then
    log_step "Updating canonical clone at $target"
    if ! git -C "$target" pull --ff-only --quiet; then
      log_warn "git pull failed in $target — continuing with what's there"
    fi
  elif [[ -d "$target" ]]; then
    log_error "$target exists but isn't a git checkout — refusing to clobber"
    log_info "If it's safe to remove: rm -rf $target && rerun this installer"
    exit 1
  else
    local remote branch
    remote=$(git -C "$CAPPY_DIR" config --get remote.origin.url 2>/dev/null || true)
    branch=$(git -C "$CAPPY_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)

    if [[ -z "$remote" ]]; then
      log_warn "No git remote in $CAPPY_DIR — copying tree to $target"
      cp -R "$CAPPY_DIR" "$target"
    else
      log_step "Cloning $remote → $target (self-contained install)"
      if ! git clone --quiet --branch "$branch" "$remote" "$target" 2>/dev/null; then
        # Branch might not exist on remote (e.g., local-only feature branch).
        # Fall back to default branch.
        if ! git clone --quiet "$remote" "$target"; then
          log_error "git clone failed for $remote"
          log_info "Pass --link to use the source clone in-place instead (fragile)"
          exit 1
        fi
        log_warn "Branch '$branch' not on remote — using default branch in $target"
      fi
    fi
  fi

  if [[ -n "$(git -C "$CAPPY_DIR" status --porcelain 2>/dev/null)" ]]; then
    log_warn "$CAPPY_DIR has uncommitted changes."
    log_warn "Those won't be in $target until you commit, push, then run 'cappy update'."
  fi

  log_step "Continuing install from $target"
  exec env CAPPY_REPO_CANONICAL=1 bash "$target/install.sh" "$@"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  print_banner
  parse_args "$@"
  resolve_cappy_dir

  # Source library functions
  # shellcheck source=lib/common.sh
  source "$CAPPY_DIR/lib/common.sh"
  # shellcheck source=lib/detect.sh
  source "$CAPPY_DIR/lib/detect.sh"
  # shellcheck source=lib/backup.sh
  source "$CAPPY_DIR/lib/backup.sh"
  # shellcheck source=lib/merge.sh
  source "$CAPPY_DIR/lib/merge.sh"
  # shellcheck source=lib/modules.sh
  source "$CAPPY_DIR/lib/modules.sh"

  # Canonicalize first — this may exec from ~/.cappy/repo and never
  # return. After this call, CAPPY_DIR is guaranteed to be the install
  # location cappy will keep using.
  ensure_cappy_repo "$@"

  CAPPY_MODULES_DIR="${CAPPY_DIR}/modules"
  export CAPPY_MODULES_DIR

  # Tell post_install hooks (e.g. auto-update/setup.sh) where the repo
  # is so they don't have to guess.
  export CAPPY_REPO="$CAPPY_DIR"


  # Phase 1: Environment Detection
  log_step "Phase 1: Environment Detection"
  detect_os
  detect_shell
  ensure_jq
  detect_claude_home
  detect_existing_config
  detect_installed_modules
  print_detection_summary

  # Phase 2: Backup
  if (( !CAPPY_SKIP_BACKUP )); then
    log_step "Phase 2: Backup"
    create_backup
  else
    log_info "Skipping backup (--no-backup)"
  fi

  # Phase 3: Module Selection
  log_step "Phase 3: Module Selection"
  select_modules

  # Phase 4: Configuration
  log_step "Phase 4: Configuration"
  select_claude_md_target
  select_preset
  select_mcp_servers

  # Phase 5: Installation
  log_step "Phase 5: Installing Modules"
  resolve_dependencies
  if ! check_conflicts; then
    if ! prompt_yn "Continue despite conflicts?"; then
      log_error "Installation cancelled."
      exit 1
    fi
  fi

  for mod in "${MODULES[@]}"; do
    install_module "$mod"
  done

  record_installation "${MODULES[@]}"

  # Phase 6: Verification
  if ! verify_installation; then
    log_warn "Some verifications failed — check the errors above."
  fi

  # Phase 7: Summary
  print_summary
}

main "$@"
