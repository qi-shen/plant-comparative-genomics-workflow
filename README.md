# Plant Comparative Genomics Workflow / 植物比较基因组分析流程

Reusable, species-agnostic pipeline for genome annotation and multi-species comparative genomics.  
通用、物种脱敏的基因组注释与多物种比较基因组流程模板。

---

## Language / 语言

| | |
|:--|:--|
| **English** | [Open English README](README.en.md) |
| **中文** | [打开中文说明](README.zh-CN.md) |

> On GitHub: click a link above to switch the documentation language.  
> 在 GitHub 上点击上方链接即可切换文档语言。

---

## Quick links / 快速链接

| English | 中文 |
|:--|:--|
| [Full README](README.en.md) | [完整说明](README.zh-CN.md) |
| [Pipeline data flow](docs/pipeline.md) | [流程数据流](docs/pipeline.md) |
| [Refactor plan](docs/REFACTOR_PLAN.en.md) | [重构计划](docs/REFACTOR_PLAN.zh-CN.md) |
| [Agent notes](CLAUDE.en.md) | [流程说明](CLAUDE.zh-CN.md) |

## Run / 运行

```bash
cp .project_env.example .project_env
# edit config/species.csv
source .project_env
./run_all.sh list
make orthology
```

Canonical comparative scripts: `comparative_genomics/scripts/` (`10_`–`94_`).  
比较基因组权威脚本目录：`comparative_genomics/scripts/`。
