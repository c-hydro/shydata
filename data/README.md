# Shybox dataset 0.0.1 (flat data/)

**Created:** 2026-01-27T10:54:49+01:00

## Layout
- In-repo dataset: `./data/` (overwritten each release)
- Provenance: `./data/docs/provenance.txt`
- Skipped files report: `./releases/0.0.1/shydata_0.0.1.copy_skipped_oversize.csv`

## Download + verify + extract
```bash
sha256sum -c shydata_0.0.1.sha256
cat shydata_0.0.1.tar.zst.part_* > shydata_0.0.1.tar.zst
tar --zstd -xf shydata_0.0.1.tar.zst
```

This archive extracts into:
- `data/...`
