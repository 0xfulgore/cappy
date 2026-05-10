#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# release.sh — bump version, tag, and push
#
# Usage:
#   ./release.sh patch              # 1.0.0 → 1.0.1
#   ./release.sh minor              # 1.0.0 → 1.1.0
#   ./release.sh major              # 1.0.0 → 2.0.0
#   ./release.sh 1.2.3              # explicit version
#   ./release.sh patch --dry-run    # show what would happen
#   ./release.sh patch --no-push    # tag locally, don't push
#   ./release.sh patch --gh         # also `gh release create`
#
# Versioning policy (semver):
#   MAJOR — breaking changes (module removed, incompatible config)
#   MINOR — new modules / features, backward-compatible
#   PATCH — bug fixes, docs, internal cleanups
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# ── Tempfile cleanup ─────────────────────────────────────────
# Registered early so any exit (error or normal) cleans up.
# Additional paths are added to _TMPFILES as they are created.
_TMPFILES=()
_cleanup_tmpfiles() {
  for _f in "${_TMPFILES[@]:-}"; do
    rm -f "$_f"
  done
}
trap '_cleanup_tmpfiles' EXIT

if [[ ! -f forge.json ]]; then
  printf '[err]  not in cappy repo (no forge.json here)\n' >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  printf '[err]  jq is required\n' >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  printf '[err]  git is required\n' >&2
  exit 1
fi

# ── ANSI ─────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RST=$'\e[0m'; BOLD=$'\e[1m'; DIM=$'\e[2m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; CYAN=$'\e[36m'
  BRIGHT_CYAN=$'\e[96m'; BRIGHT_MAGENTA=$'\e[95m'
else
  RST=""; BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""
  BRIGHT_CYAN=""; BRIGHT_MAGENTA=""
fi

err()  { printf '%s[err]%s  %s\n' "$RED" "$RST" "$*" >&2; }
ok()   { printf '%s[ ok]%s  %s\n' "$GREEN" "$RST" "$*"; }
info() { printf '%s[info]%s %s\n' "$CYAN" "$RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$YELLOW" "$RST" "$*"; }
step() { printf '\n%s━━ %s%s\n' "$BRIGHT_CYAN" "$*" "$RST"; }

# ── Parse args ───────────────────────────────────────────────
DRY_RUN=0
PUSH=1
GH=0
BUMP=""

usage() {
  sed -n '/^# Usage:/,/^# ━/p' "$0" | sed 's/^# //; s/^#//; s/^━.*//'
}

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-push) PUSH=0 ;;
    --gh)      GH=1 ;;
    -h|--help) usage; exit 0 ;;
    major|minor|patch) BUMP="$1" ;;
    [0-9]*.[0-9]*.[0-9]*) BUMP="$1" ;;
    *) err "unknown arg: $1"; usage; exit 2 ;;
  esac
  shift
done

if [[ -z "$BUMP" ]]; then
  err "missing bump arg (major|minor|patch|X.Y.Z)"
  usage
  exit 2
fi

# ── Preflight: clean tree + on main ──────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
  err "working tree dirty — commit or stash before releasing:"
  git status --short >&2
  exit 3
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$branch" != "main" ]]; then
  warn "not on main (current: $branch)"
  printf "Continue anyway? [y/N] "
  read -r ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) ;;
    *) info "aborted"; exit 4 ;;
  esac
fi

step "Fetching tags"
git fetch --tags --quiet

# ── Upstream sync guard ──────────────────────────────────────
# Reject the release early if local main is behind origin/main.
# A diverged local branch means the commit + tag would be created on
# stale state; the subsequent push would then fail (or force-push
# would be needed), leaving the repo in a bad state.
if git rev-parse --verify "origin/main" >/dev/null 2>&1; then
  # Check origin/main is an ancestor of HEAD (i.e., local is at-or-ahead of origin).
  # If origin/main is NOT an ancestor of HEAD, either local is behind or the branches
  # have diverged — both block a release.
  if ! git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
    err "local branch is behind origin/main (or diverged) — pull before releasing"
    err "Recovery: git pull --ff-only origin main"
    exit 10
  fi
fi

# ── Compute new version ──────────────────────────────────────
current=$(jq -r '.version' forge.json)
if [[ -z "$current" || "$current" == "null" ]]; then
  err "could not read version from forge.json"
  exit 5
