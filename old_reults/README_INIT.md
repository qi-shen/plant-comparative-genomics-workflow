# 项目初始化指南（脱敏）

## 快速开始

```bash
cd /path/to/project_root
bash old_reults/init_project.sh
cp .project_env.example .project_env   # 若脚本未生成
# 编辑 .project_env
source .project_env
```

初始化会检查 conda、关键目录，并生成/更新本机环境配置（不入库）。

## 环境变量

| 变量名 | 说明 |
|--------|------|
| `PROJECT_ROOT` | 项目根目录 |
| `RESULTS_DIR` | 物种数据目录 |
| `SCRIPTS_DIR` | 注释脚本目录 |
| `ANNOTATION_DIR` | 注释目录 |
| `COMPARATIVE_DIR` | 比较基因组目录 |
| `LOGS_DIR` | 日志 |
| `TOOLS_DIR` | 工具 |
| `RNA_DIR` | 转录组 |
| `T01_GENOME` / `T02_GENOME` | 目标样本基因组 |

## 隐私

- 公开仓库只保留流程与编号（T/C/O）。
- 真实种名、拉丁名、可识别路径写在本地 `species_list.csv` / `.project_env`，勿提交。
