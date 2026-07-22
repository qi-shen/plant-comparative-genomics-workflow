# CLAUDE.md

面向本仓库的流程说明（已脱敏：不含真实物种名）。

## 项目概述

植物基因组注释与多物种比较基因组分析流程模板。

- **目标样本**: T01、T02
- **比较物种**: C01–C11
- **外群**: O01–O02
- **流程状态**: 注释 → OrthoFinder → 系统发育 → WGD/Ks → 共线性 → 选择压力 → CAFE → 可视化

## 目录结构

```text
project_root/
├── old_reults/
│   ├── annotation/              # 基因组注释结果（本地数据，不入库）
│   ├── comparative_genomics/    # 早期比较基因组目录
│   ├── scripts/                 # 注释流程脚本
│   ├── results/                 # 物种原始数据（不入库）
│   ├── rna_rawdata/             # 转录组（不入库）
│   └── logs/
├── comparative_genomics/        # 比较基因组主目录
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
├── new_anno/                    # 最终注释输出（不入库）
└── .project_env                 # 本机环境变量（不入库）
```

## 常用命令

### 初始化

```bash
bash old_reults/init_project.sh
source .project_env
```

### 环境变量（`.project_env`）

| 变量 | 说明 |
|------|------|
| `PROJECT_ROOT` | 项目根目录 |
| `T01_GENOME` | 目标样本 T01 基因组 |
| `T02_GENOME` | 目标样本 T02 基因组 |
| `RESULTS_DIR` | 物种数据目录 |
| `COMPARATIVE_DIR` | 比较基因组目录 |
| `RNA_DIR` | 转录组数据目录 |

### 注释流程

```bash
bash old_reults/scripts/structure_annotation.sh
bash old_reults/scripts/functional_annotation_main.sh
bash old_reults/scripts/run_evm_v3.sh
bash old_reults/scripts/run_pasa_update.sh
```

### 比较基因组

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

## 样本编号

- **T01–T02**: 目标样本
- **C01–C11**: 比较物种
- **O01–O02**: 外群

真实种名与路径仅保存在本地 `species_list.csv`（已 gitignore），公开仓库只用编号。

## 编码规范

- 优先 conda 环境中的软件与包
- 脚本优先多核并行、后台运行并输出进度
- 绘图优先 R；无背景网格；无上方/右方边框
- 配色见 `old_reults/AGENTS.md`

## 分析流程概览

1. 重复序列注释 → 结构注释 → 功能注释 → EVM/PASA
2. 蛋白质组准备 → OrthoFinder
3. 单拷贝基因 → 系统发育树
4. WGD（Ks）→ JCVI 共线性
5. PAML/CodeML + KaKs
6. CAFE 扩张/收缩 → Circos / R 出图
