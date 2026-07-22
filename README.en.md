# Plant Comparative Genomics Workflow

**Language:** [English](README.en.md) | [中文](README.zh-CN.md) · [Home](README.md)

A reusable **genome annotation + multi-species comparative genomics** workflow template.  
This repository publishes **pipeline scripts and docs only** — no real species names, Latin names, or raw sequencing data.

By default only **scripts, documentation, and config templates** are tracked. Genomes, RNA-seq, OrthoFinder outputs, and other large artifacts are gitignored.

## What is included

| Path | Contents |
|------|----------|
| `old_reults/scripts/` | Genome annotation (structure / function / EVM / PASA / BUSCO, etc.) |
| `comparative_genomics/scripts/` | Comparative genomics main pipeline (recommended; includes R figure scripts) |
| `old_reults/comparative_genomics/scripts/` | Earlier comparative-genomics script snapshot |
| `old_reults/species_list.example.csv` | Sample-ID placeholder table (copy and fill local paths) |
| `CLAUDE.en.md` / `old_reults/AGENTS.en.md` | Workflow notes and plotting conventions |
| `.project_env.example` | Environment-variable template |

## Quick start

### 1. Clone

```bash
git clone https://github.com/qi-shen/plant-comparative-genomics-workflow.git
cd plant-comparative-genomics-workflow
```

### 2. Prepare data directories (not in Git)

```bash
cp old_reults/species_list.example.csv old_reults/species_list.csv
# Edit species_list.csv with your own paths; do not commit real species names
```

Suggested layout:

```text
project_root/
├── old_reults/
│   ├── results/                 # genomes / annotations / proteins
│   ├── rna_rawdata/             # RNA-seq (optional)
│   ├── scripts/
│   ├── annotation/
│   └── logs/
├── comparative_genomics/
│   ├── scripts/
│   ├── 01_proteomes/            # created at runtime
│   ├── 02_orthofinder_results*/ # created at runtime
│   └── ...
└── new_anno/                    # final annotation delivery (optional)
```

### 3. Configure environment

```bash
cp .project_env.example .project_env
# Edit PROJECT_ROOT and target genome paths
source .project_env
```

Or:

```bash
bash old_reults/init_project.sh
source .project_env
```

### 4. Software (prefer conda)

- Annotation: Augustus, GeneMark, GeMoMa, EVM, PASA, RepeatMasker/RepeatModeler, BUSCO, eggNOG-mapper, DIAMOND
- Comparative genomics: OrthoFinder, MAFFT, IQ-TREE / RAxML, JCVI, CAFE5, PAML (CodeML), KaKs_Calculator, Circos
- Plotting: R (`ggplot2`, `ggtree`, …)

See `old_reults/AGENTS.en.md` for conventions.

## Recommended run order

### A. Genome annotation (targets)

```bash
cd old_reults
bash scripts/structure_annotation.sh
bash scripts/functional_annotation_main.sh
bash scripts/run_evm_v3.sh
bash scripts/run_pasa_update.sh
```

### B. Comparative genomics

```bash
cd comparative_genomics
bash scripts/01_prepare_proteomes.sh
bash scripts/03_run_orthofinder.sh
bash scripts/14_extract_single_copy_genes.sh
bash scripts/12_run_phylogeny.sh
bash scripts/05_run_wgd_analysis.sh
bash scripts/06_run_jcvi_synteny.sh
bash scripts/18_run_paml_selection.sh
bash scripts/22_run_codeml_batch.sh
bash scripts/13_run_cafe_v2.sh
```

When adapting to your data, edit first:

1. `.project_env` / `species_list.csv`
2. Input mapping in `01_prepare_proteomes.sh`
3. Hard-coded sample prefixes in downstream scripts (defaults: T01/T02)

## Sample ID convention (placeholders)

| ID | Role |
|------|------|
| T01–T02 | Target samples |
| C01–C11 | Comparative species |
| O01–O02 | Outgroups |

In the public repo, keep only IDs and relative paths — **do not** commit Chinese names, Latin names, or identifiable directory labels.

## Privacy

- Keep real species maps, absolute paths, and project plans local; do not push them.
- `.project_env` and `species_list.csv` (if they contain private info) are gitignored.
- Share this workflow repo; transfer data/results separately.

## Related docs

- [docs/REFACTOR_PLAN.en.md](docs/REFACTOR_PLAN.en.md) — refactor diagnosis & phased plan
- [CLAUDE.en.md](CLAUDE.en.md) — command cheat sheet
- [old_reults/README_INIT.en.md](old_reults/README_INIT.en.md) — initialization
- [old_reults/AGENTS.en.md](old_reults/AGENTS.en.md) — coding & plotting rules

## License

Unless a license file is added, intended for internal workflow reuse among collaborators. Add a License before broad redistribution.
