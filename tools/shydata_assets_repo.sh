#!/usr/bin/env bash
# tools/shydata_update_repo_assets.sh
#
# Update ONLY repository assets (docs/, tools/, root files) into the shydata repo.
# - DOES NOT touch data/
# - KEEPS tools/shydata_create_release.sh (never overwritten)
#
# Typical use:
#   ./tools/shydata_assets_repo.sh \
#     --src /path/to/assets_source_repo \
#     --repo /path/to/shydata \
#     --commit --push
#
# Notes:
# - Source repo is expected to have: docs/, tools/, and optionally root files like
#   README.md, LICENSE, CODEOWNERS, CHANGELOG.md, .github/, etc.
#
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[shydata-assets] $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

SRC=""
REPO=""
DO_DRYRUN="false"
DO_COMMIT="false"
DO_PUSH="false"
REMOTE="origin"
BRANCH="main"
COMMIT_MSG="Update repository assets"

# What to sync
SYNC_DOCS="true"
SYNC_TOOLS="true"
SYNC_ROOT="true"
SYNC_GITHUB_DIR="true"   # .github/

usage() {
  cat <<EOF
Usage:
  $0 --src <source_repo_or_assets_dir> --repo <shydata_repo>
     [--dry-run] [--commit] [--push] [--remote origin] [--branch main]
     [--msg "Commit message"]
     [--no-docs] [--no-tools] [--no-root] [--no-github]

Behavior:
  - Syncs docs/  -> <repo>/docs/
  - Syncs tools/ -> <repo>/tools/  (EXCEPT keeps tools/shydata_create_release.sh)
  - Optionally syncs root files (README.md, LICENSE, CODEOWNERS, etc.)
  - Optionally syncs .github/ workflows, templates, etc.
  - NEVER touches <repo>/data/

Examples:
  Update assets + commit:
    $0 --src /path/to/source --repo /path/to/shydata --commit

  Dry-run:
    $0 --src /path/to/source --repo /path/to/shydata --dry-run

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --dry-run) DO_DRYRUN="true"; shift 1 ;;
    --commit) DO_COMMIT="true"; shift 1 ;;
    --push) DO_PUSH="true"; shift 1 ;;
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --msg) COMMIT_MSG="${2:-}"; shift 2 ;;
    --no-docs) SYNC_DOCS="false"; shift 1 ;;
    --no-tools) SYNC_TOOLS="false"; shift 1 ;;
    --no-root) SYNC_ROOT="false"; shift 1 ;;
    --no-github) SYNC_GITHUB_DIR="false"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
done

[[ -n "$SRC" ]] || { usage; die "--src is required"; }
[[ -n "$REPO" ]] || { usage; die "--repo is required"; }
[[ -d "$SRC" ]] || die "Source folder not found: $SRC"
[[ -d "$REPO" ]] || die "Repo folder not found: $REPO"

need_cmd rsync
need_cmd git
need_cmd mkdir
need_cmd test

# Resolve absolute paths
SRC_ABS="$(cd "$SRC" && pwd -P)"
REPO_ABS="$(cd "$REPO" && pwd -P)"

# Safety: ensure target is a git repo
cd "$REPO_ABS"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Target is not a git repo: $REPO_ABS"

# Safety: never allow accidental sync into /
[[ "$REPO_ABS" != "/" ]] || die "Refusing to operate on /"

# Safety: ensure we are not about to touch data/
if [[ ! -d "$REPO_ABS/data" ]]; then
  log "WARNING: $REPO_ABS/data does not exist (ok if intentional). This script will still NOT create or sync data/."
fi

RSYNC_FLAGS=(-a --delete --human-readable --itemize-changes)
if [[ "$DO_DRYRUN" == "true" ]]; then
  RSYNC_FLAGS+=(--dry-run)
  log "Dry-run enabled: no changes will be written."
fi

