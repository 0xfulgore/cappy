#!/usr/bin/env bash
# Cappy — Team Template Scaffolder
# Instantiate a multi-agent team from a template
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../../lib/common.sh" ]]; then
  source "${SCRIPT_DIR}/../../lib/common.sh"
  detect_os
else
  log_info()    { printf "[info]  %s\n" "$*"; }
  log_success() { printf "[  ok]  %s\n" "$*"; }
  log_error()   { printf "[ err]  %s\n" "$*" >&2; }
fi

usage() {
  cat << 'EOF'
Usage: scaffold-team.sh <template> [options]

Templates:
  product-sdlc     8-agent full SDLC pipeline (discovery → spec → design → build → review → QA)
  fullstack-api    6-agent API build team (architect, backend, frontend, test, docs)
  code-review      3-agent review pipeline (security, quality)
  docs-sprint      4-agent documentation team (API, guides, architecture)
  refactor-squad   5-agent refactoring team (analyzer, 2 refactors, test guardian)

Options:
  --name NAME        Team name (required)
  --description DESC Team description
  --dir PATH         Project directory (default: current dir)
  --tech STACK       Technology stack description
  --help             Show this help

Example:
  scaffold-team.sh fullstack-api \
    --name payments-api \
    --description "Building the payments microservice" \
    --tech "Rust with Actix-Web, SQLx, PostgreSQL"
EOF
}

main() {
  local template=""
  local team_name=""
  local description=""
  local project_dir="$(pwd)"
  local tech_stack=""

  # Parse args
  [[ $# -eq 0 ]] && { usage; exit 1; }
  template="$1"; shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)        team_name="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      --dir)         project_dir="$2"; shift 2 ;;
      --tech)        tech_stack="$2"; shift 2 ;;
      --help)        usage; exit 0 ;;
      *)             log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  # Validate
  local template_file="${TEMPLATES_DIR}/${template}/team.json"
  if [[ ! -f "$template_file" ]]; then
    log_error "Template '$template' not found. Available: $(ls "$TEMPLATES_DIR")"
    exit 1
  fi

  if [[ -z "$team_name" ]]; then
    printf "Team name: "
    read -r team_name
  fi
  if [[ -z "$description" ]]; then
    printf "Team description: "
    read -r description
  fi
  if [[ -z "$tech_stack" ]]; then
    printf "Tech stack: "
    read -r tech_stack
  fi

  # Substitute variables
  local output
  output=$(cat "$template_file" \
    | sed "s|{{TEAM_NAME}}|$team_name|g" \
    | sed "s|{{TEAM_DESCRIPTION}}|$description|g" \
    | sed "s|{{PROJECT_DIR}}|$project_dir|g" \
    | sed "s|{{PROJECT_DESCRIPTION}}|$description|g" \
    | sed "s|{{TECH_STACK}}|$tech_stack|g")

  # Write to team config
  local team_dir="$HOME/.claude/teams/${team_name}"
  mkdir -p "$team_dir"
  echo "$output" | jq '.' > "$team_dir/config.json"

  log_success "Team '$team_name' created at $team_dir/config.json"
  log_info "Template: $template ($(jq '.members | length' "$team_dir/config.json") agents)"
  printf "\n  To use this team, start Claude Code and reference it in your conversation.\n"
}

main "$@"
