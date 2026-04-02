#!/usr/bin/env bash
# Cappy Hook: File guard
# Prevents Claude from editing sensitive files
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

if [[ "$tool" != "Edit" && "$tool" != "Write" && "$tool" != "MultiEdit" ]]; then exit 0; fi
[[ -z "$file" ]] && exit 0

PROTECTED_PATTERNS=(
  "*.env"
  "*.env.*"
  "*credentials*"
  "*secret*"
  "*.pem"
  "*.key"
  "*.p12"
  "*.pfx"
  "*id_rsa*"
  "*id_ed25519*"
  ".git/config"
  "*.keystore"
)

filename=$(basename "$file")
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  # shellcheck disable=SC2254
  case "$filename" in
    $pattern)
      echo "BLOCKED: $file matches protected pattern '$pattern'"
      echo "This file may contain secrets. Edit it manually if needed."
      exit 1
      ;;
  esac
done

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  # shellcheck disable=SC2254
  case "$file" in
    */$pattern)
      echo "BLOCKED: $file matches protected pattern '$pattern'"
      exit 1
      ;;
  esac
done