fi

case "$BUMP" in
  major|minor|patch)
    if ! [[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      err "current version '$current' isn't valid semver — pass an explicit X.Y.Z"
      exit 6
    fi
    maj=${BASH_REMATCH[1]}
    min=${BASH_REMATCH[2]}
    pat=${BASH_REMATCH[3]}
    case "$BUMP" in
      major) new="$((maj+1)).0.0" ;;
      minor) new="${maj}.$((min+1)).0" ;;
      patch) new="${maj}.${min}.$((pat+1))" ;;
    esac
    ;;
  *) new="$BUMP" ;;
esac

if ! [[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  err "computed version '$new' isn't valid semver"
  exit 7
fi

tag="v${new}"

# ── Tag collision? ───────────────────────────────────────────
if git rev-parse --verify "refs/tags/$tag" >/dev/null 2>&1; then
  err "tag $tag already exists locally"
  exit 8
fi
if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  err "tag $tag already exists on origin"
  exit 9
fi

# ── Changelog (commits since last tag) ──────────────────────
last_tag=$(git tag --sort=-v:refname | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || true)
if [[ -n "$last_tag" ]]; then
  commits=$(git log --pretty='format:- %s (%h)' "${last_tag}..HEAD")
  range_label="since $last_tag"
else
  commits=$(git log --pretty='format:- %s (%h)')
  range_label="full history"
fi

step "Release plan"
printf '  %scurrent%s    %s\n' "$DIM" "$RST" "$current"
printf '  %snew%s        %s%s%s%s\n' "$DIM" "$RST" "$BOLD" "$BRIGHT_MAGENTA" "$new" "$RST"
printf '  %stag%s        %s\n' "$DIM" "$RST" "$tag"
printf '  %slast tag%s   %s\n' "$DIM" "$RST" "${last_tag:-(none)}"
printf '  %scommits%s    %s\n' "$DIM" "$RST" "$range_label"

if [[ -n "$commits" ]]; then
  printf '\n%s%sChangelog:%s\n' "$BOLD" "$BRIGHT_CYAN" "$RST"
  printf '%s\n' "$commits" | head -30
  total=$(printf '%s\n' "$commits" | wc -l | tr -d ' ')
  if (( total > 30 )); then
    printf '%s... (+%d more)%s\n' "$DIM" $((total-30)) "$RST"
  fi
else
  warn "no commits since $last_tag — releasing anyway?"
fi

if (( DRY_RUN )); then
  _push_note="$([[ $PUSH -eq 1 ]] && echo "" || echo " (skipped --no-push)")"
  _gh_note="$([[ $GH -eq 1 ]] && echo ", gh release create + append SHA-256 checksum" || echo ", print SHA-256 checksum for manual paste")"
  printf '\n%s[dry-run]%s would: bump forge.json, commit, tag %s, push%s%s\n' \
    "$YELLOW" "$RST" "$tag" "$_push_note" "$_gh_note"
  exit 0
fi

# ── Confirm ──────────────────────────────────────────────────
printf '\nProceed? [y/N] '
read -r ans
case "$ans" in
  [Yy]|[Yy][Ee][Ss]) ;;
  *) info "aborted"; exit 0 ;;
esac

# ── Bump forge.json ──────────────────────────────────────────
step "Bumping forge.json: $current → $new"
tmp=$(mktemp)
_TMPFILES+=("$tmp")
jq --arg v "$new" '.version = $v' forge.json > "$tmp"
mv "$tmp" forge.json
ok "forge.json updated"

# ── Commit ───────────────────────────────────────────────────
step "Committing"
git add forge.json
{
  printf 'release: %s\n\n' "$tag"
  if [[ -n "$commits" ]]; then
    printf 'Changelog (%s):\n%s\n' "$range_label" "$commits"
  fi
} | git commit -F -
ok "committed"

# ── Tag ──────────────────────────────────────────────────────
step "Tagging $tag (annotated)"
{
  printf 'Release %s\n\n' "$tag"
  if [[ -n "$commits" ]]; then
    printf '%s\n' "$commits"
  fi
} | git tag -a "$tag" -F -
ok "tagged"

