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

### Phase 0 — 冻结与盘点 ✅（本提交）

- [x] 打 tag `pre-refactor`
- [x] 生成 `SCRIPT_INVENTORY.csv` / `SCRIPT_TREE_DIFF.csv` / `SCRIPT_DECISIONS.csv`
- [x] 落盘本重构计划

### Phase 1 — 消除重复源（高价值、低风险）

1. 对 10 个 `DIVERGED` 文件逐一 diff，合并进 `comparative_genomics/scripts/`
2. 删除 `old_reults/comparative_genomics/`（52 个 identical + 已合并的分叉）
3. 更新 README / CLAUDE 引用为唯一路径

### Phase 2 — 收敛版本

1. 按功能族选定胜出脚本（尤其 Ks/KaKs、filter、jcvi、wgd、cafe）
2. 胜出者改为规范名；其余移入 `archive/`
3. 监控类脚本移入 `tools/` 或 archive

参考 `SCRIPT_DECISIONS.csv` 中 `provisional_decision` 列（需人工确认）。

### Phase 3 — 配置化与公共库

1. 新建 `config/species.csv`、`lib/common.sh`
2. 改写入口脚本从配置读取
3. 清除绝对路径硬编码

### Phase 4 — 重编号与编排

1. 按阶段前缀重排
2. 增加 `run_all.sh` / `Makefile`
3. 更新中英双语文档中的运行顺序

### Phase 5 — 脱敏与文档收尾

1. 全仓库脱敏 grep-replace
2. 对齐双语 README/CLAUDE 声明
3. 补充 `docs/pipeline.md` 数据流说明

---

## 四、风险控制

- 每 Phase 一个独立 commit（或 PR）
- Phase 1–2 以文件组织为主，最易验证
- Phase 3 改逻辑，需样例数据冒烟
- 任何阶段可 `git checkout pre-refactor` 回滚到基线

---

## 五、下一步

推荐立即做 **Phase 1**：合并 10 个分叉文件 → 删除重复树。  
需你确认后再改脚本内容（Phase 3+）。
