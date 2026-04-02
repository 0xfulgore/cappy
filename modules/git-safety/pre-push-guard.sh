#!/usr/bin/env bash
# Cappy Hook: Git push safety guard
# Prevents force-push to main/master, warns on push to protected branches
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)

if [[ "$tool" != "Bash" ]]; then exit 0; fi
if [[ ! "$cmd" =~ ^git\ push ]]; then exit 0; fi

# Block force push to main/master
if [[ "$cmd" =~ --force|\ -f|\+main|\+master ]]; then
  if [[ "$cmd" =~ main|master ]]; then
    echo "BLOCKED: Force push to main/master is not allowed."
    echo "If you really need this, the user must run it manually."
    exit 1
  fi
fi

# Warn on push to main/master (non-force)
if [[ "$cmd" =~ main|master ]] && [[ ! "$cmd" =~ origin ]]; then
  echo "WARNING: Pushing directly to main/master. Consider using a feature branch + PR."
fi