# ── Push ─────────────────────────────────────────────────────
# push_or_recover: push commit then tag, with explicit error handling
# and copy-pasteable recovery commands for each partial-failure scenario.
push_or_recover() {
  local _tag="$1"
  if ! git push --quiet; then
    err "git push (commit) failed — nothing was pushed to origin"
    err "Recovery (no remote state to clean up):"
    err "  git tag -d $_tag"
    err "  git reset --hard HEAD~1"
    return 1
  fi
  if ! git push --quiet origin "$_tag"; then
    err "git push (tag) failed AFTER commit was already pushed to origin"
    err "The commit is on origin but the tag is NOT. Recovery options:"
    err "  Option A — retry the tag push (if transient network issue):"
    err "    git push origin $_tag"
    err "  Option B — revert commit from origin and clean up locally:"
    err "    git push --force-with-lease origin HEAD~1:main"
    err "    git tag -d $_tag"
    err "    git reset --hard HEAD~1"
    return 1
  fi
}

if (( PUSH )); then
  step "Pushing"
  push_or_recover "$tag" || exit 12
  ok "pushed commit and tag $tag"
else
  warn "--no-push: tag created locally"
  info "push later with: git push && git push origin $tag"
fi

# ── GitHub release ───────────────────────────────────────────
# Create first so the subsequent checksum step can append to the notes.
if (( GH )); then
  if command -v gh >/dev/null 2>&1; then
    step "Creating GitHub release"
    if (( PUSH )); then
      if gh release view "$tag" >/dev/null 2>&1; then
        warn "GitHub release $tag already exists — using existing release"
      else
        gh release create "$tag" --generate-notes --title "$tag" || {
          err "gh release create failed — check 'gh auth status' and try again"
          exit 11
        }
        ok "GitHub release created"
      fi
    else
      warn "skipping gh release — tag wasn't pushed"
    fi
  else
    warn "gh CLI not found — skipping GitHub release"
  fi
fi

# ── SHA-256 checksum ─────────────────────────────────────────
# Compute a SHA-256 of the release tarball so users can verify integrity.
# If --gh was passed and the release exists, the checksum is appended to
# the release notes. Otherwise it is printed for the maintainer to paste
# manually into the GitHub release page.
step "Computing SHA-256 checksum"
_tarball="/tmp/cappy-${new}.tar.gz"
_TMPFILES+=("$_tarball")
git archive --format=tar.gz --prefix="cappy-${new}/" -o "$_tarball" "$tag"
if command -v shasum >/dev/null 2>&1; then
  _sha256=$(shasum -a 256 "$_tarball" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  _sha256=$(sha256sum "$_tarball" | awk '{print $1}')
else
  warn "neither shasum nor sha256sum found — skipping checksum"
  _sha256=""
fi

if [[ -n "$_sha256" ]]; then
  ok "Release tarball SHA-256: $_sha256"

  if (( GH )) && command -v gh >/dev/null 2>&1 && (( PUSH )) \
      && gh release view "$tag" >/dev/null 2>&1; then
    # Append the verify block to whatever notes gh auto-generated above
    _notes_tmp=$(mktemp)
    _TMPFILES+=("$_notes_tmp")
    _existing_notes=$(gh release view "$tag" --json body -q .body 2>/dev/null || true)
    {
      if [[ -n "$_existing_notes" ]]; then
        printf '%s\n\n' "$_existing_notes"
      fi
      printf '## Verify integrity\n\n'
      printf '```sh\n'
      printf 'shasum -a 256 cappy-%s.tar.gz\n' "$new"
      printf '# expected: %s\n' "$_sha256"
      printf '```\n\n'
      printf 'Or download from https://github.com/0xfulgore/cappy/archive/refs/tags/%s.tar.gz\n' "$tag"
      printf 'and verify against the SHA-256 above.\n'
    } > "$_notes_tmp"
    gh release edit "$tag" --notes-file "$_notes_tmp"
    ok "checksum appended to GitHub release notes"
  else
    info "Add this checksum manually to the GitHub release notes:"
    info "  SHA-256 (cappy-${new}.tar.gz) = $_sha256"
  fi
fi

step "Done"
ok "released $tag"
printf '\n%sUsers will see this update within 24h via the cappy statusline notifier.%s\n' "$DIM" "$RST"
printf '%sTo verify: cappy check && cappy status%s\n\n' "$DIM" "$RST"
