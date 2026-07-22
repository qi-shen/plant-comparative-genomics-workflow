# CLAUDE.md（中文）

**语言：** [English](CLAUDE.en.md) | [中文](CLAUDE.zh-CN.md)

流程说明。样本编号（T/C/O）为模板占位符，真实数据映射见 config/species.csv。

## 概述

- 目标：T01、T02 · 比较：C01–C11 · 外群：O01–O02
- 流程：注释 → OrthoFinder → 系统发育 → WGD/Ks → 共线性 → 正选择 → CAFE → 出图

## 目录

```text
project_root/
├── config/species.csv
├── lib/common.sh, species.py
├── annotation/scripts/
├── comparative_genomics/
│   ├── scripts/          # 权威脚本 10_–94_
│   └── archive/          # 历史试错
├── run_all.sh, Makefile
└── .project_env          # 本机，不入库
```

## 命令

```bash
source .project_env
./run_all.sh orthology
./run_all.sh phylogeny
./run_all.sh wgd
./run_all.sh synteny
./run_all.sh selection
./run_all.sh cafe
./run_all.sh figures
# 或
make all
```

注释：

```bash
bash annotation/scripts/structure_annotation.sh
bash annotation/scripts/functional_annotation_main.sh
bash annotation/scripts/run_evm_v3.sh
bash annotation/scripts/run_pasa_update.sh
```

## 规范

- 优先 conda；多核；后台 + 进度日志
- 优先 R 绘图；无网格；无上/右边框
- 配色：`old_reults/AGENTS.zh-CN.md`
- 物种路径只写在 `config/species.csv`
