#!/usr/bin/env bash
# Cappy Hook: Post-edit type check
# Runs tsc --noEmit after .ts/.tsx file edits
# Configure in settings.json hooks.postToolUse
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
file=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

if [[ "$tool" != "Edit" && "$tool" != "Write" ]]; then exit 0; fi
if [[ ! "$file" =~ \.(ts|tsx)$ ]]; then exit 0; fi

dir=$(dirname "$file")
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/tsconfig.json" ]]; then
    cd "$dir"
    npx tsc --noEmit --pretty 2>&1 | head -20
    exit "${PIPESTATUS[0]}"
  fi
  dir=$(dirname "$dir")
done
