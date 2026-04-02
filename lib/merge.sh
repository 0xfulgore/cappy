#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Config merging (JSON + Markdown)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Deep-merge two JSON files. Arrays are unioned. Objects are recursively merged.
# Strategy: "ours" (keep existing), "theirs" (use new), "prompt" (ask user)
merge_json() {
  local existing="$1"
  local incoming="$2"
  local output="$3"
  local strategy="${4:-prompt}"

  if [[ ! -f "$existing" ]]; then
    cp "$incoming" "$output"
    return
  fi

  # Deep merge with jq: incoming values override existing, arrays are unioned
  local merged
  merged=$(jq -s '
    def union_arrays: [.[0], .[1]] | add | unique;
    def deep_merge:
      if (.[0] | type) == "object" and (.[1] | type) == "object" then
        .[0] as $a | .[1] as $b |
        ($a | keys) + ($b | keys) | unique | map(
          . as $k |
          if ($a | has($k)) and ($b | has($k)) then
            if ($a[$k] | type) == "object" and ($b[$k] | type) == "object" then
              {($k): ([$a[$k], $b[$k]] | deep_merge)}
            elif ($a[$k] | type) == "array" and ($b[$k] | type) == "array" then
              {($k): ([$a[$k], $b[$k]] | union_arrays)}
            else
              {($k): $b[$k]}
            end
          elif ($b | has($k)) then {($k): $b[$k]}
          else {($k): $a[$k]}
          end
        ) | add // {}
      else .[1]
      end;
    [.[0], .[1]] | deep_merge
  ' "$existing" "$incoming")

  echo "$merged" > "$output"
}

# Merge a settings fragment into the existing settings.json
merge_settings_fragment() {
  local fragment="$1"  # JSON string, not a file
  local settings_file="$CLAUDE_HOME/settings.json"

  if [[ ! -f "$settings_file" ]]; then
    echo "$fragment" | jq '.' > "$settings_file"
    return
  fi

  local merged
  merged=$(echo "$fragment" | jq -s '
    def union_arrays: [.[0], .[1]] | add | unique;
    def deep_merge:
      if (.[0] | type) == "object" and (.[1] | type) == "object" then
        .[0] as $a | .[1] as $b |
        ($a | keys) + ($b | keys) | unique | map(
          . as $k |
          if ($a | has($k)) and ($b | has($k)) then
            if ($a[$k] | type) == "object" and ($b[$k] | type) == "object" then
              {($k): ([$a[$k], $b[$k]] | deep_merge)}
            elif ($a[$k] | type) == "array" and ($b[$k] | type) == "array" then
              {($k): ([$a[$k], $b[$k]] | union_arrays)}
            else
              {($k): $b[$k]}
            end
          elif ($b | has($k)) then {($k): $b[$k]}
          else {($k): $a[$k]}
          end
        ) | add // {}
      else .[1]
      end;
    [.[0], .[1]] | deep_merge
  ' "$settings_file" -)

  echo "$merged" > "$settings_file"
}

# ── CLAUDE.md Section Merging ────────────────────────────────

# Assemble CLAUDE.md from section fragments
assemble_claude_md() {
  local template="$1"  # The template file with include markers
  local sections_dir="$2"  # Directory containing section files
  shift 2
  local selected_sections=("$@")  # Array of section filenames to include

  local output=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^'<!-- cappy:include:'(.+)' -->'$ ]]; then
      local section_ref="${BASH_REMATCH[1]}"
      local section_file="${sections_dir}/${section_ref}.md"
      # Only include if selected (or if no filter specified)
      if [[ ${#selected_sections[@]} -eq 0 ]] || printf '%s\n' "${selected_sections[@]}" | grep -qx "$section_ref"; then
        if [[ -f "$section_file" ]]; then
          output+="$(cat "$section_file")"$'\n'
        fi
      fi
    else
      output+="$line"$'\n'
    fi
  done < "$template"

  echo "$output"
}

# Merge assembled CLAUDE.md into an existing file
merge_claude_md() {
  local new_content="$1"  # The assembled content
  local target="$2"  # Target file path

  if [[ ! -f "$target" ]]; then
    echo "$new_content" > "$target"
    return
  fi

  local existing
  existing=$(cat "$target")

  # Check for existing cappy managed block
  if grep -q '<!-- cappy:managed-start -->' "$target"; then
    # Replace the managed block
    local before after
    before=$(sed -n '1,/<!-- cappy:managed-start -->/p' "$target" | sed '$ d')
    after=$(sed -n '/<!-- cappy:managed-end -->/,$p' "$target" | sed '1 d')
    {
      echo "$before"
      echo "<!-- cappy:managed-start -->"
      echo "$new_content"
      echo "<!-- cappy:managed-end -->"
      echo "$after"
    } > "$target"
    log_success "Updated cappy-managed sections in CLAUDE.md"
  else
    # Append managed block
    {
      echo "$existing"
      echo ""
      echo "---"
      echo "<!-- cappy:managed-start -->"
      echo "$new_content"
      echo "<!-- cappy:managed-end -->"
    } > "$target"
    log_success "Appended cappy sections to existing CLAUDE.md"
  fi
}

# ── File Installation ────────────────────────────────────────

# Install a single file with collision detection
install_file() {
  local source="$1"
  local target="$2"
  local mode="${3:-0644}"

  ensure_dir "$(dirname "$target")"

  if [[ ! -f "$target" ]]; then
    cp "$source" "$target"
    chmod "$mode" "$target"
    log_success "Installed $(basename "$target")"
    return
  fi

  local src_hash tgt_hash
  src_hash=$(sha256_file "$source")
  tgt_hash=$(sha256_file "$target")

  if [[ "$src_hash" == "$tgt_hash" ]]; then
    log_info "$(basename "$target") already up to date"
    return
  fi

  if [[ "${CAPPY_NON_INTERACTIVE:-}" == "1" ]]; then
    cp "$source" "$target"
    chmod "$mode" "$target"
    log_warn "Overwrote $(basename "$target") (non-interactive mode)"
    return
  fi

  log_warn "$(basename "$target") differs from cappy version"
  local choice
  choice=$(prompt_select "What would you like to do?" "Skip (keep existing)" "Overwrite with cappy version" "Keep both (rename existing to .bak)")

  case "$choice" in
    0) log_info "Skipped $(basename "$target")" ;;
    1) cp "$source" "$target"; chmod "$mode" "$target"; log_success "Overwrote $(basename "$target")" ;;
    2) mv "$target" "${target}.bak"; cp "$source" "$target"; chmod "$mode" "$target"; log_success "Installed $(basename "$target") (old → .bak)" ;;
  esac
}
