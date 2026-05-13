#!/usr/bin/env bash
# Cappy — ruflo-personas alias generator
# Renders self-contained agent alias files at ~/.claude/agents/<slug>.md
# from ~/.cappy/ruflo-personas.json + installed ruflo agent files.
# Self-contained means: the alias keeps working even if ruflo is uninstalled.
# Idempotent. Refuses to overwrite agent files not managed by cappy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/personas-helpers.sh
source "${SCRIPT_DIR}/lib/personas-helpers.sh"

if ! command -v jq >/dev/null 2>&1; then
  log_error "jq is required"
  exit 1
fi

if [[ ! -f "$PERSONAS_MAP" ]]; then
  log_info "No persona map at $PERSONAS_MAP — nothing to render"
  exit 0
fi

mkdir -p "$AGENTS_DIR"

# Iterate every configured persona and render its alias file.
# Each persona maps an installed ruflo agent (e.g. "ruflo-core:coder")
# to a custom-named alias (e.g. "spock") with a self-contained system
# prompt: a persona overlay + the source agent's full body.
rendered=0
skipped=0
removed_orphans=0

# Track current managed aliases so we can clean up ones that no longer
# correspond to a persona (e.g. user renamed via reset).
declare -a known_aliases=()

while IFS=$'\t' read -r agent_id slug name pronouns mbti voice source_label; do
  [[ -n "$agent_id" ]] || continue
  [[ -n "$slug" ]] || { log_warn "persona for $agent_id has no alias_slug — skipping"; skipped=$((skipped+1)); continue; }

  src_file=$(agent_id_to_source_file "$agent_id" || true)
  if [[ -z "$src_file" || ! -f "$src_file" ]]; then
    log_warn "ruflo agent $agent_id not installed — skipping alias for $name"
    skipped=$((skipped+1))
    continue
  fi

  alias_file="${AGENTS_DIR}/${slug}.md"
  known_aliases+=("$alias_file")

  # Refuse to overwrite a non-managed file at that slug.
  if [[ -f "$alias_file" ]] && ! is_managed_alias "$alias_file"; then
    log_warn "agents/${slug}.md exists and is not cappy-managed — refusing to overwrite"
    skipped=$((skipped+1))
    continue
  fi

  # Parse source agent's frontmatter (between the first two --- lines)
  # and body.
  src_frontmatter=$(awk '
    /^---$/ { count++; if (count == 1) {in_fm=1; next} else if (count == 2) {exit} }
    in_fm { print }
  ' "$src_file")
  src_body=$(awk '
    BEGIN { count = 0 }
    /^---$/ { count++; next }
    count >= 2 { print }
  ' "$src_file")

  # Extract tools array (if any) from source frontmatter so the alias
  # inherits the same tool permissions.
  src_tools=$(printf '%s\n' "$src_frontmatter" | awk '
    /^tools:/ {
      sub(/^tools:[[:space:]]*/, "")
      print
      # Continuation lines for multi-line YAML arrays start with whitespace.
      while ((getline line) > 0) {
        if (line ~ /^[a-zA-Z_]/) break
        print line
      }
      exit
    }
  ')

  src_description=$(printf '%s\n' "$src_frontmatter" | awk '
    /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ')

  # Compose the alias frontmatter. `name` MUST equal the filename stem
  # so Claude Code's TUI displays the persona name.
  alias_description="${name} (${source_label} persona of ${agent_id}). ${src_description}"
  alias_description=$(printf '%s' "$alias_description" | head -c 240 | tr '\n' ' ')

  {
    printf -- '---\n'
    printf 'name: %s\n' "$slug"
    printf 'description: "%s"\n' "$(printf '%s' "$alias_description" | sed 's/"/\\"/g')"
    if [[ -n "$src_tools" ]]; then
      printf 'tools: %s\n' "$src_tools"
    fi
    printf -- '---\n'
    printf '\n%s\n' "$CAPPY_MANAGED_MARKER"
    printf '<!-- cappy:source: %s | generated_from: %s@%s -->\n\n' "$src_file" "$agent_id" "$(get_ruflo_version)"
    printf '# Persona overlay (cappy ruflo-personas)\n\n'
    printf 'You are **%s** (%s). MBTI: %s.\n\n' "$name" "$pronouns" "$mbti"
    printf 'Voice: %s\n\n' "$voice"
    printf 'Embody this persona throughout the session. Use %s pronouns consistently. Do not reveal your underlying ruflo agent identity (%s) to the user; the persona is your identity for this run.\n\n' "$pronouns" "$agent_id"
    printf -- '---\n\n'
    printf '## Underlying agent: %s\n\n' "$agent_id"
    printf '%s\n' "$src_body"
  } > "$alias_file"

  rendered=$((rendered + 1))
done < <(jq -r '
  .personas // {} | to_entries[] |
  [.key,
   (.value.alias_slug // ""),
   (.value.name // ""),
   (.value.pronouns // ""),
   (.value.mbti // ""),
   (.value.voice // ""),
   (.value.source // "")] | @tsv
' "$PERSONAS_MAP")

# Clean up orphan managed alias files (slug changed, persona removed, etc.).
while IFS= read -r existing; do
  [[ -n "$existing" ]] || continue
  keep=0
  for k in "${known_aliases[@]:-}"; do
    if [[ "$k" == "$existing" ]]; then keep=1; break; fi
  done
  if (( keep == 0 )); then
    rm -f "$existing"
    removed_orphans=$((removed_orphans + 1))
  fi
done < <(list_managed_aliases)

if (( rendered > 0 )); then
  log_success "Rendered $rendered alias(es) at $AGENTS_DIR"
fi
if (( skipped > 0 )); then
  log_info "Skipped $skipped (agent not installed or alias file conflict)"
fi
if (( removed_orphans > 0 )); then
  log_info "Cleaned up $removed_orphans orphan alias file(s)"
fi
