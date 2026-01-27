#!/usr/bin/env bash
# tools/shydata_create_release.sh
#
# Flat layout:
#   - Copies from shybox/dset -> shydata/data/   (NO /<VERSION>, overwrites each run)
#   - Updates shydata/CHANGELOG.md (+ optional README.md entry)
#   - Builds versioned release assets into shydata/releases/<VERSION>/...
#   - Commits data/ + docs changes (+ optional tag/push)
#   - Optional: creates GitHub Release + uploads assets via `gh`
#
# Example:
#   ./tools/shydata_assets_datasets.sh \
#     --src /path/to/shybox/dset \
#     --repo /path/to/shydata \
#     --bump patch \
#     --tag --push --gh-release
#
# Or explicit version:
#   ./tools/shydata_create_release.sh --src ... --repo ... --version 0.2.0 --tag --push
#
set -euo pipefail

# --------------------------
# Defaults (edit if you want)
# --------------------------
SRC="/home/fabio/Desktop/Workspace/shybox/dset/"
REPO="/home/fabio/Desktop/Workspace/shydata/"
VERSION="0.0.0"
BUMP=""                 # major|minor|patch
REMOTE="origin"
BRANCH="main"

DO_PUSH="false"
DO_TAG="false"
DO_GH_RELEASE="false"
GH_DRAFT="false"
GH_PRERELEASE="false"

# Flat dataset root (no /<version>)
DATA_ROOT_DIRNAME="data"
DOCS_DIRNAME="docs"

# GitHub policy: committed file must be < 100 MB to avoid GH001
GITHUB_FILE_MAX_MB="100"
GITHUB_FILE_MAX_BYTES=$((GITHUB_FILE_MAX_MB * 1024 * 1024))

# Release assets splitting (keep each asset < 100MB)
ASSET_MAX_MB="100"
ASSET_MAX_BYTES=$((ASSET_MAX_MB * 1024 * 1024))
SPLIT_MB="95"   # each part is 95MB (safe under 100MB)

ARCHIVE_PREFIX="shydata"
VERBOSE="true"

# --------------------------
# Helpers
# --------------------------
die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[shydata] $*"; }
vlog() { [[ "$VERBOSE" == "true" ]] && echo "[shydata:debug] $*" || true; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

is_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
strip_v_prefix() { local t="$1"; echo "${t#v}"; }

bump_semver() {
  local ver="$1" which="$2"
  IFS='.' read -r major minor patch <<<"$ver"
  case "$which" in
    major) major=$((major+1)); minor=0; patch=0 ;;
    minor) minor=$((minor+1)); patch=0 ;;
    patch) patch=$((patch+1)) ;;
    *) die "Invalid bump type: $which (use major|minor|patch)" ;;
  esac
  echo "${major}.${minor}.${patch}"
}

git_latest_semver_tag() {
  local latest
  latest="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' '[0-9]*.[0-9]*.[0-9]*' 2>/dev/null | sort -V | tail -n 1 || true)"
  [[ -n "$latest" ]] && strip_v_prefix "$latest" || true
}

now_iso() { date -Iseconds; }

file_size_bytes() {
  local f="$1"
  if stat -c%s "$f" >/dev/null 2>&1; then
    stat -c%s "$f"
  elif stat -f%z "$f" >/dev/null 2>&1; then
    stat -f%z "$f"
  else
    wc -c <"$f" | tr -d ' '
  fi
}

human_bytes() {
  awk -v b="$1" '
    function human(x) {
      s="B KB MB GB TB PB"; split(s,a," ");
      i=1; while (x>=1024 && i<6) { x/=1024; i++ }
      return sprintf("%.2f %s", x, a[i])
    }
    BEGIN { print human(b) }
  '
}

csv_escape() {
  local s="$1"
  s="${s//\"/\"\"}"
  printf "\"%s\"" "$s"
}

ensure_under_asset_limit() {
  local f="$1"
  local sz
  sz="$(file_size_bytes "$f")"
  if (( sz >= ASSET_MAX_BYTES )); then
    die "Release asset too large (must be <${ASSET_MAX_MB} MB): $f (${sz} bytes). Reduce --split-mb."
  fi
}

