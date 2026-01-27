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

## [0.0.1] - 2026-01-27T10:54:49+01:00

### Added
- Dataset release **0.0.1** for *shybox*.
- Dataset folder (flat, overwritten each release):
  - `./data/`
- Documentation:
  - `./data/docs/provenance.txt`
  - `./data/README.md`

### Release artifacts
- Location:
  - `./releases/0.0.1/`
- Files:
  - `shydata_0.0.1.tar.zst.part_*`
  - `shydata_0.0.1.sha256`
  - `shydata_0.0.1.manifest.txt`

### Notes
- Copy policy enforced (GitHub file limit):
  - Files **≥ 100MB** are skipped during copy into the repo.
- Release policy:
  - Each asset **< 100MB**, split size **95MB**.
- Skipped files report:
  - `./releases/0.0.1/shydata_0.0.1.copy_skipped_oversize.csv`

---

