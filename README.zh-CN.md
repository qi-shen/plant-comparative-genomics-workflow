# 植物比较基因组分析流程

[English](README.md) | [中文](README.zh-CN.md)

通用、**物种脱敏**的植物基因组注释与多物种比较基因组流程模板。

本仓库只跟踪**脚本、配置模板与文档**；基因组、转录组、OrthoFinder 结果等大数据不入库。公开文档仅使用样本编号（`T` / `C` / `O`），不含真实物种名。

> GitHub 默认展示英文主文档 [`README.md`](README.md)；本页为完整中文说明。

---

## 功能概览

- 基因组注释辅助流程（结构 / 功能 / EVM / PASA / BUSCO 等）
- 比较基因组阶段：OrthoFinder → 系统发育 → WGD/Ks → 共线性 → 正选择 → CAFE → 出图
- 配置驱动的物种路径（`config/species.csv`）
- 公共函数库（`lib/common.sh`、`lib/species.py`）
- 一键编排（`run_all.sh` / `Makefile`）

## 目录结构

| 路径 | 作用 |
|------|------|
| `config/species.csv` | 样本编号 → 本地路径映射 |
| `lib/` | Shell / Python 公共函数 |
| `annotation/scripts/` | 基因组注释流程 |
| `comparative_genomics/scripts/` | 比较基因组权威脚本（`10_`–`94_`） |
| `comparative_genomics/archive/` | 已归档的试错 / 监控脚本 |
| `run_all.sh`、`Makefile` | 阶段编排 |
| `docs/pipeline.md` | 数据流说明 |
| `docs/REFACTOR_PLAN.md` | 重构说明 |

## 快速开始

```bash
git clone https://github.com/qi-shen/plant-comparative-genomics-workflow.git
cd plant-comparative-genomics-workflow

cp .project_env.example .project_env
# 1) 编辑 .project_env（项目根目录、线程数、conda 环境等）
# 2) 编辑 config/species.csv（各编号的 pep/cds/gff 路径）
source .project_env

./run_all.sh list
make orthology          # 等同于 ./run_all.sh orthology
```

### 注释（目标基因组）

```bash
bash annotation/scripts/structure_annotation.sh
bash annotation/scripts/functional_annotation_main.sh
bash annotation/scripts/run_evm_v3.sh
bash annotation/scripts/run_pasa_update.sh
```

### 比较基因组

| 阶段 | 入口脚本 |
|------|------|
| 同源 | `10_prepare_proteomes.sh` → `11_filter_proteomes.py` → `13_run_orthofinder.sh` → `14_extract_single_copy_genes.sh` |
| 系统发育 | `20_run_phylogeny.sh` |
| WGD / Ks | `30_run_wgd_analysis.sh` → `31_calculate_ks.py` |
| 共线性 | `40_prepare_synteny_data.py` → `41_run_jcvi_synteny.sh` |
| 正选择 | `50_prepare_selection.sh` → `51_run_paml_selection.sh` → `52_run_codeml_batch.sh` |
| CAFE | `60_run_cafe.sh` → `61_parse_cafe_results.py` |
| 出图 | `70_run_circos.sh` → `71_`–`79_`（R） |

一次性跑完全流程：

```bash
./run_all.sh all
# 或：make all
```

## 样本编号约定

| 编号 | 角色 |
|------|------|
| `T01`–`T02` | 目标样本 |
| `C01`–`C11` | 比较物种 |
| `O01`–`O02` | 外群 |

真实文件名与绝对路径只写在本地 `config/species.csv` / `.project_env`，不要提交到公开仓库。

## 软件依赖

优先使用 **conda** 环境。

| 类别 | 工具 |
|------|------|
| 注释 | Augustus, GeneMark, GeMoMa, EVM, PASA, RepeatMasker/RepeatModeler, BUSCO, eggNOG-mapper, DIAMOND |
| 比较 | OrthoFinder, MAFFT, IQ-TREE / RAxML, JCVI, CAFE5, PAML (CodeML), KaKs_Calculator, Circos |
| 绘图 | R（`ggplot2`、`ggtree` 等） |

编码与绘图规范见 [`old_reults/AGENTS.zh-CN.md`](old_reults/AGENTS.zh-CN.md)。

## 相关文档

- [English README](README.md)
- [流程数据流](docs/pipeline.md)
- [重构计划](docs/REFACTOR_PLAN.zh-CN.md)
- [命令速查](CLAUDE.zh-CN.md)
- [初始化指南](old_reults/README_INIT.zh-CN.md)

## 隐私

公开仓库已做脱敏。数据与真实物种对照表请与本流程仓库分开传输。

## License

尚未单独声明许可证，默认供合作方复用流程；公开分发前请补全 `LICENSE`。