# Copy SRC -> DST but SKIP files >= GITHUB_FILE_MAX_BYTES.
# Writes CSV of skipped files with sizes.
copy_tree_skip_oversize() {
  local src_root="$1"
  local dst_root="$2"
  local csv_file="$3"
  local limit_bytes="$4"

  mkdir -p "$dst_root"
  mkdir -p "$(dirname "$csv_file")"
  echo "relative_path,size_bytes,size_human,source_path" > "$csv_file"

  local skipped_count=0
  local copied_count=0

  local src_abs
  src_abs="$(cd "$src_root" && pwd -P)"
  local dst_abs
  dst_abs="$(cd "$dst_root" && pwd -P)"

  vlog "Copy scan source: $src_abs"
  vlog "Copy destination: $dst_abs"
  vlog "Size limit: ${GITHUB_FILE_MAX_MB} MB (< ${limit_bytes} bytes)"

  while IFS= read -r -d '' f; do
    local sz rel dstf hb
    sz="$(file_size_bytes "$f")"
    hb="$(human_bytes "$sz")"
    rel="${f#${src_abs}/}"
    dstf="${dst_abs}/${rel}"

    if (( sz >= limit_bytes )); then
      skipped_count=$((skipped_count+1))
      printf "%s,%s,%s,%s\n" \
        "$(csv_escape "$rel")" \
        "$(csv_escape "$sz")" \
        "$(csv_escape "$hb")" \
        "$(csv_escape "$f")" >> "$csv_file"
    else
      copied_count=$((copied_count+1))
      mkdir -p "$(dirname "$dstf")"
      cp -p "$f" "$dstf"
    fi
  done < <(find "$src_abs" -type f -print0)

  log "Copy complete: copied=${copied_count}, skipped=${skipped_count} (limit < ${GITHUB_FILE_MAX_MB} MB)"
  if (( skipped_count > 0 )); then
    log "WARNING: Skipped ${skipped_count} oversized files (see CSV): $csv_file"
  fi
}

# --------------------------
# CHANGELOG helpers
# --------------------------
init_changelog_if_missing() {
  local changelog_file="$1"
  if [[ ! -f "$changelog_file" ]]; then
    cat > "$changelog_file" <<'EOF'
# Changelog

All notable changes to **shydata** datasets will be documented in this file.

This project follows **Semantic Versioning** for dataset releases: `MAJOR.MINOR.PATCH`.

---

## [Unreleased]

### Added
- N/A

### Changed
- N/A

### Fixed
- N/A

---

EOF
  fi
}

