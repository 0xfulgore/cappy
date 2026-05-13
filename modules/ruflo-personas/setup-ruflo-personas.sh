#!/usr/bin/env bash
# Cappy — Ruflo Personas Setup
# Per-agent custom-named persona overlays for every installed ruflo agent.
# Idempotent; non-interactive mode writes empty persona map and exits.
#
# Usage:
#   setup-ruflo-personas.sh           # initial / re-run setup
#   setup-ruflo-personas.sh --reset   # wipe everything and re-run
#   setup-ruflo-personas.sh --sync    # re-render aliases; prompt only on structural drift
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source cappy common helpers if available.
if [[ -f "${SCRIPT_DIR}/../../lib/common.sh" ]]; then
  # shellcheck source=../../lib/common.sh
  source "${SCRIPT_DIR}/../../lib/common.sh"
fi
# shellcheck source=lib/personas-helpers.sh
source "${SCRIPT_DIR}/lib/personas-helpers.sh"

ALIAS_GENERATOR="${SCRIPT_DIR}/alias-generator.sh"

# ── ANSI ─────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RST=$'\e[0m'; BOLD=$'\e[1m'; DIM=$'\e[2m'
  CYAN=$'\e[36m'; YELLOW=$'\e[33m'; GREEN=$'\e[32m'
else
  RST=""; BOLD=""; DIM=""; CYAN=""; YELLOW=""; GREEN=""
fi

# ── Args ─────────────────────────────────────────────────────
MODE="setup"
while (( $# )); do
  case "$1" in
    --reset) MODE="reset" ;;
    --sync)  MODE="sync"  ;;
    -h|--help)
      sed -n '/^# Usage:/,/^set -euo/p' "$0" | sed 's/^# //; s/^#//; /^set/d'
      exit 0
      ;;
    *) printf '[err] unknown arg: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

# ── Preflight ────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  log_error "jq is required for ruflo-personas — install it first"
  exit 1
fi

# ── Helpers ──────────────────────────────────────────────────
header() {
  printf '\n%s━━ %s%s\n' "$CYAN" "$*" "$RST"
}

# Returns 0 if running interactively, 1 otherwise.
is_interactive() { [[ -t 0 && -t 1 ]]; }

# Read a line with a prompt and a default. Echoes the trimmed answer.
# Prompt goes to stderr so $(prompt_line ...) captures only the answer.
prompt_line() {
  local label="$1" default="${2:-}"
  if [[ -n "$default" ]]; then
    printf '  %s [%s]: ' "$label" "$default" >&2
  else
    printf '  %s: ' "$label" >&2
  fi
  local ans
  read -r ans || ans=""
  ans="${ans## }"; ans="${ans%% }"
  printf '%s' "${ans:-$default}"
}

# Print the 16 MBTI types grouped, return the chosen 4-letter code.
# Catalogue goes to stderr (display only); the chosen code goes to stdout.
prompt_mbti() {
  cat >&2 <<'EOF'

    Analysts:   1) INTJ Architect   2) INTP Logician   3) ENTJ Commander  4) ENTP Debater
    Diplomats:  5) INFJ Advocate    6) INFP Mediator   7) ENFJ Protagonist 8) ENFP Campaigner
    Sentinels:  9) ISTJ Logistician 10) ISFJ Defender  11) ESTJ Executive 12) ESFJ Consul
    Explorers: 13) ISTP Virtuoso   14) ISFP Adventurer 15) ESTP Entrepreneur 16) ESFP Entertainer

EOF
  local mbti_list=("INTJ" "INTP" "ENTJ" "ENTP" "INFJ" "INFP" "ENFJ" "ENFP" \
                   "ISTJ" "ISFJ" "ESTJ" "ESFJ" "ISTP" "ISFP" "ESTP" "ESFP")
  while true; do
    local input
    input=$(prompt_line "MBTI [1-16, name, or 'any' to skip]" "any")
    case "$input" in
      any|skip|"") printf 'any'; return ;;
    esac
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= 16 )); then
      printf '%s' "${mbti_list[$((input-1))]}"
      return
    fi
    # Direct 4-letter name?
    local upper
    upper=$(printf '%s' "$input" | tr '[:lower:]' '[:upper:]')
    for m in "${mbti_list[@]}"; do
      if [[ "$m" == "$upper" ]]; then printf '%s' "$m"; return; fi
    done
    printf '  %sNot recognized — try a number 1-16 or the 4-letter code.%s\n' "$YELLOW" "$RST" >&2
  done
}

prompt_pronouns() {
  cat >&2 <<'EOF'

    1) he/him   2) she/her   3) they/them   4) it/its   5) custom   6) any

