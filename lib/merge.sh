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

  # Validate inputs before merging — jq failure here would otherwise
  # truncate $output to empty via the redirect below.
  if ! jq empty "$existing" 2>/dev/null; then
    log_error "Cannot merge: $existing is not valid JSON. Leaving $output untouched."
    return 1
  fi
  if ! jq empty "$incoming" 2>/dev/null; then
    log_error "Cannot merge: $incoming is not valid JSON. Leaving $output untouched."
    return 1
  fi

  # Deep merge with jq.
  # Strategy semantics:
  #   "ours"   — on scalar conflict, keep destination (user customisation wins). Safe default for `cappy update`.
  #   "theirs" — on scalar conflict, overwrite with incoming value. Used by install_module_settings on first install.
  #   "prompt" — same as "ours" but logs a warning naming the conflicting key so the user is aware.
  # Arrays are always unioned (deduped) regardless of strategy.
  local merged jq_status
  merged=$(jq -s --arg strategy "$strategy" '
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
              if $strategy == "theirs" then {($k): $b[$k]}
              elif $strategy == "prompt" then ({($k): $a[$k]} | (. , ("WARNING: merge conflict on key \"" + $k + "\" — keeping existing value (strategy=prompt)" | debug | empty)))
              else {($k): $a[$k]}
              end
            end
          elif ($b | has($k)) then {($k): $b[$k]}
          else {($k): $a[$k]}
          end
        ) | add // {}
      else
        if $strategy == "theirs" then .[1] else .[0] end
      end;
    [.[0], .[1]] | deep_merge
  ' "$existing" "$incoming")
  jq_status=$?

  if (( jq_status != 0 )) || [[ -z "$merged" ]]; then
    log_error "Merge failed (jq exit=$jq_status). Leaving $output untouched."
    return 1
  fi

  printf '%s\n' "$merged" > "$output"
}

# Merge a settings fragment into the existing settings.json
# Strategy defaults to "ours" so re-installs / updates never overwrite user customisations.
merge_settings_fragment() {
  local fragment="$1"  # JSON string, not a file
  local strategy="${2:-ours}"
  local settings_file="$CLAUDE_HOME/settings.json"

  # Validate the incoming fragment before touching anything.
  if ! printf '%s' "$fragment" | jq empty 2>/dev/null; then
    log_error "Cannot merge fragment: not valid JSON. Leaving $settings_file untouched."
    return 1
  fi

  if [[ ! -f "$settings_file" ]]; then
    printf '%s' "$fragment" | jq '.' > "$settings_file"
    return
  fi

  # Validate existing settings — without this, jq fails and the redirect
  # below would truncate the file to empty.
  if ! jq empty "$settings_file" 2>/dev/null; then
    log_error "Cannot merge: $settings_file is not valid JSON. Leaving it untouched."
    return 1
  fi

  local merged jq_status
  merged=$(printf '%s' "$fragment" | jq -s --arg strategy "$strategy" '
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
              if $strategy == "theirs" then {($k): $b[$k]}
              elif $strategy == "prompt" then ({($k): $a[$k]} | (. , ("WARNING: merge conflict on key \"" + $k + "\" — keeping existing value (strategy=prompt)" | debug | empty)))
              else {($k): $a[$k]}
              end
            end
          elif ($b | has($k)) then {($k): $b[$k]}
          else {($k): $a[$k]}
          end
        ) | add // {}
      else
        if $strategy == "theirs" then .[1] else .[0] end
      end;
    [.[0], .[1]] | deep_merge
  ' "$settings_file" -)
  jq_status=$?

  if (( jq_status != 0 )) || [[ -z "$merged" ]]; then
    log_error "Settings fragment merge failed (jq exit=$jq_status). Leaving $settings_file untouched."
    return 1
  fi

  printf '%s\n' "$merged" > "$settings_file"
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
