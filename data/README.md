# Shybox dataset 0.0.2 (flat data/)

**Created:** 2026-01-30T10:56:04+01:00

## Layout
- In-repo dataset: `./data/` (overwritten each release)
- Provenance: `./data/docs/provenance.txt`
- Skipped files report: `./releases/0.0.2/shydata_0.0.2.copy_skipped_oversize.csv`

## Download + verify + extract
```bash
sha256sum -c shydata_0.0.2.sha256
cat shydata_0.0.2.tar.zst.part_* > shydata_0.0.2.tar.zst
tar --zstd -xf shydata_0.0.2.tar.zst
```

This archive extracts into:
- `data/...`