# --------------------------
# Sync docs/
# --------------------------
if [[ "$SYNC_DOCS" == "true" ]]; then
  if [[ -d "$SRC_ABS/docs" ]]; then
    log "Syncing docs/: $SRC_ABS/docs/ -> $REPO_ABS/docs/"
    mkdir -p "$REPO_ABS/docs"
    rsync "${RSYNC_FLAGS[@]}" "$SRC_ABS/docs/" "$REPO_ABS/docs/"
  else
    log "Skipping docs/: source does not contain docs/ ($SRC_ABS/docs)"
  fi
fi

# --------------------------
# Sync tools/ (but keep shydata_create_release.sh)
# --------------------------
if [[ "$SYNC_TOOLS" == "true" ]]; then
  if [[ -d "$SRC_ABS/tools" ]]; then
    log "Syncing tools/ (keeping tools/shydata_create_release.sh): $SRC_ABS/tools/ -> $REPO_ABS/tools/"
    mkdir -p "$REPO_ABS/tools"

    # Protect: never overwrite the release script
    # - exclude it from sync
    # - also avoid deleting it due to --delete
    rsync "${RSYNC_FLAGS[@]}" \
      --exclude 'shydata_create_release.sh' \
      "$SRC_ABS/tools/" "$REPO_ABS/tools/"

    log "Ensuring tools/shydata_create_release.sh remains untouched."
  else
    log "Skipping tools/: source does not contain tools/ ($SRC_ABS/tools)"
  fi
fi

# --------------------------
# Sync .github/ (workflows, templates)
# --------------------------
if [[ "$SYNC_GITHUB_DIR" == "true" ]]; then
  if [[ -d "$SRC_ABS/.github" ]]; then
    log "Syncing .github/: $SRC_ABS/.github/ -> $REPO_ABS/.github/"
    mkdir -p "$REPO_ABS/.github"
    rsync "${RSYNC_FLAGS[@]}" "$SRC_ABS/.github/" "$REPO_ABS/.github/"
  else
    log "Skipping .github/: source does not contain .github/ ($SRC_ABS/.github)"
  fi
fi

# --------------------------
# Sync selected root files (safe list)
# --------------------------
if [[ "$SYNC_ROOT" == "true" ]]; then
  # Add/remove files here as you like (safe + typical repo assets)
  ROOT_FILES=(
    "README.md"
    "LICENSE"
    "LICENSE.md"
    "CODEOWNERS"
    "CHANGELOG.md"
    ".gitignore"
    ".gitattributes"
    ".editorconfig"
  )

  for f in "${ROOT_FILES[@]}"; do
    if [[ -f "$SRC_ABS/$f" ]]; then
      log "Syncing root file: $f"
      rsync "${RSYNC_FLAGS[@]}" "$SRC_ABS/$f" "$REPO_ABS/$f"
    fi
  done
fi

# --------------------------
# Final: show status + optionally commit/push
# --------------------------
cd "$REPO_ABS"

log "Git status (porcelain):"
git status --porcelain || true

if [[ "$DO_DRYRUN" == "true" ]]; then
  log "Dry-run complete. No commit performed."
  exit 0
fi

if [[ "$DO_COMMIT" == "true" ]]; then
  # Stage only what this script is meant to manage
  # (never stage data/)
  git add docs tools .github 2>/dev/null || true
  git add README.md LICENSE LICENSE.md CODEOWNERS CHANGELOG.md .gitignore .gitattributes .editorconfig 2>/dev/null || true

  if git diff --cached --quiet; then
    log "Nothing staged to commit."
  else
    git commit -m "$COMMIT_MSG"
    log "Committed: $COMMIT_MSG"
  fi
fi

if [[ "$DO_PUSH" == "true" ]]; then
  log "Pushing to $REMOTE $BRANCH"
  git push "$REMOTE" "$BRANCH"
  log "Push complete."
else
  log "Push skipped (use --push)."
fi

log "Done."

