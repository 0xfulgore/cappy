#!/usr/bin/env bash
# Cappy Hook: Pre-commit verification
# Runs type-check + lint + test before allowing git commit
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)

if [[ "$tool" != "Bash" ]]; then exit 0; fi
if [[ ! "$cmd" =~ ^git\ commit ]]; then exit 0; fi

cwd=$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null)
cd "$cwd"
errors=0

# Type check
if [[ -f "tsconfig.json" ]]; then
  printf "Running type check...\n"
  if ! npx tsc --noEmit 2>&1 | tail -5; then
    printf "Type check failed\n"; errors=$((errors + 1))
  fi
fi
if [[ -f "Cargo.toml" ]]; then
  printf "Running cargo check...\n"
  if ! cargo check 2>&1 | tail -5; then
    printf "Cargo check failed\n"; errors=$((errors + 1))
  fi
fi

# Lint
if [[ -f ".eslintrc.js" || -f ".eslintrc.json" || -f ".eslintrc.cjs" ]]; then
  printf "Running ESLint...\n"
  if ! npx eslint . --quiet 2>&1 | tail -10; then
    printf "Lint failed\n"; errors=$((errors + 1))
  fi
fi
if [[ -f "biome.json" ]]; then
  printf "Running Biome...\n"
  if ! npx biome check . 2>&1 | tail -10; then
    printf "Biome check failed\n"; errors=$((errors + 1))
  fi
fi

# Tests
if [[ -f "package.json" ]] && jq -e '.scripts.test' package.json &>/dev/null; then
  printf "Running tests...\n"
  if ! npm test 2>&1 | tail -10; then
    printf "Tests failed\n"; errors=$((errors + 1))
  fi
fi

if [[ "$errors" -gt 0 ]]; then
  printf "\nPre-commit check failed with %d error(s). Fix issues before committing.\n" "$errors"
  exit 1
fi
printf "All pre-commit checks passed\n"
