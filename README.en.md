# Plant Comparative Genomics Workflow

**Language:** [English](README.en.md) | [中文](README.zh-CN.md) · [Home](README.md)

Reusable **genome annotation + multi-species comparative genomics** workflow.  
Tracks **scripts, config templates, and docs only** — no raw genomes/RNA/OrthoFinder dumps. Sample IDs only (`T/C/O`).

## Layout

| Path | Role |
|------|------|
| `config/species.csv` | Species → path mapping (edit locally) |
| `lib/common.sh`, `lib/species.py` | Shared helpers |
| `annotation/scripts/` | Genome annotation pipeline |
| `comparative_genomics/scripts/` | Comparative genomics (**canonical**, staged IDs `10_`–`94_`) |
| `comparative_genomics/archive/` | Superseded trial scripts |
| `run_all.sh` / `Makefile` | Orchestration |
| `docs/pipeline.md` | Data-flow diagram |
| `docs/REFACTOR_PLAN.*.md` | Refactor history |

## Quick start

```bash
git clone https://github.com/qi-shen/plant-comparative-genomics-workflow.git
cd plant-comparative-genomics-workflow
cp .project_env.example .project_env
# edit .project_env and config/species.csv
source .project_env

./run_all.sh list
make orthology          # or: ./run_all.sh orthology
```

### Annotation (targets)

```bash
cd annotation
bash scripts/structure_annotation.sh
bash scripts/functional_annotation_main.sh
bash scripts/run_evm_v3.sh
bash scripts/run_pasa_update.sh
```

### Comparative genomics (recommended order)

| Stage | Scripts |
|------|------|
| Orthology | `10_prepare_proteomes.sh` → `11_filter_proteomes.py` → `13_run_orthofinder.sh` → `14_extract_single_copy_genes.sh` |
| Phylogeny | `20_run_phylogeny.sh` |
| WGD / Ks | `30_run_wgd_analysis.sh` → `31_calculate_ks.py` |
| Synteny | `40_prepare_synteny_data.py` → `41_run_jcvi_synteny.sh` |
| Selection | `50_prepare_selection.sh` → `51_run_paml_selection.sh` → `52_run_codeml_batch.sh` |
| CAFE | `60_run_cafe.sh` → `61_parse_cafe_results.py` |
| Figures | `70_run_circos.sh` → `71_`–`79_` R scripts |

Or simply: `./run_all.sh all`

## Sample IDs

| ID | Role |
|------|------|
| T01–T02 | Targets |
| C01–C11 | Comparatives |
| O01–O02 | Outgroups |

Put real filenames only in local `config/species.csv` / `.project_env` (gitignored when private).

## Software (conda preferred)

Annotation: Augustus, GeneMark, GeMoMa, EVM, PASA, RepeatMasker, BUSCO, eggNOG-mapper, DIAMOND  
Comparative: OrthoFinder, MAFFT, IQ-TREE/RAxML, JCVI, CAFE5, PAML, KaKs_Calculator, Circos  
Plotting: R (`ggplot2`, `ggtree`)

## Privacy

Public tree uses codes and neutral paths only. Do not commit real species names or absolute personal paths.

## License

Add a License before broad redistribution; otherwise intended for collaborator workflow reuse.
