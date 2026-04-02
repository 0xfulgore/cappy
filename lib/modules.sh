#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Module management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CAPPY_MODULES_DIR=""  # Set by installer to point at the modules/ directory

# Load module metadata from module.json
load_module() {
  local module_name="$1"
  local module_dir="${CAPPY_MODULES_DIR}/${module_name}"
  local module_json="${module_dir}/module.json"

  if [[ ! -f "$module_json" ]]; then
    log_error "Module '$module_name' not found at $module_dir"
    return 1
  fi

  jq '.' "$module_json"
}

# Given selected modules, add any missing required dependencies
# Operates directly on the global MODULES array
resolve_dependencies() {
  local changed=1

  while (( changed )); do
    changed=0
    for mod in "${MODULES[@]}"; do
      local module_dir="${CAPPY_MODULES_DIR}/${mod}"
      local module_json="${module_dir}/module.json"
      [[ -f "$module_json" ]] || continue

      local deps
      deps=$(jq -r '.requires[]? // empty' "$module_json" 2>/dev/null)
      while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        local found=0
        for existing in "${MODULES[@]}"; do
          [[ "$existing" == "$dep" ]] && found=1 && break
        done
        if (( !found )); then
          MODULES+=("$dep")
          log_info "Added dependency: $dep (required by $mod)"
          changed=1
        fi
      done <<< "$deps"
    done
  done
}

# Warn about conflicting modules
check_conflicts() {
  local has_conflict=0

  for mod in "${MODULES[@]}"; do
    local module_json="${CAPPY_MODULES_DIR}/${mod}/module.json"
    [[ -f "$module_json" ]] || continue

    local conflicts
    conflicts=$(jq -r '.conflicts[]? // empty' "$module_json" 2>/dev/null)
    while IFS= read -r conflict; do
      [[ -z "$conflict" ]] && continue
      for other in "${MODULES[@]}"; do
        if [[ "$other" == "$conflict" ]]; then
          log_warn "Module '$mod' conflicts with '$conflict'"
          has_conflict=1
        fi
      done
    done <<< "$conflicts"
  done

  return $has_conflict
}

# Install a single module
install_module() {
  local module_name="$1"
  local module_dir="${CAPPY_MODULES_DIR}/${module_name}"
  local module_json="${module_dir}/module.json"

  if [[ ! -f "$module_json" ]]; then
    log_error "Module '$module_name' not found"
    return 1
  fi

  local install_type
  install_type=$(jq -r '.install_type // "files"' "$module_json")

  log_step "Installing module: $module_name"

  case "$install_type" in
    claude_md)
      install_module_claude_md "$module_name" "$module_dir"
      ;;
    claude_md_addon)
      install_module_claude_md_addon "$module_name" "$module_dir"
      ;;
    files)
      install_module_files "$module_name" "$module_dir" "$module_json"
      ;;
    settings)
      install_module_settings "$module_name" "$module_dir" "$module_json"
      ;;
    *)
      # Default: process files array and settings_merge
      install_module_files "$module_name" "$module_dir" "$module_json"
      ;;
  esac

  # Apply settings_merge if present
  local settings_merge
  settings_merge=$(jq -r '.settings_merge // empty' "$module_json" 2>/dev/null)
  if [[ -n "$settings_merge" ]] && [[ "$settings_merge" != "null" ]] && [[ "$settings_merge" != "{}" ]]; then
    merge_settings_fragment "$settings_merge"
    log_success "Merged settings for $module_name"
  fi

  # Run post_install if present
  local post_install
  post_install=$(jq -r '.post_install // empty' "$module_json" 2>/dev/null)
  if [[ -n "$post_install" ]] && [[ "$post_install" != "null" ]]; then
    log_info "Running post-install for $module_name..."
    bash -c "cd '$module_dir' && $post_install"
  fi
}

# Install a CLAUDE.md module (core)
install_module_claude_md() {
  local module_name="$1"
  local module_dir="$2"
  local template="${module_dir}/CLAUDE.md.template"
  local sections_dir="${module_dir}/sections"

  if [[ ! -f "$template" ]]; then
    log_error "No CLAUDE.md.template found for $module_name"
    return 1
  fi

  # Determine which sections to install (could be filtered by user choice)
  local selected_sections=()
  if [[ -n "${CAPPY_CORE_SECTIONS:-}" ]]; then
    IFS=',' read -ra selected_sections <<< "$CAPPY_CORE_SECTIONS"
  fi

  # Assemble CLAUDE.md from template + sections
  local assembled
  assembled=$(assemble_claude_md "$template" "$sections_dir" "${selected_sections[@]}")

  # Determine target: global CLAUDE.md location
  # Install to the parent development directory if available, otherwise current dir
  local target
  if [[ -n "${CAPPY_CLAUDE_MD_TARGET:-}" ]]; then
    target="$CAPPY_CLAUDE_MD_TARGET"
  else
    target="$(pwd)/CLAUDE.md"
  fi

  merge_claude_md "$assembled" "$target"
  log_success "CLAUDE.md installed at $target"
}