insert_release_in_changelog() {
  local changelog_file="$1"
  local version="$2"
  local run_date="$3"
  local data_path_rel="$4"
  local gh_limit_mb="$5"
  local asset_limit_mb="$6"
  local split_mb="$7"
  local archive_basename="$8"
  local skip_csv_basename="$9"

  if grep -qE "^## \\[${version}\\]" "$changelog_file"; then
    vlog "CHANGELOG already contains an entry for ${version} (not modifying)."
    return 0
  fi

  local entry
  entry="$(cat <<EOF

## [${version}] - ${run_date}

### Added
- Dataset release **${version}** for *shybox*.
- Dataset folder (flat, overwritten each release):
  - \`${data_path_rel}/\`
- Documentation:
  - \`${data_path_rel}/${DOCS_DIRNAME}/provenance.txt\`
  - \`${data_path_rel}/README.md\`

### Release artifacts
- Location:
  - \`./releases/${version}/\`
- Files:
  - \`${archive_basename}.tar.zst.part_*\`
  - \`${archive_basename}.sha256\`
  - \`${archive_basename}.manifest.txt\`

### Notes
- Copy policy enforced (GitHub file limit):
  - Files **≥ ${gh_limit_mb}MB** are skipped during copy into the repo.
- Release policy:
  - Each asset **< ${asset_limit_mb}MB**, split size **${split_mb}MB**.
- Skipped files report:
  - \`./releases/${version}/${skip_csv_basename}\`

---
EOF
)"

  awk -v entry="$entry" '
    BEGIN { seen_unreleased=0; inserted=0 }
    /^## \[Unreleased\]/ { seen_unreleased=1 }
    seen_unreleased && /^---[[:space:]]*$/ && inserted==0 {
      print $0
      printf "%s\n", entry
      inserted=1
      next
    }
    { print $0 }
    END {
      if (inserted==0) {
        printf "\n%s\n", entry
      }
    }
  ' "$changelog_file" > "${changelog_file}.tmp" && mv "${changelog_file}.tmp" "$changelog_file"
}

# --------------------------
# Arg parsing
# --------------------------
usage() {
  cat <<EOF
Usage:
  $0 --src <shybox_dset_path> --repo <shydata_repo_path> [--version X.Y.Z | --bump patch]
     [--remote origin] [--branch main] [--push] [--tag]
     [--gh-release] [--gh-draft] [--gh-prerelease]
     [--split-mb 95] [--verbose]

Flat layout:
  - Copies into:  ./data/        (overwritten each run)
  - Releases into: ./releases/<version>/

Policy:
  - Any file >= ${GITHUB_FILE_MAX_MB} MB is NOT copied into the repo (prevents GH001).
  - Release assets are split so each part < ${ASSET_MAX_MB} MB.

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    --version) VERSION="${2:-}"; shift 2 ;;
    --bump) BUMP="${2:-}"; shift 2 ;;
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --push) DO_PUSH="true"; shift 1 ;;
    --tag) DO_TAG="true"; shift 1 ;;
    --gh-release) DO_GH_RELEASE="true"; shift 1 ;;
    --gh-draft) GH_DRAFT="true"; shift 1 ;;
    --gh-prerelease) GH_PRERELEASE="true"; shift 1 ;;
    --split-mb) SPLIT_MB="${2:-}"; shift 2 ;;
    --verbose) VERBOSE="true"; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
done

[[ -n "$SRC" ]] || { usage; die "--src is required"; }
[[ -n "$REPO" ]] || { usage; die "--repo is required"; }
[[ -d "$SRC" ]] || die "SRC folder not found: $SRC"
[[ -d "$REPO" ]] || die "REPO folder not found: $REPO"

if (( SPLIT_MB >= ASSET_MAX_MB )); then
  die "--split-mb must be < ${ASSET_MAX_MB} (policy: each release asset < ${ASSET_MAX_MB} MB). Suggested: 95"
fi

need_cmd git
need_cmd sha256sum
need_cmd split
need_cmd tar
need_cmd zstd
need_cmd find
need_cmd stat
need_cmd cp
need_cmd awk
need_cmd rm
need_cmd mkdir
need_cmd ls

cd "$REPO"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "REPO is not a git repo: $REPO"

# --------------------------
# Determine version
# --------------------------
if [[ -n "$VERSION" && -n "$BUMP" ]]; then
  die "Use either --version OR --bump, not both."
fi

if [[ -n "$VERSION" && "$VERSION" != "0.0.0" ]]; then
  is_semver "$VERSION" || die "--version must be SemVer X.Y.Z, got: $VERSION"
elif [[ -n "$BUMP" ]]; then
  latest="$(git_latest_semver_tag || true)"
  if [[ -z "$latest" ]]; then
    case "$BUMP" in
      major) VERSION="1.0.0" ;;
      minor) VERSION="0.1.0" ;;
      patch) VERSION="0.0.1" ;;
      *) die "--bump must be major|minor|patch" ;;
    esac
    log "No existing SemVer tags found; starting at $VERSION (bump=$BUMP)."
  else
    VERSION="$(bump_semver "$latest" "$BUMP")"
    log "Latest tag is $latest; bumped ($BUMP) -> $VERSION"
  fi
else
  usage
  die "You must provide --version X.Y.Z OR --bump major|minor|patch"
fi

RUN_DATE="$(now_iso)"

# --------------------------
# Paths (flat data/)
# --------------------------
DATA_DIR="${REPO}/${DATA_ROOT_DIRNAME}"          # <-- flat
DOC_DIR="${DATA_DIR}/${DOCS_DIRNAME}"
REL_DIR="${REPO}/releases/${VERSION}"

ARCHIVE_BASENAME="${ARCHIVE_PREFIX}_${VERSION}"
ARCHIVE_FILE="${REL_DIR}/${ARCHIVE_BASENAME}.tar.zst"
CHECKSUM_FILE="${REL_DIR}/${ARCHIVE_BASENAME}.sha256"
MANIFEST_FILE="${REL_DIR}/${ARCHIVE_BASENAME}.manifest.txt"
DATASET_README="${DATA_DIR}/README.md"

SKIP_COPY_CSV="${REL_DIR}/${ARCHIVE_BASENAME}.copy_skipped_oversize.csv"

TOP_README="${REPO}/README.md"
CHANGELOG_FILE="${REPO}/CHANGELOG.md"

DATA_PATH_REL="./${DATA_ROOT_DIRNAME}"          # <-- flat

# --------------------------
# 1) Copy dataset into repo: data/ (overwrites)
# --------------------------
log "Organizing dataset for version: $VERSION"
mkdir -p "$REL_DIR"

log "Replacing ${DATA_DIR} with new content from: $SRC"
rm -rf "${DATA_DIR:?}/"*
mkdir -p "$DATA_DIR" "$DOC_DIR"


log "Copying (skipping files >= ${GITHUB_FILE_MAX_MB} MB): $SRC -> $DATA_DIR"
copy_tree_skip_oversize "$SRC" "$DATA_DIR" "$SKIP_COPY_CSV" "$GITHUB_FILE_MAX_BYTES"

# provenance
cat > "${DOC_DIR}/provenance.txt" <<EOF
Dataset version: ${VERSION}
Run date: ${RUN_DATE}
Source path: ${SRC}
Destination path: ${DATA_DIR}
Pack script: $(basename "$0")
Git repo: $(git remote get-url "$REMOTE" 2>/dev/null || echo "(unknown remote)")
Git commit (before commit): $(git rev-parse HEAD)
Copy filter: skipped files >= ${GITHUB_FILE_MAX_MB} MB (see: ${SKIP_COPY_CSV})
Layout: data/ is overwritten each release (no per-version folder in-repo)
EOF

# --------------------------
# Update top-level README.md (optional)
# --------------------------
if [[ ! -f "$TOP_README" ]]; then
  cat > "$TOP_README" <<'EOF'
# shydata

Reproducibility datasets for shybox.

## Dataset releases
EOF
fi

# add a line if not present
if ! grep -qE "Dataset release ${VERSION}" "$TOP_README"; then
  {
    echo
    echo "## Dataset releases"
    echo "- Dataset release ${VERSION} (${RUN_DATE}) -> ./data/"
  } >> "$TOP_README"
fi

# --------------------------
# Update CHANGELOG.md
# --------------------------
init_changelog_if_missing "$CHANGELOG_FILE"
insert_release_in_changelog \
  "$CHANGELOG_FILE" \
  "$VERSION" \
  "$RUN_DATE" \
  "$DATA_PATH_REL" \
  "$GITHUB_FILE_MAX_MB" \
  "$ASSET_MAX_MB" \
  "$SPLIT_MB" \
  "$ARCHIVE_BASENAME" \
  "$(basename "$SKIP_COPY_CSV")"

# --------------------------
# 2) Package for GitHub Release (include data/)
# --------------------------
log "Packaging for GitHub Release"

cat > "$DATASET_README" <<EOF
# Shybox dataset ${VERSION} (flat data/)

**Created:** ${RUN_DATE}

## Layout
- In-repo dataset: \`${DATA_PATH_REL}/\` (overwritten each release)
- Provenance: \`${DATA_PATH_REL}/${DOCS_DIRNAME}/provenance.txt\`
- Skipped files report: \`./releases/${VERSION}/$(basename "$SKIP_COPY_CSV")\`

## Download + verify + extract
\`\`\`bash
sha256sum -c ${ARCHIVE_BASENAME}.sha256
cat ${ARCHIVE_BASENAME}.tar.zst.part_* > ${ARCHIVE_BASENAME}.tar.zst
tar --zstd -xf ${ARCHIVE_BASENAME}.tar.zst
\`\`\`

This archive extracts into:
- \`data/...\`
EOF

(
  cd "$REPO"
  tar --zstd -cf "$ARCHIVE_FILE" "${DATA_ROOT_DIRNAME}"
)

log "Splitting archive into ${SPLIT_MB}MB parts (policy: each part < ${ASSET_MAX_MB}MB)"
split -b "${SPLIT_MB}M" "$ARCHIVE_FILE" "${ARCHIVE_FILE}.part_"

parts=( "${ARCHIVE_FILE}.part_"* )
for p in "${parts[@]}"; do
  ensure_under_asset_limit "$p"
done

log "Creating checksums"
sha256sum "${ARCHIVE_FILE}.part_"* > "$CHECKSUM_FILE"

{
  echo "Archive: $(basename "$ARCHIVE_FILE")"
  echo "Version: $VERSION"
  echo "Run date: $RUN_DATE"
  echo "Source: $SRC"
  echo "Extracts to: data/"
  echo "Copy policy: skipped files >= ${GITHUB_FILE_MAX_MB} MB (see CSV: $(basename "$SKIP_COPY_CSV"))"
  echo "Release policy: each asset < ${ASSET_MAX_MB} MB; split size ${SPLIT_MB} MB"
  echo
  echo "Parts:"
  ls -lh "${ARCHIVE_FILE}.part_"* || true
  echo
  echo "SHA256:"
  cat "$CHECKSUM_FILE"
} > "$MANIFEST_FILE"

log "Release artifacts ready in: $REL_DIR"
ls -lh "$REL_DIR" || true

# --------------------------
# 3) Commit (+ optional tag) + optional push
# --------------------------
log "Preparing git commit"
git status --porcelain || true

git add "$TOP_README" "$CHANGELOG_FILE" "data/"

COMMIT_MSG="Update dataset (flat data/) ${VERSION} (${RUN_DATE})"
if git diff --cached --quiet; then
  log "Nothing staged for commit (maybe identical copy)."
else
  git commit -m "$COMMIT_MSG"
  log "Committed: $COMMIT_MSG"
fi

TAG="v${VERSION}"
if [[ "$DO_TAG" == "true" ]]; then
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    log "Tag already exists: $TAG (skipping tag creation)"
  else
    git tag -a "$TAG" -m "Dataset ${VERSION} (flat data/)"
    log "Created tag: $TAG"
  fi
fi

if [[ "$DO_PUSH" == "true" ]]; then
  log "Pushing to ${REMOTE} ${BRANCH}"
  git push "$REMOTE" "$BRANCH"
  if [[ "$DO_TAG" == "true" ]]; then
    git push "$REMOTE" "$TAG"
  fi
  log "Push complete."
else
  log "Push skipped (use --push to push)."
fi

# --------------------------
# 4) Optional: create GitHub Release + upload assets
# --------------------------
if [[ "$DO_GH_RELEASE" == "true" ]]; then
  need_cmd gh

  if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    die "Cannot create GitHub release: tag not found locally ($TAG). Use --tag."
  fi

  if [[ "$DO_PUSH" != "true" ]]; then
    log "NOTE: --gh-release used without --push. If the tag is not on GitHub yet, upload may fail."
  fi

  GH_FLAGS=()
  [[ "$GH_DRAFT" == "true" ]] && GH_FLAGS+=(--draft)
  [[ "$GH_PRERELEASE" == "true" ]] && GH_FLAGS+=(--prerelease)

  log "Creating GitHub Release ($TAG) and uploading assets..."
  gh release create "$TAG" \
    "${GH_FLAGS[@]}" \
    --title "Dataset ${VERSION} (flat data/)" \
    --notes "Dataset ${VERSION} created ${RUN_DATE}. In-repo layout: data/ overwritten each release. See manifest + checksums." \
    "${REL_DIR}/${ARCHIVE_BASENAME}.tar.zst.part_"* \
    "$CHECKSUM_FILE" \
    "$MANIFEST_FILE"
  log "GitHub Release created."
fi

log "Done."
log "In-repo dataset: ${DATA_DIR}"
log "Assets are in: ${REL_DIR}"
echo "Upload (if not using --gh-release):"
echo "  - ${ARCHIVE_BASENAME}.tar.zst.part_*"
echo "  - ${ARCHIVE_BASENAME}.sha256"
echo "  - ${ARCHIVE_BASENAME}.manifest.txt"
echo "Skipped files CSV:"
echo "  - ${SKIP_COPY_CSV}"

