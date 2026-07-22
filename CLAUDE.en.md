# CLAUDE.md (English)

**Language:** [English](CLAUDE.en.md) | [中文](CLAUDE.zh-CN.md)

Workflow notes for this repository (anonymized: no real species names).

## Overview

Template for plant genome annotation and multi-species comparative genomics.

- **Targets:** T01, T02
- **Comparatives:** C01–C11
- **Outgroups:** O01–O02
- **Pipeline:** annotation → OrthoFinder → phylogeny → WGD/Ks → synteny → selection → CAFE → visualization

## Layout

```text
project_root/
├── old_reults/
│   ├── annotation/              # annotation outputs (local; not tracked)
│   ├── comparative_genomics/    # earlier comparative-genomics tree
│   ├── scripts/                 # annotation scripts
│   ├── results/                 # species data (not tracked)
│   ├── rna_rawdata/             # RNA-seq (not tracked)
│   └── logs/
├── comparative_genomics/        # main comparative-genomics directory
│   ├── scripts/
│   ├── 01_proteomes/
│   ├── 02_orthofinder_results*/
│   ├── 03_phylogeny/
│   ├── 04_wgd/
│   ├── 05_synteny/
│   ├── 06_selection/
│   ├── 07_cafe/
│   ├── 08_circos/
│   └── DELIVERY_PACKAGE/
├── new_anno/                    # final annotation delivery (not tracked)
└── .project_env                 # local env (not tracked)
```

## Common commands

### Init

```bash
bash old_reults/init_project.sh
source .project_env
```

### Environment (`.project_env`)

| Variable | Meaning |
|------|------|
| `PROJECT_ROOT` | Project root |
| `T01_GENOME` | Target T01 genome |
| `T02_GENOME` | Target T02 genome |
| `RESULTS_DIR` | Species data directory |
| `COMPARATIVE_DIR` | Comparative genomics directory |
| `RNA_DIR` | RNA-seq directory |

### Annotation

```bash
bash old_reults/scripts/structure_annotation.sh
bash old_reults/scripts/functional_annotation_main.sh
bash old_reults/scripts/run_evm_v3.sh
bash old_reults/scripts/run_pasa_update.sh
```

### Comparative genomics

```bash
cd comparative_genomics
bash scripts/01_prepare_proteomes.sh
bash scripts/03_run_orthofinder.sh
bash scripts/12_run_phylogeny.sh
bash scripts/05_run_wgd_analysis.sh
bash scripts/06_run_jcvi_synteny.sh
bash scripts/18_run_paml_selection.sh
bash scripts/22_run_codeml_batch.sh
bash scripts/35_run_kaks_calculator.sh
bash scripts/13_run_cafe_v2.sh
```

## Sample IDs

- **T01–T02:** targets
- **C01–C11:** comparatives
- **O01–O02:** outgroups

Real names/paths stay in local `species_list.csv` (gitignored). Public repo uses IDs only.

## Conventions

- Prefer conda-packaged tools
- Prefer multi-core / background jobs with progress logs
- Prefer R for figures; no grid; no top/right spines
- Palette: see `old_reults/AGENTS.en.md`

## Pipeline overview

1. Repeats → structure → function → EVM/PASA
2. Proteomes → OrthoFinder
3. Single-copy genes → phylogeny
4. WGD (Ks) → JCVI synteny
5. PAML/CodeML + KaKs
6. CAFE expansion/contraction → Circos / R figures
