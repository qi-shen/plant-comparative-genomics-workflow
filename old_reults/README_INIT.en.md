# Project initialization guide

**Language:** [English](README_INIT.en.md) | [中文](README_INIT.zh-CN.md)

## Quick start

```bash
cd /path/to/project_root
bash old_reults/init_project.sh
cp .project_env.example .project_env   # if not generated
# edit .project_env
source .project_env
```

Initialization checks conda and key directories, then writes/updates a local env file (not tracked).

## Environment variables

| Name | Meaning |
|--------|------|
| `PROJECT_ROOT` | Project root |
| `RESULTS_DIR` | Species data directory |
| `SCRIPTS_DIR` | Annotation scripts |
| `ANNOTATION_DIR` | Annotation directory |
| `COMPARATIVE_DIR` | Comparative genomics directory |
| `LOGS_DIR` | Logs |
| `TOOLS_DIR` | Tools |
| `RNA_DIR` | RNA-seq |
| `T01_GENOME` / `T02_GENOME` | Target genomes |

## Privacy

- Public repo keeps workflow + IDs (T/C/O) only.
- Put real names, Latin names, and identifiable paths in local `species_list.csv` / `.project_env`; do not commit them.
