# 🗃️ SHYDATA – Versioned Datasets for SHYBOX

[![License](https://img.shields.io/badge/license-EUPL--1.2-blue.svg)](LICENSE)
[![Data Releases](https://img.shields.io/github/v/release/c-hydro/shydata)](https://github.com/c-hydro/shydata/releases)

**SHYDATA** is the official dataset repository for the **[SHYBOX](https://github.com/c-hydro/shybox)** hydrological processing framework.

It provides **versioned, immutable, and reproducible datasets** used by SHYBOX workflows in both **operational** and **research** contexts.

---

## 🔎 Overview

SHYDATA centralizes all environmental and hydrological datasets required by SHYBOX.

Key concepts:

- Datasets are distributed **only via GitHub releases**
- Each release represents a **fixed dataset snapshot**
- Dataset versions are explicitly referenced by SHYBOX configurations
- Repository history remains lightweight (no large binary data)

This approach guarantees **traceability, reproducibility, and controlled updates**.

---

## 🎯 Objectives

The main objectives of SHYDATA are to:

- Provide centralized datasets for SHYBOX workflows
- Ensure dataset versioning and long-term reproducibility
- Enable controlled publication of dataset updates
- Decouple dataset management from processing logic

---

## 📦 Dataset Philosophy

- ❌ No datasets stored directly in the Git repository history
- ✅ All datasets published as **tagged releases**
- ✅ Each release corresponds to a **single dataset version**
- ✅ Releases are immutable once published

---

## 📂 Repository Structure

```text
shydata/
├── data/          # Recovered dataset content (created locally)
├── tools/         # Dataset recovery and release tools
├── docs/          # Dataset documentation
└── README.md
```

---

## 🚀 Dataset Recovery (Users)

```bash
git clone https://github.com/c-hydro/shydata.git
cd shydata

release_version=0.0.4
bash tools/shydata_recover_release.sh --version ${release_version} --dest .
```

---

## 📁 Recommended Workspace Layout

```text
<workspace>/
├── shybox/
└── shydata/
    └── data/
```

---

## 🔗 Integration with SHYBOX

SHYDATA is designed to be used **exclusively together with SHYBOX**.

Refer to SHYBOX documentation:
https://github.com/c-hydro/shybox

---

## ⚙️ Requirements

```bash
sudo apt-get install -y zstd
```

---

## 📜 License

This project is licensed under the  
**European Union Public License v1.2 (EUPL-1.2)**

---

## 🔗 Related Repositories

- **SHYBOX** – https://github.com/c-hydro/shybox
- **SHYDATA** – https://github.com/c-hydro/shydata

## Dataset releases
- Dataset release 0.0.2 (2026-01-30T10:56:04+01:00) -> ./data/

## Dataset releases
- Dataset release 0.0.3 (2026-02-03T18:04:41+01:00) -> ./data/
