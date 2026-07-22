# 植物比较基因组分析流程（可复用模板）

通用的**基因组注释 + 多物种比较基因组**流程仓库。只公开流程与脚本骨架，不包含真实物种名、拉丁名或原始数据。

本仓库默认只跟踪**脚本、文档与配置模板**；基因组、转录组、OrthoFinder 结果等大数据不入库。

## 仓库包含什么

| 路径 | 内容 |
|------|------|
| `old_reults/scripts/` | 基因组注释流程（结构注释 / 功能注释 / EVM / PASA / BUSCO 等） |
| `comparative_genomics/scripts/` | 比较基因组主流程（推荐使用，含出图 R 脚本） |
| `old_reults/comparative_genomics/scripts/` | 比较基因组早期脚本备份 |
| `old_reults/species_list.example.csv` | 物种编号占位表（自行复制并填本地路径） |
| `CLAUDE.md` / `old_reults/AGENTS.md` | 流程约定与绘图规范 |
| `.project_env.example` | 环境变量模板 |

## 快速开始

### 1. 克隆

```bash
git clone <your-repo-url> comparative-genomics-workflow
cd comparative-genomics-workflow
```

### 2. 准备数据目录（不进 Git）

```bash
cp old_reults/species_list.example.csv old_reults/species_list.csv
# 编辑 species_list.csv：只写你自己的目录路径，勿把真实种名提交回公开仓库
```

建议结构：

```text
project_root/
├── old_reults/
│   ├── results/                 # 各物种基因组 / 注释 / 蛋白
│   ├── rna_rawdata/             # 转录组原始数据（可选）
│   ├── scripts/
│   ├── annotation/
│   └── logs/
├── comparative_genomics/
│   ├── scripts/
│   ├── 01_proteomes/            # 运行后生成
│   ├── 02_orthofinder_results*/ # 运行后生成
│   └── ...
└── new_anno/                    # 最终注释交付（可选）
```

### 3. 配置环境变量

```bash
cp .project_env.example .project_env
# 编辑 PROJECT_ROOT 与目标种基因组路径
source .project_env
```

或：

```bash
bash old_reults/init_project.sh
source .project_env
```

### 4. 软件依赖（conda 优先）

- 注释：Augustus, GeneMark, GeMoMa, EVM, PASA, RepeatMasker/RepeatModeler, BUSCO, eggNOG-mapper, DIAMOND
- 比较基因组：OrthoFinder, MAFFT, IQ-TREE / RAxML, JCVI, CAFE5, PAML(CodeML), KaKs_Calculator, Circos
- 绘图：R（ggplot2, ggtree 等）

规范见 `old_reults/AGENTS.md`。

## 推荐复跑顺序

### A. 基因组注释（目标种）

```bash
cd old_reults
bash scripts/structure_annotation.sh
bash scripts/functional_annotation_main.sh
bash scripts/run_evm_v3.sh
bash scripts/run_pasa_update.sh
```

### B. 比较基因组

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

复用到自己的数据时，优先改：

1. `.project_env` / `species_list.csv`
2. `01_prepare_proteomes.sh` 中的输入映射
3. 下游脚本中的样本前缀（默认示例为 T01/T02）

## 样本编号约定（占位）

| 编号 | 角色 |
|------|------|
| T01–T02 | 目标样本 |
| C01–C11 | 比较物种 |
| O01–O02 | 外群 |

公开仓库中请只保留编号与相对路径，**不要**提交中文名、拉丁名或可识别目录名。

## 隐私

- 真实物种对照表、原始路径、项目计划等放在本地，勿推送到公开远程。
- `.project_env`、`species_list.csv`（若含真实信息）已被 `.gitignore` 忽略。
- 需要分享时，只分享本流程仓库；数据与结果单独传输。

## License

未单独声明许可证时，仅供合作方内部复用流程；公开分发前请补全 License。
