# Shybox dataset 0.0.3 (flat data/)

**Created:** 2026-02-03T18:56:18+01:00

## Layout
- In-repo dataset: `./data/` (overwritten each release)
- Provenance: `./data/docs/provenance.txt`
- Skipped files report: `./releases/0.0.3/shydata_0.0.3.copy_skipped_oversize.csv`

## Download + verify + extract
```bash
sha256sum -c shydata_0.0.3.sha256
cat shydata_0.0.3.tar.zst.part_* > shydata_0.0.3.tar.zst
tar --zstd -xf shydata_0.0.3.tar.zst
```

This archive extracts into:
- `data/...`
