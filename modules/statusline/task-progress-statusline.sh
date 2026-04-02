#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Task Progress Status Line for Claude Code
# Colorful status bar with git, tasks, context, cost, duration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

input=$(cat)

# ── ANSI Colors ──────────────────────────────────────────────
RST=$'\e[0m'
DIM=$'\e[2m'
BOLD=$'\e[1m'
BLINK=$'\e[5m'
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
MAGENTA=$'\e[35m'
CYAN=$'\e[36m'
WHITE=$'\e[37m'
BRIGHT_GREEN=$'\e[92m'
BRIGHT_YELLOW=$'\e[93m'
BRIGHT_CYAN=$'\e[96m'
BRIGHT_WHITE=$'\e[97m'
BG_DIM=$'\e[48;5;236m'

# ── Animation ────────────────────────────────────────────────
# Cycle through frames based on current time (changes each refresh)
TICK=$(date +%s)

# Spinner for status icon (cycles through braille dots)
SPINNERS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPIN_IDX=$(( TICK % ${#SPINNERS[@]} ))
SPINNER="${SPINNERS[$SPIN_IDX]}"

# Pulse chars for progress bar leading edge
PULSE_CHARS=("▓" "▒" "░" "▒")
PULSE_IDX=$(( TICK % ${#PULSE_CHARS[@]} ))
PULSE="${PULSE_CHARS[$PULSE_IDX]}"

# Activity dots for "working" indicator
DOTS_FRAMES=("·  " "·· " "···" " ··" "  ·" "   ")
DOTS_IDX=$(( TICK % ${#DOTS_FRAMES[@]} ))
DOTS="${DOTS_FRAMES[$DOTS_IDX]}"

# ── Parse stdin JSON ─────────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"' 2>/dev/null)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null)
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' 2>/dev/null)
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0' 2>/dev/null)
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0' 2>/dev/null)
agent_name=$(echo "$input" | jq -r '.agent.name // ""' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)

# ── Helpers ──────────────────────────────────────────────────
context_color() {
  local pct=$1
  if [ "$pct" -ge 85 ] 2>/dev/null; then echo "$RED"
  elif [ "$pct" -ge 70 ] 2>/dev/null; then echo "$YELLOW"
  elif [ "$pct" -ge 50 ] 2>/dev/null; then echo "$BRIGHT_YELLOW"
  else echo "$GREEN"
  fi
}

colored_bar() {
  local pct=$1 width=${2:-12}
  local filled=$(( (pct * width + 50) / 100 ))
  local empty=$(( width - filled ))
  local color
  color=$(context_color "$pct")
  printf "%s" "${color}"
  for ((i=0; i<filled; i++)); do printf "█"; done
  printf "%s" "${DIM}"
  for ((i=0; i<empty; i++)); do printf "░"; done
  printf "%s" "${RST}"
}

format_duration() {
  local ms=$1
  local secs=$(( ms / 1000 ))
  if [ "$secs" -lt 60 ]; then
    echo "<1m"
  elif [ "$secs" -lt 3600 ]; then
    echo "$(( secs / 60 ))m"
  else
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    echo "${h}h ${m}m"
  fi
}

# ── Line 1: Model │ Context │ Git │ Cost │ Duration ──────────
parts=()

# Model name
parts+=("${BRIGHT_CYAN}${BOLD}${model}${RST}")

# Context bar + percentage
ctx_color=$(context_color "$ctx_pct")
ctx_bar=$(colored_bar "$ctx_pct" 10)
parts+=("${ctx_bar} ${ctx_color}${ctx_pct}%${RST}")

# Project path + git
if [ -n "$cwd" ]; then
  project=$(basename "$cwd")
  git_part=""
  if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
      dirty=""
      if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)" ]; then
        dirty="${YELLOW}*${RST}"
      fi
      # Ahead/behind
      ab=""
      revlist=$(git -C "$cwd" rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
      if [ -n "$revlist" ]; then
        behind=$(echo "$revlist" | awk '{print $1}')
        ahead=$(echo "$revlist" | awk '{print $2}')
        [ "$ahead" -gt 0 ] 2>/dev/null && ab+=" ${GREEN}↑${ahead}${RST}"
        [ "$behind" -gt 0 ] 2>/dev/null && ab+=" ${RED}↓${behind}${RST}"
      fi
      git_part=" ${MAGENTA}git:(${RST}${CYAN}${branch}${dirty}${ab}${MAGENTA})${RST}"
    fi
  fi
  parts+=("${YELLOW}${project}${RST}${git_part}")
fi

# Lines changed
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
  changes=""
  [ "$lines_added" -gt 0 ] 2>/dev/null && changes+="${GREEN}+${lines_added}${RST}"
  if [ "$lines_removed" -gt 0 ] 2>/dev/null; then
    [ -n "$changes" ] && changes+=" "
    changes+="${RED}-${lines_removed}${RST}"
  fi
  parts+=("${changes}")
fi

# Cost
if [ "$(echo "$cost > 0" | bc 2>/dev/null)" = "1" ]; then
  cost_fmt=$(printf "%.2f" "$cost")
  if [ "$(echo "$cost >= 5" | bc 2>/dev/null)" = "1" ]; then
    parts+=("${RED}\$${cost_fmt}${RST}")
  elif [ "$(echo "$cost >= 2" | bc 2>/dev/null)" = "1" ]; then
    parts+=("${YELLOW}\$${cost_fmt}${RST}")
  else
    parts+=("${DIM}\$${cost_fmt}${RST}")
  fi
fi

# Duration
if [ "$duration_ms" -gt 0 ] 2>/dev/null; then
  dur=$(format_duration "$duration_ms")
  parts+=("${DIM}⏱ ${dur}${RST}")
fi

# Agent name (if in a team)
if [ -n "$agent_name" ]; then
  parts+=("${MAGENTA}@${agent_name}${RST}")
fi

# Join line 1
line1=""
for i in "${!parts[@]}"; do
  if [ "$i" -gt 0 ]; then
    line1+=" ${DIM}│${RST} "
  fi
  line1+="${parts[$i]}"
done

echo "$line1"

# ── Line 2: Task Progress (if tasks exist) ───────────────────

# Find the task directory for THIS session
# Priority: 1) session_id match, 2) team tasks (named dirs), 3) most recent
task_dir=""
latest_mtime=0

# First: try exact session_id match
if [ -n "$session_id" ] && [ -d "$HOME/.claude/tasks/$session_id" ]; then
  task_dir="$HOME/.claude/tasks/$session_id/"
  latest_mtime=$(find "$task_dir" -name "*.json" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1)
fi

# Second: if no session match, check for team dirs that reference this session
# Also look for named team dirs that were recently active
if [ -z "$task_dir" ] || [ -z "$latest_mtime" ] || [ "$latest_mtime" = "0" ]; then
  # Check if this session is part of a team by looking at team configs
  if [ -n "$agent_name" ]; then
    # Agent sessions belong to teams — find the team's task dir
    for team_cfg in ~/.claude/teams/*/config.json; do
      [ -f "$team_cfg" ] || continue
      team_dir=$(dirname "$team_cfg")
      team_name=$(basename "$team_dir")
      if [ -d "$HOME/.claude/tasks/$team_name" ]; then
        dir_mtime=$(find "$HOME/.claude/tasks/$team_name" -name "*.json" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1)
        if [ -n "$dir_mtime" ] && [ "$dir_mtime" -gt "$latest_mtime" ] 2>/dev/null; then
          latest_mtime=$dir_mtime
          task_dir="$HOME/.claude/tasks/$team_name/"
        fi
      fi
    done
  fi

  # Fallback: most recently modified task dir (but only named ones, skip UUIDs for non-agent sessions)
  if [ -z "$task_dir" ] || [ "$latest_mtime" = "0" ]; then
    for dir in ~/.claude/tasks/*/; do
      [ -d "$dir" ] || continue
      dirname=$(basename "$dir")
      # For non-agent sessions, skip UUID-named dirs (belong to other sessions)
      if [ -z "$agent_name" ]; then
        case "$dirname" in
          ????????-????-????-????-????????????) continue ;;
        esac
      fi
      newest=$(find "$dir" -name "*.json" -type f -exec stat -f "%m" {} \; 2>/dev/null | sort -rn | head -1)
      if [ -n "$newest" ] && [ "$newest" -gt "$latest_mtime" ] 2>/dev/null; then
        latest_mtime=$newest
        task_dir="$dir"
      fi
    done
  fi
fi

# Only show tasks from recent sessions (last 6 hours)
now=$(date +%s)
if [ -n "$task_dir" ] && [ "$latest_mtime" -gt 0 ] 2>/dev/null; then
  age=$(( now - latest_mtime ))
  [ "$age" -gt 21600 ] && task_dir=""
fi

if [ -n "$task_dir" ]; then
  total=0; completed=0; in_progress=0; blocked=0; pending_count=0

  for f in "$task_dir"*.json; do
    [ -f "$f" ] || continue
    status=$(jq -r '.status // "pending"' "$f" 2>/dev/null)
    blocked_by=$(jq -r '.blockedBy // [] | length' "$f" 2>/dev/null)
    total=$((total + 1))
    case "$status" in
      completed) completed=$((completed + 1)) ;;
      in_progress)
        if [ "$blocked_by" -gt 0 ] 2>/dev/null; then
          blocked=$((blocked + 1))
        else
          in_progress=$((in_progress + 1))
        fi ;;
      *)
        if [ "$blocked_by" -gt 0 ] 2>/dev/null; then
          blocked=$((blocked + 1))
        else
          pending_count=$((pending_count + 1))
        fi ;;
    esac
  done

  if [ "$total" -gt 0 ]; then
    # Build colored task progress bar (20 chars)
    bar_w=20
    c_chars=$(( (completed * bar_w) / total ))
    a_chars=$(( (in_progress * bar_w) / total ))
    b_chars=$(( (blocked * bar_w) / total ))
    p_chars=$(( bar_w - c_chars - a_chars - b_chars ))
    [ "$p_chars" -lt 0 ] && p_chars=0

    # Ensure at least 1 char for non-zero counts
    [ "$completed" -gt 0 ] && [ "$c_chars" -eq 0 ] && c_chars=1
    [ "$in_progress" -gt 0 ] && [ "$a_chars" -eq 0 ] && a_chars=1
    [ "$blocked" -gt 0 ] && [ "$b_chars" -eq 0 ] && b_chars=1

    # Rebalance
    over=$(( c_chars + a_chars + b_chars + p_chars - bar_w ))
    if [ "$over" -gt 0 ]; then
      p_chars=$(( p_chars - over ))
      [ "$p_chars" -lt 0 ] && p_chars=0
    fi
    under=$(( bar_w - c_chars - a_chars - b_chars - p_chars ))
    [ "$under" -gt 0 ] && p_chars=$(( p_chars + under ))

    bar="${GREEN}"
    for ((i=0; i<c_chars; i++)); do bar+="█"; done

    # Active section with animated leading edge
    if [ "$a_chars" -gt 0 ]; then
      bar+="${BRIGHT_CYAN}"
      for ((i=0; i<a_chars-1; i++)); do bar+="▓"; done
      # Pulsing leading edge on the last active char
      bar+="${BRIGHT_CYAN}${BOLD}${PULSE}${RST}"
    fi

    bar+="${YELLOW}"
    for ((i=0; i<b_chars; i++)); do bar+="░"; done
    bar+="${DIM}"
    for ((i=0; i<p_chars; i++)); do bar+="·"; done
    bar+="${RST}"

    # ETA
    remaining=$((total - completed))
    if [ "$remaining" -eq 0 ]; then
      eta="${GREEN}done!${RST}"
    elif [ "$in_progress" -gt 0 ]; then
      eta_min=$(( (remaining * 10 + in_progress - 1) / in_progress ))
      if [ "$eta_min" -lt 60 ]; then
        eta="${DIM}~${eta_min}m${RST}"
      else
        eta="${DIM}~$(( eta_min / 60 ))h${RST}"
      fi
    else
      eta="${DIM}waiting${RST}"
    fi

    # Project/team name
    team=$(basename "$task_dir")
    if [ ${#team} -gt 18 ]; then
      team="${team:0:15}..."
    fi

    # Status counts
    counts=""
    [ "$completed" -gt 0 ] && counts+="${GREEN}✓${completed}${RST} "
    [ "$in_progress" -gt 0 ] && counts+="${BRIGHT_CYAN}▶${in_progress}${RST} "
    [ "$blocked" -gt 0 ] && counts+="${YELLOW}⏸${blocked}${RST} "
    [ "$pending_count" -gt 0 ] && counts+="${DIM}○${pending_count}${RST} "

    # All done celebration
    if [ "$completed" -eq "$total" ]; then
      printf "${GREEN}✨${RST} ${DIM}${team}${RST} [${bar}] ${BRIGHT_GREEN}${BOLD}${completed}/${total} complete${RST} ${counts} ${eta}\n"
    elif [ "$in_progress" -gt 0 ]; then
      # Animated spinner when tasks are actively being worked
      printf "${BRIGHT_CYAN}${SPINNER}${RST} ${DIM}${team}${RST} [${bar}] ${BRIGHT_WHITE}${completed}/${total}${RST} ${counts} ${eta} ${BRIGHT_CYAN}${DOTS}${RST}\n"
    else
      printf "${YELLOW}⏸${RST} ${DIM}${team}${RST} [${bar}] ${BRIGHT_WHITE}${completed}/${total}${RST} ${counts} ${eta}\n"
    fi
  fi
fi
