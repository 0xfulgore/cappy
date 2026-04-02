#!/usr/bin/env bash
# Cappy Hook: Commit message format enforcer
# Ensures commit messages follow conventional commits style
# Runs before git commit commands
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)

if [[ "$tool" != "Bash" ]]; then exit 0; fi
if [[ ! "$cmd" =~ ^git\ commit ]]; then exit 0; fi

# Extract commit message from -m flag
if [[ "$cmd" =~ -m[[:space:]]+\"([^\"]+)\" ]] || [[ "$cmd" =~ -m[[:space:]]+\'([^\']+)\' ]]; then
  msg="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ -m[[:space:]]+([^[:space:]]+) ]]; then
  msg="${BASH_REMATCH[1]}"
else
  # Can't extract message (might be using heredoc or editor), skip check
  exit 0
fi

# Check for conventional commit prefix
if [[ ! "$msg" =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?:\ .+ ]]; then
  echo "NOTE: Commit message doesn't follow conventional commits format."
  echo "  Expected: type(scope): description"
  echo "  Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
  echo "  Example: feat(auth): add OAuth2 login flow"
  echo ""
  echo "  Your message: $msg"
  echo ""
  echo "  (This is a suggestion, not a block — commit will proceed)"
fi
