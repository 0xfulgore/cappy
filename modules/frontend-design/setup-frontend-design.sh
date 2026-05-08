#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# setup-frontend-design.sh — install the frontend-design skill
#
# frontend-design is Anthropic's official skill for production
# frontend work, shipped inside the anthropics/claude-code repo at
# plugins/frontend-design/skills/frontend-design/. We sparse-checkout
# that subtree into ~/.claude/skills/frontend-design so Claude Code
# picks it up at user scope alongside any other skills.
#
# Coexists cleanly with huashu-design: different skill name, different
# install path. huashu-design is HTML hi-fi prototyping; frontend-design
# is production frontend code with strong aesthetic direction.
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

REPO_URL="${FRONTEND_DESIGN_REPO:-https://github.com/anthropics/claude-code.git}"
SKILL_SUBPATH="plugins/frontend-design/skills/frontend-design"
SKILL_DIR="${HOME}/.claude/skills/frontend-design"
WORK_DIR="$(mktemp -d -t cappy-frontend-design.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

if ! command -v git >/dev/null 2>&1; then
  log_error "git not found — cannot install frontend-design"
  exit 1
fi

mkdir -p "${HOME}/.claude/skills"

if [[ -e "${SKILL_DIR}" && ! -d "${SKILL_DIR}" ]]; then
  log_warn "${SKILL_DIR} exists but isn't a directory — skipping"
  exit 0
fi

log_info "Fetching frontend-design from ${REPO_URL} (sparse)"
if ! git clone --depth 1 --filter=blob:none --sparse --quiet "${REPO_URL}" "${WORK_DIR}/checkout" 2>/dev/null; then
  log_error "git clone failed for ${REPO_URL}"
  exit 1
fi

if ! git -C "${WORK_DIR}/checkout" sparse-checkout set "${SKILL_SUBPATH}" >/dev/null 2>&1; then
  log_error "sparse-checkout failed for ${SKILL_SUBPATH}"
  exit 1
fi

SRC="${WORK_DIR}/checkout/${SKILL_SUBPATH}"
if [[ ! -d "${SRC}" ]]; then
  log_error "Expected ${SKILL_SUBPATH} in checkout but it's missing — upstream layout may have changed"
  exit 1
fi

# Replace existing install atomically so partial state can't linger.
rm -rf "${SKILL_DIR}"
mkdir -p "${SKILL_DIR}"
# Copy contents (not the directory itself) so SKILL.md ends up at the root.
cp -R "${SRC}/." "${SKILL_DIR}/"

log_success "frontend-design installed (use via Skill('frontend-design'))"
