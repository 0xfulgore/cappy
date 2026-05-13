#!/usr/bin/env bash
# Cappy — ruflo-personas shared helpers
# Sourced by setup-ruflo-personas.sh, alias-generator.sh, hooks/driftcheck.sh.
# All functions assume jq is available (verified by the caller).

# ── Paths ────────────────────────────────────────────────────
PERSONAS_DIR="${HOME}/.cappy"
PERSONAS_MAP="${PERSONAS_DIR}/ruflo-personas.json"
PERSONAS_MAP_VERSION=1
AGENTS_DIR="${HOME}/.claude/agents"
PLUGINS_DIR="${HOME}/.claude/plugins"
CAPPY_MANAGED_MARKER="<!-- cappy:ruflo-personas:managed -->"

# Source pool relative to this helpers file. Resolve at source-time so
# the variable is stable regardless of where callers invoke us from.
# Using BASH_SOURCE inside a subshelled function is unreliable across
# bash versions, so resolve inline here.
_PERSONAS_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERSONAS_POOL_FILE="${_PERSONAS_HELPERS_DIR}/../personas-pool.json"

# ── Logging fallbacks (only if not already provided) ─────────
if ! declare -f log_info >/dev/null 2>&1; then
  log_info()    { printf "[info]  %s\n" "$*"; }
  log_success() { printf "[  ok]  %s\n" "$*"; }
  log_warn()    { printf "[warn]  %s\n" "$*"; }
  log_error()   { printf "[ err]  %s\n" "$*" >&2; }
fi

# ── Agent discovery ──────────────────────────────────────────
# Enumerate every installed ruflo agent as fully-qualified IDs:
#   <plugin-without-ruflo->:<agent-stem>
# Example outputs: "core:coder", "swarm:architect", "autopilot:autopilot-coordinator"
# (We strip the "ruflo-" plugin prefix because Claude Code's subagent_type
# uses the form "ruflo-core:coder" — we'll reattach the prefix at dispatch
# time; the persona map keys use the full "ruflo-core:coder" form.)
discover_ruflo_agents() {
  [[ -d "$PLUGINS_DIR" ]] || return 0
  # Find every <plugin>/agents/<name>.md under installed plugin trees.
  # Exclude marketplace source dumps (they live under .claude/plugins/marketplaces/<...>/)
  # by requiring the path to match the installed-plugin layout.
  find "$PLUGINS_DIR" -type d -name "ruflo-*" 2>/dev/null \
    | while read -r plugin_dir; do
        local plugin_name
        plugin_name=$(basename "$plugin_dir")
        local agents_dir="${plugin_dir}/agents"
        [[ -d "$agents_dir" ]] || continue
        find "$agents_dir" -maxdepth 1 -type f -name "*.md" 2>/dev/null \
          | while read -r agent_file; do
              local agent_stem
              agent_stem=$(basename "$agent_file" .md)
              printf '%s:%s\n' "$plugin_name" "$agent_stem"
            done
      done | sort -u
}

# Locate the on-disk .md file for a given agent ID (e.g. "ruflo-core:coder").
# Echoes the absolute path on success, returns non-zero if not found.
agent_id_to_source_file() {
  local agent_id="$1"
  local plugin_name="${agent_id%%:*}"
  local agent_stem="${agent_id##*:}"
  [[ "$plugin_name" != "$agent_id" ]] || return 1

  # Search for installed plugin directory matching plugin_name.
  local hit
  hit=$(find "$PLUGINS_DIR" -type d -name "$plugin_name" 2>/dev/null \
          | while read -r d; do
              local f="${d}/agents/${agent_stem}.md"
              [[ -f "$f" ]] && printf '%s\n' "$f"
            done | head -1)
  if [[ -z "$hit" ]]; then
    return 1
  fi
  printf '%s\n' "$hit"
}

# Human-readable description for a known ruflo agent. Pulls from the
# first non-empty `description:` line in the agent's frontmatter, or
# falls back to "(no description)".
agent_id_description() {
  local agent_id="$1"
  local src
  src=$(agent_id_to_source_file "$agent_id") || { printf '(agent not installed)'; return 0; }
  awk '
    /^---$/ { fm = !fm; next }
    fm && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$src" | head -c 120
}

