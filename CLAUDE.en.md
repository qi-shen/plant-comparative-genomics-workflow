# CLAUDE.md (English)

**Language:** [English](CLAUDE.en.md) | [中文](CLAUDE.zh-CN.md)

Workflow notes. Sample IDs (T/C/O) are template placeholders mapped to real data in config/species.csv.

## Overview

- Targets: T01, T02 · Comparatives: C01–C11 · Outgroups: O01–O02
- Flow: annotation → OrthoFinder → phylogeny → WGD/Ks → synteny → selection → CAFE → figures

## Layout

```text
project_root/
├── config/species.csv
├── lib/common.sh, species.py
├── annotation/scripts/
├── comparative_genomics/
│   ├── scripts/          # canonical 10_–94_
│   └── archive/          # legacy trials
├── run_all.sh, Makefile
└── .project_env          # local, gitignored
```

## Commands

```bash
source .project_env
./run_all.sh orthology
./run_all.sh phylogeny
./run_all.sh wgd
./run_all.sh synteny
./run_all.sh selection
./run_all.sh cafe
./run_all.sh figures
# or
make all
```

Annotation:

```bash
bash annotation/scripts/structure_annotation.sh
bash annotation/scripts/functional_annotation_main.sh
bash annotation/scripts/run_evm_v3.sh
bash annotation/scripts/run_pasa_update.sh
```

## Conventions

- Prefer conda; multi-core; background + progress logs
- Prefer R plots; no grid; no top/right spines
- Palette: `old_reults/AGENTS.en.md`
- Species paths only in `config/species.csv`
