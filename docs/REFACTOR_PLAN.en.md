# Refactor Plan

**Language:** [English](REFACTOR_PLAN.en.md) | [中文](REFACTOR_PLAN.zh-CN.md)

> Baseline tag: `pre-refactor` (Phase 0 checkpoint)  
> Inventories: `docs/SCRIPT_INVENTORY.csv`, `SCRIPT_TREE_DIFF.csv`, `SCRIPT_DECISIONS.csv`

---

## 1. Diagnosis (verified by repo scan)

### 1.1 Version sprawl / trial scripts committed as deliverables

Many `_v2 / _v3 / fix_ / final_ / improved_ / simple_` variants. Inventory: **57** version-like filenames; Ks/KaKs work is especially fragmented (scripts 10, 24, 33–46, …).

### 1.2 Numeric prefixes no longer encode order

IDs jump `13 → 30 → 50` then `60/61/90/92/93/95/100/101/110–116`. Newcomers cannot tell the recommended entrypoints from numbering alone.

### 1.3 Two comparative_genomics trees have diverged (high risk)

| Status | Count |
|------|------|
| `identical` | **52** |
| `DIVERGED` | **10** |
| only in `comparative_genomics/` | **17** |
| only in `old_reults/...` | **0** |

**Diverged files (must merge in Phase 1):**

`01_prepare_proteomes.sh`, `03_run_orthofinder.sh`, `04_prepare_synteny_data.sh`, `05_run_wgd_analysis.sh`, `06_run_jcvi_synteny.sh`, `11_run_wgd_ks.sh`, `12_run_phylogeny.sh`, `13_run_cafe_v2.sh`, `16_prepare_selection_analysis.sh`, `52_create_final_summary.py`

Canonical tree: `comparative_genomics/scripts/` (newer; includes figure scripts).

### 1.4 Typo directory `old_reults` with overloaded roles

Holds archived scripts, annotation pipeline, and roots for results/logs/tools. `.project_env` is wired to the misspelling.

### 1.5 Hard-coded paths

**200** scripts contain `/home/` or `/path/to/`. Species maps are hard-coded instead of reading `species_list.example.csv`.

### 1.6 Privacy claims vs content mismatch

Docs claim T/C/O-only IDs, but **132** scripts still hit `T01/T02/目标种` or identifiable filenames. Must be closed before treating the public story as accurate.

### 1.7 No config-driven design / shared helpers

No shared `config/` consumption; no `lib/common.sh`; boilerplate and species tables duplicated.

---

## 2. Target shape

| Direction | Action |
|------|------|
| Single source of truth | Keep `comparative_genomics/` only; remove `old_reults/comparative_genomics/` after merges |
| Config-driven | `config/species.csv` + `.project_env`; no in-script species path maps |
| Archive trials | One winner per function; history in `archive/` (or git) |
| Renumber | `00_setup / 10_orthology / 20_phylogeny / 30_wgd_ks / 40_synteny / 50_selection / 60_cafe / 70_figures` |
| Shared lib | `lib/common.sh` for strict mode, logging, env, conda, path checks |
| Orchestration | `run_all.sh` or `Makefile` |
| Naming | Fix/split `old_reults` into clear modules (e.g. `annotation/`) |
| Privacy close-out | Repo-wide grep/replace; align README claims |

---

## 3. Phased plan

Rule: **clean first, restructure second**; one commit per phase; always rollback-able.

### Phase 0 — Freeze & inventory ✅

- [x] Tag `pre-refactor`
- [x] Inventory CSVs
- [x] This plan

### Phase 1 — Eliminate duplicate trees ✅

- [x] Treat `comparative_genomics/` as canonical
- [x] Remove `old_reults/comparative_genomics/`

### Phase 2 — Converge versions ✅

- [x] Winners renamed to staged IDs
- [x] Trials → `comparative_genomics/archive/legacy/`
- [x] Monitors → `archive/ops/`
- [x] Annotation scripts → `annotation/scripts/`

### Phase 3 — Config + shared library ✅

- [x] `config/species.csv`
- [x] `lib/common.sh` + `lib/species.py`
- [x] Config-driven `10_` / `11_` / `13_` entrypoints

### Phase 4 — Renumber + orchestration ✅

- [x] Stage prefixes `10_`–`94_`
- [x] `run_all.sh` + `Makefile`
- [x] Bilingual docs updated

### Phase 5 — Privacy + docs close-out ✅

- [x] Active-tree anonymization (archive keeps historical variants)
- [x] `docs/pipeline.md`

---

## 4. Rollback

```bash
git checkout pre-refactor
```
