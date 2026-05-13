#!/usr/bin/env bash
# Cappy — ruflo-personas SessionStart drift-check hook
# Detects ruflo upgrades + structural drift in installed agents.
# MUST never block session start: any error → silent exit 0.
set -euo pipefail
trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../lib/personas-helpers.sh
source "${SCRIPT_DIR}/../lib/personas-helpers.sh"

# If jq is missing, do nothing.
command -v jq >/dev/null 2>&1 || exit 0

# If no persona map, nothing to drift-check.
[[ -f "$PERSONAS_MAP" ]] || exit 0

current_version=$(get_ruflo_version)
stamped_version=$(jq -r '.ruflo_version_stamp // ""' "$PERSONAS_MAP" 2>/dev/null || true)

# ── Content drift: ruflo version changed → silently re-render aliases ─
if [[ -n "$current_version" && "$current_version" != "$stamped_version" ]]; then
  ALIAS_GENERATOR="${SCRIPT_DIR}/../alias-generator.sh"
  if [[ -f "$ALIAS_GENERATOR" ]]; then
    # Run quietly; any stdout goes to stderr so we never pollute the user's
    # terminal during session start.
    bash "$ALIAS_GENERATOR" >/dev/null 2>&1 || true
  fi
  # Bump the stamp so subsequent sessions don't re-render needlessly.
  set_persona_map_field "ruflo_version_stamp" "$current_version" 2>/dev/null || true
fi

# ── Structural drift: new or removed agents → print one-line notice ─
# Compare currently-installed agents against the `known_agents` snapshot
# taken at last setup/--sync. Configured personas are a subset of known
# agents — a known-but-unconfigured agent is a deliberate user choice
# (skip) and is NOT drift. Only agents newly installed since the last
# sync (or removed since) count as drift.
declare -a installed=() known=() new_agents=() removed_agents=()
while IFS= read -r a; do [[ -n "$a" ]] && installed+=("$a"); done < <(discover_ruflo_agents 2>/dev/null || true)
while IFS= read -r a; do [[ -n "$a" ]] && known+=("$a"); done < <(jq -r '.known_agents[]?' "$PERSONAS_MAP" 2>/dev/null || true)

for a in "${installed[@]:-}"; do
  printf '%s\n' "${known[@]:-}" | grep -qx "$a" || new_agents+=("$a")
done
for a in "${known[@]:-}"; do
  printf '%s\n' "${installed[@]:-}" | grep -qx "$a" || removed_agents+=("$a")
done

if (( ${#new_agents[@]} > 0 || ${#removed_agents[@]} > 0 )); then
  printf '\n[ruflo-personas] %d new agent(s), %d removed since last sync.\n' \
    "${#new_agents[@]}" "${#removed_agents[@]}" >&2
  printf '[ruflo-personas] Run: bash ~/.cappy/repo/modules/ruflo-personas/setup-ruflo-personas.sh --sync\n' >&2
fi

exit 0
