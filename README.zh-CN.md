# 植物比较基因组分析流程（可复用模板）

**语言：** [English](README.en.md) | [中文](README.zh-CN.md) · [首页](README.md)

通用的**基因组注释 + 多物种比较基因组**流程。只跟踪**脚本、配置模板与文档**；不含原始基因组/转录组/OrthoFinder 大数据。公开内容仅使用样本编号（`T/C/O`）。

## 目录结构

| 路径 | 作用 |
|------|------|
| `config/species.csv` | 物种→路径映射（本地修改） |
| `lib/common.sh`, `lib/species.py` | 公共函数库 |
| `annotation/scripts/` | 基因组注释流程 |
| `comparative_genomics/scripts/` | 比较基因组（**唯一权威**，阶段编号 `10_`–`94_`） |
| `comparative_genomics/archive/` | 已收敛的历史试错脚本 |
| `run_all.sh` / `Makefile` | 一键编排 |
| `docs/pipeline.md` | 数据流图 |
| `docs/REFACTOR_PLAN.*.md` | 重构说明 |

## 快速开始

```bash
git clone https://github.com/qi-shen/plant-comparative-genomics-workflow.git
cd plant-comparative-genomics-workflow
cp .project_env.example .project_env
# 编辑 .project_env 与 config/species.csv
source .project_env

./run_all.sh list
make orthology          # 或 ./run_all.sh orthology
```

### 注释（目标种）

```bash
cd annotation
bash scripts/structure_annotation.sh
bash scripts/functional_annotation_main.sh
bash scripts/run_evm_v3.sh
bash scripts/run_pasa_update.sh
```

### 比较基因组（推荐顺序）

| 阶段 | 脚本 |
|------|------|
| 同源 | `10_prepare_proteomes.sh` → `11_filter_proteomes.py` → `13_run_orthofinder.sh` → `14_extract_single_copy_genes.sh` |
| 系统发育 | `20_run_phylogeny.sh` |
| WGD / Ks | `30_run_wgd_analysis.sh` → `31_calculate_ks.py` |
| 共线性 | `40_prepare_synteny_data.py` → `41_run_jcvi_synteny.sh` |
| 正选择 | `50_prepare_selection.sh` → `51_run_paml_selection.sh` → `52_run_codeml_batch.sh` |
| CAFE | `60_run_cafe.sh` → `61_parse_cafe_results.py` |
| 出图 | `70_run_circos.sh` → `71_`–`79_` R 脚本 |

或直接：`./run_all.sh all`

## 样本编号

| 编号 | 角色 |
|------|------|
| T01–T02 | 目标样本 |
| C01–C11 | 比较物种 |
| O01–O02 | 外群 |

真实文件名只写在本地 `config/species.csv` / `.project_env`。

## 软件依赖（优先 conda）

注释：Augustus, GeneMark, GeMoMa, EVM, PASA, RepeatMasker, BUSCO, eggNOG-mapper, DIAMOND  
比较：OrthoFinder, MAFFT, IQ-TREE/RAxML, JCVI, CAFE5, PAML, KaKs_Calculator, Circos  
绘图：R（ggplot2, ggtree）

## 隐私

公开仓库只用编号与中性路径；勿提交真实种名或本机绝对路径。

## License

公开分发前请补全 License；默认供合作方复用流程。