EOF
  local input
  input=$(prompt_line "Pronouns [1-6, default 6 any]" "6")
  case "$input" in
    1|he|he/him)     printf 'he/him' ;;
    2|she|she/her)   printf 'she/her' ;;
    3|they|they/them) printf 'they/them' ;;
    4|it|it/its)     printf 'it/its' ;;
    5|custom)
      local custom
      custom=$(prompt_line "Custom pronouns (≤30 chars)" "")
      printf '%s' "$(printf '%s' "$custom" | head -c 30)"
      ;;
    *) printf 'any' ;;
  esac
}

# Show the full pool grouped by source. Return the chosen 0-based index.
# Listing goes to stderr; only the chosen index goes to stdout.
prompt_browse_pool() {
  local total
  total=$(jq 'length' "$PERSONAS_POOL_FILE")
  {
    jq -r '
      to_entries[] |
      "  " + ((.key + 1) | tostring) + ") " + .value.name + " — " + .value.source + " (" + .value.pronouns + ", " + .value.mbti + ")"
    ' "$PERSONAS_POOL_FILE"
    printf '\n'
  } >&2
  while true; do
    local input
    input=$(prompt_line "Choose 1-$total or 'q' to cancel" "")
    case "$input" in
      q|Q|"") printf -- '-1'; return ;;
    esac
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= total )); then
      printf '%d' $((input - 1)); return
    fi
    printf '  %sInvalid — try again.%s\n' "$YELLOW" "$RST" >&2
  done
}

# ── Per-agent flow ───────────────────────────────────────────
# Args: agent_id, current_persona_json (or empty)
configure_agent() {
  local agent_id="$1" current="${2:-}"
  local desc
  desc=$(agent_id_description "$agent_id")

  printf '\n%s%s%s — %s\n' "$BOLD" "$agent_id" "$RST" "${desc:-no description}"
  if [[ -n "$current" && "$current" != "null" ]]; then
    local cur_name cur_pr cur_mb
    cur_name=$(jq -r '.name' <<<"$current")
    cur_pr=$(jq -r '.pronouns' <<<"$current")
    cur_mb=$(jq -r '.mbti' <<<"$current")
    printf '  %scurrent persona:%s %s (%s, %s)\n' "$DIM" "$RST" "$cur_name" "$cur_pr" "$cur_mb"
  fi

  cat <<EOF
  1) auto-random — pick from pool by pronouns + MBTI preference
  2) browse      — see all 50 and pick
  3) custom      — name + pronouns + MBTI + voice
  4) skip        — keep canonical ruflo name (default)
EOF
  local choice
  choice=$(prompt_line "Choice [1-4]" "4")

  case "$choice" in
    1)
      local pr mb pick
      printf '\n  %sAuto-random filter:%s\n' "$BOLD" "$RST"
      pr=$(prompt_pronouns)
      mb=$(prompt_mbti)
      local include_tech
      include_tech=$(jq -r '.include_tech_founders // true' <<<"$(read_persona_map)")
      local filtered
      filtered=$(pool_filter_with_fallback "$pr" "$mb" "$include_tech")
      pick=$(pool_random_pick "$filtered") || {
        printf '  %sNo match in pool — skipping this agent.%s\n' "$YELLOW" "$RST"
        return
      }
      _commit_pool_pick "$agent_id" "$pick"
      ;;
    2)
      local idx
      idx=$(prompt_browse_pool)
      if [[ "$idx" -lt 0 ]]; then
        printf '  %scancelled — keeping default for %s%s\n' "$DIM" "$agent_id" "$RST"
        return
      fi
      local pick
      pick=$(jq --argjson i "$idx" '.[$i]' "$PERSONAS_POOL_FILE")
      _commit_pool_pick "$agent_id" "$pick"
      ;;
    3)
      _custom_flow "$agent_id"
      ;;
    *)
      # Skip — if a persona exists, remove it (user explicitly chose skip).
      if [[ -n "$current" && "$current" != "null" ]]; then
        remove_persona_entry "$agent_id"
        printf '  %sremoved existing persona for %s%s\n' "$DIM" "$agent_id" "$RST"
      fi
      ;;
  esac
}

_commit_pool_pick() {
  local agent_id="$1" pick="$2"
  local name pr mb voice src slug
  name=$(jq -r '.name' <<<"$pick")
  pr=$(jq -r '.pronouns' <<<"$pick")
  mb=$(jq -r '.mbti' <<<"$pick")
  voice=$(jq -r '.voice' <<<"$pick")
  src=$(jq -r '.source' <<<"$pick")
  slug=$(slugify "$name")
  set_persona_entry "$agent_id" "$name" "$pr" "$mb" "$voice" "$src" "$slug"
  printf '  %s✓%s %s → %s%s%s (%s, %s)\n' "$GREEN" "$RST" "$agent_id" "$BOLD" "$name" "$RST" "$pr" "$mb"
}

