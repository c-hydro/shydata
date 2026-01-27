# SHYDATA — datasets for SHYBOX

This repository provides **versioned datasets** required by the **[shybox](https://github.com/c-hydro/shybox)** package.

It supports:

- **Publishing datasets** as *tagged releases* (for maintainers)
- **Recovering datasets** locally (for users)
- Ensuring **reproducibility** via dataset versioning (`0.0.1`, `0.0.2`, ...)

---

## ✅ Quick links

- **Dataset repository (this one):** https://github.com/c-hydro/shydata
- **SHYBOX code repository:** https://github.com/c-hydro/shybox

---

## Requirements

### System packages

On Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y zstd
```

Optional (for CLI Git helpers):

```bash
sudo apt-get install -y gitsome
```

---

## 📦 Download datasets (recommended way)

### 1. Clone the `shydata` repository

```bash
git clone https://github.com/c-hydro/shydata.git
cd shydata
```

---

### 2. Recover a dataset release

Choose a dataset version (example: `0.0.1`):

```bash
release_version=0.0.1
```

Then run:

```bash
bash tools/shydata_recover_release.sh \
  --version ${release_version} \
  --dest .
```

This will download and unpack the dataset release into the folder you provide as `--dest`.

✅ At the end you should have a local dataset directory containing the files used by **shybox**.

---

## 📁 Suggested dataset directory layout

A typical setup could be:

```text
<your_workspace>/
├── shybox/                # code repo
└── shydata/               # dataset repo
    └── dset/              # recovered dataset folder (example)
```

Example:

```bash
mkdir -p /home/$USER/Workspace/shybox_data
cd /home/$USER/Workspace/shybox_data

git clone https://github.com/c-hydro/shydata.git
cd shydata

release_version=0.0.1
bash tools/shydata_recover_release.sh --version ${release_version} --dest .
```

---

## 🔗 Use datasets in SHYBOX

Now clone `shybox`:

```bash
cd /home/$USER/Workspace
git clone https://github.com/c-hydro/shybox.git
cd shybox
```

To run `shybox`, you must configure the paths so it can locate the recovered datasets.

📌 **Where to set paths?**
- in your `shybox` configuration file(s)
- or via environment variables / CLI options (depending on the workflow)

Please refer to the official SHYBOX documentation:
https://github.com/c-hydro/shybox

---

## 🧪 Dataset versions

Dataset releases are tracked by version tags, for example:

- `0.0.1`
- `0.0.2`
- ...

To list available versions locally:

```bash
git tag -l
```

To fetch tags from remote:

```bash
git fetch --tags
git tag -l
```

---

## 🛠️ Maintainers: create and publish a dataset release

> This section is for developers maintaining the dataset repository.

### 1. Clone the official repo

```bash
git clone git@github.com:c-hydro/shydata.git
cd shydata
```

### 2. Create first commit (if needed)

```bash
echo "# shydata" > README.md
git add README.md
git commit -m "Initialize shydata repository"
git branch -M main
git push -u origin main
```

### 3. Create and publish release

Example:

```bash
release_version=0.0.1

./shydata_create_release.sh \
  --src /home/fabio/Desktop/Workspace/shybox/dset \
  --repo /home/fabio/Desktop/Workspace/shydata \
  --version ${release_version} \
  --tag --push
```

---

## Troubleshooting

### `zstd: command not found`

Install it:

```bash
sudo apt-get install -y zstd
```

---

### Permission issues when extracting

Try extracting into a folder you own, e.g.:

```bash
mkdir -p $HOME/Workspace/shybox_data
bash tools/shydata_recover_release.sh --version 0.0.1 --dest $HOME/Workspace/shybox_data
```

---

## Contacts / Support

For issues or questions:

- Open an issue on `shydata`: https://github.com/c-hydro/shydata/issues
- Open an issue on `shybox`: https://github.com/c-hydro/shybox/issues

## Datasets
- 0.0.2 (2026-01-22T13:21:40+01:00) -> ./0.0.2/

## Datasets
- 0.0.3 (2026-01-26T23:57:57+01:00) -> ./0.0.3/

## Dataset releases
- Dataset release 0.0.4 (2026-01-27T00:45:15+01:00) -> ./data/

## Dataset releases
- Dataset release 0.0.1 (2026-01-27T10:54:49+01:00) -> ./data/
