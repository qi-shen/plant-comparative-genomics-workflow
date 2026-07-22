# 重构计划

**语言：** [English](REFACTOR_PLAN.en.md) | [中文](REFACTOR_PLAN.zh-CN.md)

> 基线标签：`pre-refactor`（Phase 0 打点，便于回滚）  
> 盘点产物：`docs/SCRIPT_INVENTORY.csv`、`SCRIPT_TREE_DIFF.csv`、`SCRIPT_DECISIONS.csv`

---

## 一、问题诊断（已用仓库扫描复核）

### 1. 版本泛滥 / 调试脚本沉淀（最严重）

同一功能存在多个 `_v2 / _v3 / fix_ / final_ / improved_ / simple_` 版本。盘点显示 **57** 个文件名带版本/试错痕迹；Ks/KaKs 相关编号尤其分散（10、24、33–46 等）。

### 2. 编号失去排序意义

前缀从 `13 → 30 → 50` 再跳到 `60/61/90/92/93/95/100/101/110–116`，无法靠编号判断推荐入口。

### 3. 两套 comparative_genomics 已分叉（高风险）

| 状态 | 数量 |
|------|------|
| 完全相同 `identical` | **52** |
| 内容已分叉 `DIVERGED` | **10** |
| 仅存在于 `comparative_genomics/` | **17** |
| 仅存在于 `old_reults/...` | **0** |

**已分叉文件（Phase 1 必须人工合并）：**

- `01_prepare_proteomes.sh`
- `03_run_orthofinder.sh`
- `04_prepare_synteny_data.sh`
- `05_run_wgd_analysis.sh`
- `06_run_jcvi_synteny.sh`
- `11_run_wgd_ks.sh`
- `12_run_phylogeny.sh`
- `13_run_cafe_v2.sh`
- `16_prepare_selection_analysis.sh`
- `52_create_final_summary.py`

权威目录定为：`comparative_genomics/scripts/`（更新、含出图脚本）。

### 4. 目录名 `old_reults` 拼写错误且职责过载

同时承担归档脚本、注释流程、results/logs/tools 根路径；`.project_env` 绑死该错拼名。

### 5. 硬编码路径

盘点：**200** 个脚本含 `/home/` 或 `/path/to/`。`01_prepare_proteomes.sh` 等仍用硬编码物种映射，而非读取 `species_list.example.csv`。

### 6. 脱敏声明与内容不一致

文档声明只用 T/C/O，但扫描显示 **132** 个脚本仍有 `BH/CK/目标种` 或可识别文件名痕迹。公开前必须收口。

### 7. 缺乏配置驱动与公共库

无统一 `config/` 读取；无 `lib/common.sh`；样板代码与物种表在各脚本重复。

---

## 二、目标形态

| 方向 | 建议 |
|------|------|
| 单一权威源 | 只保留 `comparative_genomics/`；删除 `old_reults/comparative_genomics/`（合并分叉后） |
| 配置驱动 | `config/species.csv` + `.project_env`；禁止脚本内 `declare -A` 硬编码物种路径 |
| 归档试错 | 每功能只留胜出版本；历史进 `archive/`（或依赖 git） |
| 重编号 | `00_setup / 10_orthology / 20_phylogeny / 30_wgd_ks / 40_synteny / 50_selection / 60_cafe / 70_figures` |
| 公共库 | `lib/common.sh`：`set -euo pipefail`、日志、source env、conda、路径校验 |
| 编排入口 | `run_all.sh` 或 `Makefile` |
| 修正命名 | `old_reults` → 拆分为 `annotation/` 等清晰模块（或先改名为 `old_results`） |
| 脱敏收口 | 全库 grep 后替换；README 声明与内容一致 |

---

## 三、分阶段计划

原则：**先低风险清理、后结构调整**；每阶段独立提交、可回滚。

### Phase 0 — 冻结与盘点 ✅

- [x] 打 tag `pre-refactor`
- [x] 生成盘点 CSV
- [x] 落盘本重构计划

### Phase 1 — 消除重复源 ✅

- [x] 确认 `comparative_genomics/` 为权威（分叉文件均为更新版）
- [x] 删除 `old_reults/comparative_genomics/`

### Phase 2 — 收敛版本 ✅

- [x] 选定胜出脚本并重命名为阶段编号
- [x] 试错脚本 → `comparative_genomics/archive/legacy/`
- [x] 监控脚本 → `archive/ops/`
- [x] 注释脚本迁至 `annotation/scripts/`

### Phase 3 — 配置化与公共库 ✅

- [x] `config/species.csv`
- [x] `lib/common.sh` + `lib/species.py`
- [x] `10_prepare_proteomes.sh` / `11_filter_proteomes.py` / `13_run_orthofinder.sh` 配置驱动

### Phase 4 — 重编号与编排 ✅

- [x] 阶段前缀 `10_`–`94_`
- [x] `run_all.sh` + `Makefile`
- [x] 双语 README/CLAUDE 更新

### Phase 5 — 脱敏与文档收尾 ✅

- [x] 活跃脚本脱敏（归档目录保留历史痕迹供对照）
- [x] `docs/pipeline.md`

---

## 四、回滚

```bash
git checkout pre-refactor
```
