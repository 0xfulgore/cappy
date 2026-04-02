#!/usr/bin/env bash
# Cappy Hook: Post-edit lint
# Auto-lints files after edits using the project's configured linter
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

if [[ "$tool" != "Edit" && "$tool" != "Write" ]]; then exit 0; fi
[[ -z "$file" ]] && exit 0

dir=$(dirname "$file")
while [[ "$dir" != "/" ]]; do
  # ESLint
  if [[ -f "$dir/.eslintrc.js" || -f "$dir/.eslintrc.json" || -f "$dir/.eslintrc.yml" || -f "$dir/.eslintrc.cjs" ]]; then
    cd "$dir"
    npx eslint --fix "$file" 2>&1 | head -20
    exit 0
  fi
  # Biome
  if [[ -f "$dir/biome.json" || -f "$dir/biome.jsonc" ]]; then
    cd "$dir"
    npx biome check --fix "$file" 2>&1 | head -20
    exit 0
  fi
  # Ruff (Python)
  if [[ -f "$dir/pyproject.toml" ]] && [[ "$file" =~ \.py$ ]]; then
    cd "$dir"
    ruff check --fix "$file" 2>&1 | head -20
    exit 0
  fi
  # Cargo clippy (Rust)
  if [[ -f "$dir/Cargo.toml" ]] && [[ "$file" =~ \.rs$ ]]; then
    cd "$dir"
    cargo clippy --fix --allow-dirty -- -W clippy::all 2>&1 | head -20
    exit 0
  fi
  dir=$(dirname "$dir")
done