# ── Pool filtering ───────────────────────────────────────────
# Filter the personas pool by pronouns and MBTI. Each filter accepts
# "any" or empty to skip that dimension. Echoes a JSON array.
pool_filter() {
  local pronouns="${1:-any}"
  local mbti="${2:-any}"
  local include_tech="${3:-true}"  # "true" | "false"

  jq --arg pr "$pronouns" --arg mb "$mbti" --arg inct "$include_tech" '
    map(
      select(($pr == "any" or $pr == "" or .pronouns == $pr)
             and ($mb == "any" or $mb == "" or .mbti == $mb)
             and ($inct == "true" or .source != "tech"))
    )
  ' "$PERSONAS_POOL_FILE"
}

# Fallback ladder: try strict filter, then relax MBTI to same dichotomy
# family (Analyst/Diplomat/Sentinel/Explorer), then drop MBTI, then drop
# pronouns. Echoes JSON array, never empty unless include_tech excludes all.
pool_filter_with_fallback() {
  local pronouns="${1:-any}"
  local mbti="${2:-any}"
  local include_tech="${3:-true}"

  local r
  r=$(pool_filter "$pronouns" "$mbti" "$include_tech")
  if [[ "$(jq 'length' <<<"$r")" -gt 0 ]]; then
    printf '%s' "$r"; return
  fi

  # Relax MBTI to family.
  local family=""
  case "$mbti" in
    INTJ|INTP|ENTJ|ENTP) family="analyst" ;;
    INFJ|INFP|ENFJ|ENFP) family="diplomat" ;;
    ISTJ|ISFJ|ESTJ|ESFJ) family="sentinel" ;;
    ISTP|ISFP|ESTP|ESFP) family="explorer" ;;
  esac
  if [[ -n "$family" ]]; then
    local fam_pattern=""
    case "$family" in
      analyst)  fam_pattern="^(INTJ|INTP|ENTJ|ENTP)$" ;;
      diplomat) fam_pattern="^(INFJ|INFP|ENFJ|ENFP)$" ;;
      sentinel) fam_pattern="^(ISTJ|ISFJ|ESTJ|ESFJ)$" ;;
      explorer) fam_pattern="^(ISTP|ISFP|ESTP|ESFP)$" ;;
    esac
    r=$(jq --arg pr "$pronouns" --arg pat "$fam_pattern" --arg inct "$include_tech" '
      map(
        select(($pr == "any" or $pr == "" or .pronouns == $pr)
               and (.mbti | test($pat))
               and ($inct == "true" or .source != "tech"))
      )
    ' "$PERSONAS_POOL_FILE")
    if [[ "$(jq 'length' <<<"$r")" -gt 0 ]]; then
      printf '%s' "$r"; return
    fi
  fi

  # Drop MBTI entirely.
  r=$(pool_filter "$pronouns" "any" "$include_tech")
  if [[ "$(jq 'length' <<<"$r")" -gt 0 ]]; then
    printf '%s' "$r"; return
  fi

  # Drop pronouns too — last resort.
  pool_filter "any" "any" "$include_tech"
}

# Pick a uniformly random record from a JSON array. Echoes the record
# as compact JSON.
pool_random_pick() {
  local filtered="$1"
  local len
  len=$(jq 'length' <<<"$filtered")
  if (( len == 0 )); then
    return 1
  fi
  # Use $RANDOM (0-32767) → modulo len.
  local idx=$(( RANDOM % len ))
  jq --argjson i "$idx" '.[$i]' <<<"$filtered"
}

# ── Persona map I/O ──────────────────────────────────────────
ensure_personas_dir() {
  mkdir -p "$PERSONAS_DIR"
}

read_persona_map() {
  if [[ -f "$PERSONAS_MAP" ]]; then
    cat "$PERSONAS_MAP"
  else
    jq -n --argjson v "$PERSONAS_MAP_VERSION" \
      '{_version: $v, ruflo_version_stamp: "", include_tech_founders: true, known_agents: [], personas: {}}'
  fi
}

