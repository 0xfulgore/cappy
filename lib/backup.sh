#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cappy — Backup and restore
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BACKUP_DIR=""

create_backup() {
  local timestamp
  timestamp=$(date +"%Y%m%d-%H%M%S")
  BACKUP_DIR="${CLAUDE_HOME}/backups/cappy-${timestamp}"
  ensure_dir "$BACKUP_DIR"

  log_step "Creating backup at $BACKUP_DIR"

  local manifest=()

  # Back up settings.json
  if [[ -f "$CLAUDE_HOME/settings.json" ]]; then
    cp "$CLAUDE_HOME/settings.json" "$BACKUP_DIR/settings.json"
    local hash
    hash=$(sha256_file "$CLAUDE_HOME/settings.json")
    manifest+=("{\"file\": \"settings.json\", \"source\": \"$CLAUDE_HOME/settings.json\", \"sha256\": \"$hash\"}")
    log_success "Backed up settings.json"
  fi

  # Back up global CLAUDE.md (if in a project dir)
  if [[ -f "$(pwd)/CLAUDE.md" ]]; then
    cp "$(pwd)/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
    local hash
    hash=$(sha256_file "$(pwd)/CLAUDE.md")
    manifest+=("{\"file\": \"CLAUDE.md\", \"source\": \"$(pwd)/CLAUDE.md\", \"sha256\": \"$hash\"}")
    log_success "Backed up CLAUDE.md"
  fi

  # Back up hooks
  if [[ -d "$CLAUDE_HOME/hooks" ]]; then
    cp -r "$CLAUDE_HOME/hooks" "$BACKUP_DIR/hooks"
    log_success "Backed up hooks/"
  fi

  # Write manifest
  local manifest_json="["
  for i in "${!manifest[@]}"; do
    (( i > 0 )) && manifest_json+=","
    manifest_json+="${manifest[$i]}"
  done
  manifest_json+="]"

  echo "$manifest_json" | jq '.' > "$BACKUP_DIR/backup-manifest.json"
  log_success "Backup manifest written"

  export BACKUP_DIR
}

restore_backup() {
  local backup_path="$1"

  if [[ ! -d "$backup_path" ]]; then
    log_error "Backup directory not found: $backup_path"
    return 1
  fi

  if [[ ! -f "$backup_path/backup-manifest.json" ]]; then
    log_error "No backup manifest found in $backup_path"
    return 1
  fi

  log_step "Restoring from $backup_path"

  local count
  count=$(jq 'length' "$backup_path/backup-manifest.json")

  for (( i=0; i<count; i++ )); do
    local file source
    file=$(jq -r ".[$i].file" "$backup_path/backup-manifest.json")
    source=$(jq -r ".[$i].source" "$backup_path/backup-manifest.json")

    if [[ -f "$backup_path/$file" ]]; then
      cp "$backup_path/$file" "$source"
      log_success "Restored $file → $source"
    fi
  done

  # Restore hooks directory
  if [[ -d "$backup_path/hooks" ]]; then
    cp -r "$backup_path/hooks/"* "$CLAUDE_HOME/hooks/" 2>/dev/null || true
    log_success "Restored hooks/"
  fi

  log_success "Backup restored from $backup_path"
}
