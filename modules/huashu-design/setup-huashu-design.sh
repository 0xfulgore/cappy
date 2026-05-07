#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# setup-huashu-design.sh — install the huashu-design skill
#
# huashu-design is a pure Claude Code skill (SKILL.md + assets +
# scripts) maintained at github.com/alchaincyf/huashu-design.
# We shallow-clone it into ~/.claude/skills/huashu-design so Claude
# Code picks it up at user scope.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Sourced by install.sh so log_* helpers are already in scope. Fall back
# to plain printf if invoked standalone for testing.
if ! type log_info >/dev/null 2>&1; then
  log_info()    { printf '[info] %s\n' "$*"; }
  log_success() { printf '[ ok] %s\n' "$*"; }
  log_warn()    { printf '[warn] %s\n' "$*" >&2; }
  log_error()   { printf '[err]  %s\n' "$*" >&2; }
fi

REPO_URL="${HUASHU_DESIGN_REPO:-https://github.com/alchaincyf/huashu-design.git}"
SKILL_DIR="${HOME}/.claude/skills/huashu-design"

if ! command -v git >/dev/null 2>&1; then
  log_error "git not found — cannot install huashu-design"
  exit 1
fi

mkdir -p "${HOME}/.claude/skills"

if [[ -d "${SKILL_DIR}/.git" ]]; then
  log_info "huashu-design already at ${SKILL_DIR} — pulling latest"
  if ! git -C "${SKILL_DIR}" pull --ff-only --quiet 2>/dev/null; then
    log_warn "git pull failed — leaving existing checkout in place"
  else
    log_success "huashu-design up to date"
  fi
elif [[ -e "${SKILL_DIR}" ]]; then
  log_warn "${SKILL_DIR} exists but isn't a git checkout — skipping"
  log_info "Remove it manually if you want a fresh install: rm -rf ${SKILL_DIR}"
else
  log_info "Cloning huashu-design (shallow) → ${SKILL_DIR}"
  if ! git clone --depth 1 --quiet "${REPO_URL}" "${SKILL_DIR}"; then
    log_error "git clone failed for ${REPO_URL}"
    exit 1
  fi
  log_success "huashu-design installed (use via Skill('huashu-design'))"
fi