# Update the known_agents list to reflect currently-installed ruflo agents.
# Called at setup end and --sync end. The map's known_agents field is what
# driftcheck compares against — distinct from `personas` (which only holds
# configured personas; skipped agents have no persona entry but ARE known).
update_known_agents() {
  local current new agents_json
  current=$(read_persona_map)
  agents_json=$(discover_ruflo_agents | jq -R . | jq -s .)
  new=$(jq --argjson a "$agents_json" '.known_agents = $a' <<<"$current")
  write_persona_map "$new"
}

# Write a fresh persona map. Caller passes the full JSON.
write_persona_map() {
  ensure_personas_dir
  local content="$1"
  local tmp
  tmp=$(mktemp)
  printf '%s' "$content" | jq '.' > "$tmp"
  mv "$tmp" "$PERSONAS_MAP"
}

# Set a single persona entry. Idempotent: overwrites if key exists.
# Args: agent_id, name, pronouns, mbti, voice, source, alias_slug
set_persona_entry() {
  local agent_id="$1" name="$2" pronouns="$3" mbti="$4" voice="$5" source="$6" alias_slug="$7"
  local current new
  current=$(read_persona_map)
  new=$(jq --arg k "$agent_id" \
           --arg name "$name" \
           --arg pr "$pronouns" \
           --arg mb "$mbti" \
           --arg voice "$voice" \
           --arg src "$source" \
           --arg slug "$alias_slug" \
           --arg ver "$(get_ruflo_version)" \
        '.personas[$k] = {name: $name, pronouns: $pr, mbti: $mb, voice: $voice, source: $src, alias_slug: $slug, generated_from: ($k + "@" + $ver)}' \
        <<<"$current")
  write_persona_map "$new"
}

# Remove a persona entry.
remove_persona_entry() {
  local agent_id="$1"
  local current new
  current=$(read_persona_map)
  new=$(jq --arg k "$agent_id" 'del(.personas[$k])' <<<"$current")
  write_persona_map "$new"
}

# Set top-level fields.
set_persona_map_field() {
  local key="$1" value="$2"
  local current new
  current=$(read_persona_map)
  new=$(jq --arg k "$key" --arg v "$value" '.[$k] = $v' <<<"$current")
  write_persona_map "$new"
}

# ── Slug + name helpers ──────────────────────────────────────
# Convert a persona name to an alias slug: lowercase, hyphenate spaces,
# strip non-alphanumeric (preserve hyphens).
slugify() {
  local name="$1"
  printf '%s' "$name" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//'
}

# Quote a string for safe embedding in markdown alias-file body.
# Strips frontmatter terminators (---) and backticks that would break parsing.
sanitize_voice() {
  local raw="$1"
  printf '%s' "$raw" \
    | tr '\n' ' ' \
    | sed 's/---//g; s/`//g' \
    | head -c 200
}

# ── Ruflo version ────────────────────────────────────────────
# Best-effort: read RUFLO_MCP_VERSION from cappy's setup-ruflo.sh.
# Falls back to "unknown" so callers can still operate.
get_ruflo_version() {
  local setup_script="${HOME}/.cappy/repo/modules/ruflo/setup-ruflo.sh"
  if [[ -f "$setup_script" ]]; then
    awk -F'"' '/^RUFLO_MCP_VERSION=/ {print $2; exit}' "$setup_script"
  else
    printf 'unknown'
  fi
}

# ── List managed aliases ─────────────────────────────────────
# Echo paths of every alias file currently managed by ruflo-personas
# (identified by the managed marker in the file body).
list_managed_aliases() {
  [[ -d "$AGENTS_DIR" ]] || return 0
  grep -l "$CAPPY_MANAGED_MARKER" "$AGENTS_DIR"/*.md 2>/dev/null || true
}

# Check if a given file is a cappy-managed alias.
is_managed_alias() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  grep -q "$CAPPY_MANAGED_MARKER" "$file"
}
