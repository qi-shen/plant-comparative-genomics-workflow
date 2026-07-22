# Plant Comparative Genomics Workflow

[English](README.md) | [中文](README.zh-CN.md)

A reusable, **species-agnostic** pipeline for plant genome annotation and multi-species comparative genomics.

This repository tracks **scripts, configuration templates, and documentation only**. Genomes, RNA-seq, OrthoFinder outputs, and other large artifacts are gitignored. Public docs use sample codes (`T` / `C` / `O`) instead of real species names.

---

## Features

- Genome annotation helpers (structure / function / EVM / PASA / BUSCO, …)
- Comparative genomics stages: OrthoFinder → phylogeny → WGD/Ks → synteny → selection → CAFE → figures
- Config-driven species mapping (`config/species.csv`)
- Shared helpers (`lib/common.sh`, `lib/species.py`)
- One-command orchestration (`run_all.sh` / `Makefile`)

## Repository layout

| Path | Role |
|------|------|
| `config/species.csv` | Sample ID → local path mapping |
| `lib/` | Shared shell/Python helpers |
| `annotation/scripts/` | Annotation pipeline |
| `comparative_genomics/scripts/` | Canonical comparative scripts (`10_`–`94_`) |
| `comparative_genomics/archive/` | Superseded trial / ops scripts |
| `run_all.sh`, `Makefile` | Stage orchestration |
| `docs/pipeline.md` | Data-flow overview |
| `docs/REFACTOR_PLAN.md` | Refactor notes |

## Quick start

```bash
git clone https://github.com/qi-shen/plant-comparative-genomics-workflow.git
cd plant-comparative-genomics-workflow

cp .project_env.example .project_env
# 1) Edit .project_env  (PROJECT_ROOT, THREADS, conda env, …)
# 2) Edit config/species.csv (pep/cds/gff paths for each ID)
source .project_env

./run_all.sh list
make orthology          # same as: ./run_all.sh orthology
```

### Annotation (target genomes)

```bash
bash annotation/scripts/structure_annotation.sh
bash annotation/scripts/functional_annotation_main.sh
bash annotation/scripts/run_evm_v3.sh
bash annotation/scripts/run_pasa_update.sh
```

### Comparative genomics

| Stage | Entry scripts |
|------|------|
| Orthology | `10_prepare_proteomes.sh` → `11_filter_proteomes.py` → `13_run_orthofinder.sh` → `14_extract_single_copy_genes.sh` |
| Phylogeny | `20_run_phylogeny.sh` |
| WGD / Ks | `30_run_wgd_analysis.sh` → `31_calculate_ks.py` |
| Synteny | `40_prepare_synteny_data.py` → `41_run_jcvi_synteny.sh` |
| Selection | `50_prepare_selection.sh` → `51_run_paml_selection.sh` → `52_run_codeml_batch.sh` |
| CAFE | `60_run_cafe.sh` → `61_parse_cafe_results.py` |
| Figures | `70_run_circos.sh` → `71_`–`79_` (R) |

Run everything:

```bash
./run_all.sh all
# or: make all
```

## Sample ID convention

| ID | Role |
|------|------|
| `T01`–`T02` | Target samples |
| `C01`–`C11` | Comparative species |
| `O01`–`O02` | Outgroups |

Keep real filenames and absolute paths in local `config/species.csv` / `.project_env` only. Do not commit identifiable names to the public tree.

## Dependencies

Prefer **conda** environments.

| Area | Tools |
|------|------|
| Annotation | Augustus, GeneMark, GeMoMa, EVM, PASA, RepeatMasker/RepeatModeler, BUSCO, eggNOG-mapper, DIAMOND |
| Comparative | OrthoFinder, MAFFT, IQ-TREE / RAxML, JCVI, CAFE5, PAML (CodeML), KaKs_Calculator, Circos |
| Plotting | R (`ggplot2`, `ggtree`, …) |

Coding / figure style notes: [`old_reults/AGENTS.en.md`](old_reults/AGENTS.en.md).

## Documentation

- [Chinese README](README.zh-CN.md)
- [Pipeline data flow](docs/pipeline.md)
- [Refactor plan](docs/REFACTOR_PLAN.en.md)
- [Agent / command notes](CLAUDE.en.md)
- [Init guide](old_reults/README_INIT.en.md)

## Privacy

The public repository is intentionally anonymized. Share data and private species maps separately from this workflow repo.

## License

No license file yet — intended for collaborator workflow reuse. Add a `LICENSE` before broad redistribution.
