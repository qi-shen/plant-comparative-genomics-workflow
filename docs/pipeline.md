# Pipeline data flow / 流程数据流

**Language / 语言:** English below · 中文见后半部分

## English

```text
config/species.csv ──► 10_prepare_proteomes ──► 01_proteomes/*.fa
                              │
                              ▼
                       11_filter_proteomes ──► 01_proteomes/filtered/
                              │
                              ▼
                       13_run_orthofinder ──► 02_orthofinder_results/Results_*/
                         │            │
                         ▼            ▼
              14_extract_single_copy   gene counts / trees
                         │
                         ▼
                  20_run_phylogeny ──► 03_phylogeny/
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   30_run_wgd     40_prepare_synteny   50_prepare_selection
   31_calculate_ks  41_run_jcvi        51/52/53 PAML-CodeML
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                  60_run_cafe (+61/62 parsers)
                         │
                         ▼
                  70_run_circos + 71–79 R figures
                         │
                         ▼
                  90–94 summaries / final report
```

Orchestration: `./run_all.sh [orthology|phylogeny|wgd|synteny|selection|cafe|figures|all]` or `make <stage>`.

Shared helpers: `lib/common.sh`, `lib/species.py`.  
Species paths: **only** `config/species.csv` (plus local `.project_env`).

## 中文

```text
config/species.csv → 准备蛋白组 → 过滤 → OrthoFinder
        → 单拷贝 / 系统发育
        → WGD·Ks / 共线性 / 正选择
        → CAFE → Circos / R 出图 → 汇总报告
```

编排入口：`./run_all.sh` 或 `make`。  
物种路径只维护在 `config/species.csv`，脚本禁止再写死映射表。
