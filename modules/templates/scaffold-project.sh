#!/usr/bin/env bash
# Cappy — Project CLAUDE.md Scaffolder
# Generate a project-level CLAUDE.md from templates
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to find templates relative to script or in the cappy install
if [[ -d "${SCRIPT_DIR}/../../modules/templates" ]]; then
  TEMPLATES_DIR="${SCRIPT_DIR}/../../modules/templates"
elif [[ -d "${SCRIPT_DIR}" ]]; then
  TEMPLATES_DIR="${SCRIPT_DIR}"
else
  echo "Error: Cannot find templates directory"
  exit 1
fi

usage() {
  cat << 'EOF'
Usage: scaffold-project.sh [template] [options]

Templates:
  react-nextjs       Next.js + TypeScript + App Router
  rust-api           Rust API server
  python-ml          Python ML/data science project
  expo-mobile        Expo / React Native mobile app
  generic-fullstack  Generic fullstack project

Options:
  --name NAME        Project name
  --output PATH      Output path (default: ./CLAUDE.md)
  --help             Show this help

If no template is specified, you'll be prompted interactively.
EOF
}

main() {
  local template=""
  local project_name=""
  local output="./CLAUDE.md"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)   project_name="$2"; shift 2 ;;
      --output) output="$2"; shift 2 ;;
      --help)   usage; exit 0 ;;
      -*)       echo "Unknown option: $1"; usage; exit 1 ;;
      *)        template="$1"; shift ;;
    esac
  done

  # Interactive template selection
  if [[ -z "$template" ]]; then
    echo ""
    echo "Select a project template:"
    echo ""
    echo "  1) react-nextjs       — Next.js + TypeScript"
    echo "  2) rust-api           — Rust API server"
    echo "  3) python-ml          — Python ML project"
    echo "  4) expo-mobile        — Expo / React Native"
    echo "  5) generic-fullstack  — Generic fullstack"
    echo ""
    printf "Choose [1-5]: "
    read -r choice
    case "$choice" in
      1) template="react-nextjs" ;;
      2) template="rust-api" ;;
      3) template="python-ml" ;;
      4) template="expo-mobile" ;;
      5) template="generic-fullstack" ;;
      *) echo "Invalid choice"; exit 1 ;;
    esac
  fi

  local template_file="${TEMPLATES_DIR}/${template}.md"
  if [[ ! -f "$template_file" ]]; then
    echo "Error: Template '$template' not found at $template_file"
    exit 1
  fi

  if [[ -z "$project_name" ]]; then
    project_name=$(basename "$(pwd)")
    printf "Project name [%s]: " "$project_name"
    read -r input
    [[ -n "$input" ]] && project_name="$input"
  fi

  # Read template and substitute project name
  local content
  content=$(cat "$template_file")
  content="${content//\{\{PROJECT_NAME\}\}/$project_name}"

  # Replace remaining placeholders with sensible prompts
  local placeholders
  placeholders=$(echo "$content" | grep -oE '\{\{[A-Z_]+\}\}' | sort -u || true)

  for ph in $placeholders; do
    local var_name="${ph//\{\{/}"
    var_name="${var_name//\}\}/}"
    local display_name="${var_name//_/ }"
    display_name=$(echo "$display_name" | tr '[:upper:]' '[:lower:]')

    printf "  %s: " "$display_name"
    read -r value
    [[ -z "$value" ]] && value="TODO"
    content="${content//$ph/$value}"
  done

  echo "$content" > "$output"
  echo ""
  echo "Created $output for '$project_name' using '$template' template."
  echo "Edit it to match your project specifics."
}

main "$@"