# Install a CLAUDE.md addon module (performance, accessibility, devops, api-design)
# These have a single section.md that gets appended to the managed block in CLAUDE.md
install_module_claude_md_addon() {
  local module_name="$1"
  local module_dir="$2"
  local section_file="${module_dir}/section.md"

  if [[ ! -f "$section_file" ]]; then
    log_error "No section.md found for addon module $module_name"
    return 1
  fi

  local target
  if [[ -n "${CAPPY_CLAUDE_MD_TARGET:-}" ]]; then
    target="$CAPPY_CLAUDE_MD_TARGET"
  else
    target="$(pwd)/CLAUDE.md"
  fi

  if [[ ! -f "$target" ]]; then
    log_warn "CLAUDE.md not found at $target — install core module first"
    return 1
  fi

  local section_content
  section_content=$(cat "$section_file")
  local section_marker
  section_marker=$(grep -o 'cappy:section:[a-z-]*' "$section_file" | head -1 || true)

  # Check if this section is already in the file
  if [[ -n "$section_marker" ]] && grep -q "$section_marker" "$target"; then
    # Replace existing section
    local marker_name="${section_marker#cappy:section:}"
    local before after
    before=$(sed -n "1,/<!-- cappy:section:${marker_name} -->/p" "$target" | sed '$ d')
    after=$(sed -n "/<!-- cappy:end:${marker_name} -->/,\$p" "$target" | sed '1 d')
    {
      echo "$before"
      echo "$section_content"
      echo "$after"
    } > "$target"
    log_success "Updated $module_name section in CLAUDE.md"
  else
    # Append before the managed-end marker (or at the end if no marker)
    if grep -q '<!-- cappy:managed-end -->' "$target"; then
      local before after
      before=$(sed -n '1,/<!-- cappy:managed-end -->/p' "$target" | sed '$ d')
      after=$(sed -n '/<!-- cappy:managed-end -->/,$p' "$target")
      {
        echo "$before"
        echo ""
        echo "$section_content"
        echo "$after"
      } > "$target"
    else
      # No managed block — just append
      {
        cat "$target"
        echo ""
        echo "$section_content"
      } > "${target}.tmp" && mv "${target}.tmp" "$target"
    fi
    log_success "Added $module_name section to CLAUDE.md"
  fi
}

# Install file-based module
install_module_files() {
  local module_name="$1"
  local module_dir="$2"
  local module_json="$3"

  local count
  count=$(jq '.files | length' "$module_json" 2>/dev/null)
  [[ "$count" == "null" ]] && count=0

  for (( i=0; i<count; i++ )); do
    local source target mode
    source=$(jq -r ".files[$i].source" "$module_json")
    target=$(jq -r ".files[$i].target" "$module_json")
    mode=$(jq -r ".files[$i].mode // \"0644\"" "$module_json")

    # Expand ~ in target
    target="${target/#\~/$HOME}"

    install_file "${module_dir}/${source}" "$target" "$mode"
  done
}

# Install settings preset module
install_module_settings() {
  local module_name="$1"
  local module_dir="$2"
  local module_json="$3"

  local preset="${CAPPY_SETTINGS_PRESET:-power-user}"
  local preset_file="${module_dir}/presets/${preset}.json"

  if [[ ! -f "$preset_file" ]]; then
    log_error "Settings preset '$preset' not found"
    return 1
  fi

  local settings_file="$CLAUDE_HOME/settings.json"
  if [[ -f "$settings_file" ]]; then
    merge_json "$settings_file" "$preset_file" "$settings_file" "theirs"
    log_success "Merged $preset preset into settings.json"
  else
    cp "$preset_file" "$settings_file"
    log_success "Installed $preset preset as settings.json"
  fi
}

# Record installed module to ~/.cappy/installed.json
record_installation() {
  local modules=("$@")
  ensure_dir "$CAPPY_HOME"

  local modules_json="{"
  for i in "${!modules[@]}"; do
    (( i > 0 )) && modules_json+=","
    local mod="${modules[$i]}"
    local ver
    ver=$(jq -r '.version // "1.0.0"' "${CAPPY_MODULES_DIR}/${mod}/module.json" 2>/dev/null)
    modules_json+="\"$mod\": {\"version\": \"$ver\"}"
  done
  modules_json+="}"

  local cappy_ver
  cappy_ver=$(jq -r '.version' "${CAPPY_MODULES_DIR}/../forge.json" 2>/dev/null)

  jq -n \
    --arg ver "$cappy_ver" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg backup "${BACKUP_DIR:-none}" \
    --argjson mods "$modules_json" \
    '{
      cappy_version: $ver,
      installed_at: $ts,
      backup_path: $backup,
      modules: $mods
    }' > "$CAPPY_INSTALLED_JSON"
}