_custom_flow() {
  local agent_id="$1"
  local name pr mb voice slug
  while true; do
    name=$(prompt_line "Name (1-24 chars)" "")
    if [[ -n "$name" && ${#name} -le 24 ]]; then break; fi
    printf '  %sName must be 1-24 chars. Try again.%s\n' "$YELLOW" "$RST"
  done
  pr=$(prompt_pronouns)
  mb=$(prompt_mbti)
  voice=$(prompt_line "Voice / instruction overlay (≤200 chars)" "Embody this persona with a distinct voice.")
  voice=$(sanitize_voice "$voice")
  slug=$(slugify "$name")
  set_persona_entry "$agent_id" "$name" "$pr" "$mb" "$voice" "custom" "$slug"
  printf '  %s✓%s %s → %s%s%s (%s, %s)\n' "$GREEN" "$RST" "$agent_id" "$BOLD" "$name" "$RST" "$pr" "$mb"
}

# ── Top-level flows ──────────────────────────────────────────
flow_setup() {
  header "Ruflo Personas — custom names for your ruflo agents"

  if ! is_interactive; then
    log_info "Non-interactive — writing empty persona map (no aliases)"
    ensure_personas_dir
    write_persona_map "$(jq -n --argjson v "$PERSONAS_MAP_VERSION" \
        --arg ver "$(get_ruflo_version)" \
        '{_version: $v, ruflo_version_stamp: $ver, include_tech_founders: true, known_agents: [], personas: {}}')"
    # Snapshot installed agents so future sessions don't fire drift notices
    # against the agents present at install time.
    update_known_agents
    return
  fi

  # Top-level escape hatch.
  cat <<EOF

  You can give each ruflo agent a custom name (e.g. "Spock" instead of
  "ruflo-core:coder") with pronouns, an MBTI archetype, and a voice
  instruction. Personas are stored at ~/.cappy/ruflo-personas.json and
  rendered as agent alias files at ~/.claude/agents/<slug>.md.

  The TUI will display the persona name during agent runs.

EOF
  local quick_skip
  quick_skip=$(prompt_line "Skip all and keep ruflo defaults? [y/N]" "N")
  case "$quick_skip" in
    y|Y|yes|YES)
      ensure_personas_dir
      write_persona_map "$(jq -n --argjson v "$PERSONAS_MAP_VERSION" \
          --arg ver "$(get_ruflo_version)" \
          '{_version: $v, ruflo_version_stamp: $ver, include_tech_founders: true, known_agents: [], personas: {}}')"
      update_known_agents
      printf '\n  %s✓%s Skipped — ruflo agents keep their canonical names.\n' "$GREEN" "$RST"
      return
      ;;
  esac

  # Include tech founders pref.
  local include_tech_in
  include_tech_in=$(prompt_line "Include real-world tech figures (Jobs, Musk, Lovelace, ...) in the random pool? [Y/n]" "Y")
  local include_tech="true"
  case "$include_tech_in" in n|N|no|NO) include_tech="false" ;; esac

  ensure_personas_dir
  # Seed the map with current ruflo version + include_tech pref.
  local seed
  seed=$(jq -n --argjson v "$PERSONAS_MAP_VERSION" \
      --arg ver "$(get_ruflo_version)" \
      --argjson tech "$include_tech" \
      '{_version: $v, ruflo_version_stamp: $ver, include_tech_founders: $tech, personas: {}}')
  # Preserve existing entries if re-running setup.
  if [[ -f "$PERSONAS_MAP" ]]; then
    seed=$(jq --argjson seed "$seed" '$seed * {personas: (.personas // {})}' "$PERSONAS_MAP")
  fi
  write_persona_map "$seed"

  # Enumerate installed ruflo agents.
  local -a agents=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && agents+=("$line")
  done < <(discover_ruflo_agents)

  if (( ${#agents[@]} == 0 )); then
    log_warn "No installed ruflo agents found under $PLUGINS_DIR — nothing to configure."
    log_warn "Run 'bash ~/.cappy/repo/modules/ruflo/setup-ruflo.sh' first."
    return
  fi

  printf '\n  Found %s%d%s installed ruflo agent(s).\n' "$BOLD" "${#agents[@]}" "$RST"

  local current_map
  current_map=$(read_persona_map)
  for agent_id in "${agents[@]}"; do
    local current
    current=$(jq --arg k "$agent_id" '.personas[$k] // null' <<<"$current_map")
    configure_agent "$agent_id" "$current"
    current_map=$(read_persona_map)
  done

  # Render aliases.
  printf '\n'
  if [[ -x "$ALIAS_GENERATOR" ]]; then
    bash "$ALIAS_GENERATOR"
  else
    log_warn "alias-generator.sh not executable — skipping render. Run: bash $ALIAS_GENERATOR"
  fi

  # Snapshot which agents were "known" at this sync time. Drift detection
  # compares future installs against this list, not the persona map keys —
  # so skipped agents don't fire false-positive drift notices.
  update_known_agents

  printf '\n  %s✓%s Done. Run: %sclaude%s in any project to see the new names.\n' "$GREEN" "$RST" "$CYAN" "$RST"
}

flow_reset() {
  header "Ruflo Personas — reset"
  local ans
  ans=$(prompt_line "Wipe all personas and re-run setup? [y/N]" "N")
  case "$ans" in
    y|Y|yes|YES) ;;
    *) printf '  %scancelled%s\n' "$DIM" "$RST"; return ;;
  esac

  # Remove managed alias files.
  local removed=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rm -f "$f"
    removed=$((removed + 1))
  done < <(list_managed_aliases)
  log_info "Removed $removed managed alias file(s)"

  # Wipe the map.
  rm -f "$PERSONAS_MAP"
  log_info "Removed $PERSONAS_MAP"

  flow_setup
}

flow_sync() {
  header "Ruflo Personas — sync"

  if [[ ! -f "$PERSONAS_MAP" ]]; then
    log_info "No persona map exists — running initial setup instead."
    flow_setup
    return
  fi

  # Re-render aliases against current ruflo prompts (content drift).
  if [[ -x "$ALIAS_GENERATOR" ]]; then
    bash "$ALIAS_GENERATOR"
  else
    log_warn "alias-generator.sh not executable — skipping render"
  fi

  # Detect structural drift.
  local -a installed=() configured=() new_agents=() removed_agents=()
  while IFS= read -r a; do [[ -n "$a" ]] && installed+=("$a"); done < <(discover_ruflo_agents)
  while IFS= read -r a; do [[ -n "$a" ]] && configured+=("$a"); done < <(jq -r '.personas | keys[]?' "$PERSONAS_MAP")

  for a in "${installed[@]}"; do
    if ! printf '%s\n' "${configured[@]:-}" | grep -qx "$a"; then
      new_agents+=("$a")
    fi
  done
  for a in "${configured[@]:-}"; do
    if ! printf '%s\n' "${installed[@]:-}" | grep -qx "$a"; then
      removed_agents+=("$a")
    fi
  done

  if (( ${#new_agents[@]} == 0 && ${#removed_agents[@]} == 0 )); then
    log_success "No structural drift — aliases re-rendered against current ruflo."
    set_persona_map_field "ruflo_version_stamp" "$(get_ruflo_version)"
    update_known_agents
    return
  fi

  if (( ${#new_agents[@]} > 0 )); then
    printf '\n  %sNew ruflo agents since last sync:%s\n' "$BOLD" "$RST"
    for a in "${new_agents[@]}"; do printf '    + %s\n' "$a"; done
    if is_interactive; then
      local current_map
      current_map=$(read_persona_map)
      for a in "${new_agents[@]}"; do
        configure_agent "$a" ""
        current_map=$(read_persona_map)
      done
    else
      log_warn "Non-interactive sync — leaving new agents at canonical names."
    fi
  fi

  if (( ${#removed_agents[@]} > 0 )); then
    printf '\n  %sRuflo agents removed since last sync:%s\n' "$BOLD" "$RST"
    for a in "${removed_agents[@]}"; do
      local persona_name
      persona_name=$(jq -r --arg k "$a" '.personas[$k].name // "(unknown)"' "$PERSONAS_MAP")
      printf '    - %s (was: %s)\n' "$a" "$persona_name"
      remove_persona_entry "$a"
      # Also drop the alias file.
      local slug
      slug=$(jq -r --arg k "$a" '.personas[$k].alias_slug // ""' "$PERSONAS_MAP" 2>/dev/null || true)
      [[ -n "$slug" ]] && rm -f "${AGENTS_DIR}/${slug}.md" 2>/dev/null || true
    done
  fi

  # Re-render after structural changes + update version stamp + snapshot.
  if [[ -x "$ALIAS_GENERATOR" ]]; then
    bash "$ALIAS_GENERATOR"
  fi
  set_persona_map_field "ruflo_version_stamp" "$(get_ruflo_version)"
  update_known_agents
  printf '\n  %s✓%s Sync complete.\n' "$GREEN" "$RST"
}

# ── Main ─────────────────────────────────────────────────────
case "$MODE" in
  setup) flow_setup ;;
  reset) flow_reset ;;
  sync)  flow_sync ;;
esac
