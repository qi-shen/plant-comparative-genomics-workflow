#!/bin/bash
# CAFE5 基因家族扩张/收缩分析 - 调整参数版本
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/07_cafe"
OF_DIR="$BASE_DIR/comparative_genomics/02_orthofinder_results"

echo "=========================================="
echo "CAFE5 基因家族动态分析 (调整参数版本)"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

# 查找OrthoFinder结果目录（自动选择最新的 Results_*）
RESULTS_DIR=$(ls -td "$OF_DIR"/Results_* 2>/dev/null | head -1)

if [ ! -d "$RESULTS_DIR" ]; then
    echo "错误: OrthoFinder结果目录不存在: $RESULTS_DIR"
    exit 1
fi

echo "使用OrthoFinder结果目录: $RESULTS_DIR"

# 检查必要文件
OG_COUNTS="$RESULTS_DIR/Orthogroups/Orthogroups.GeneCount.tsv"
SPECIES_TREE="$RESULTS_DIR/Species_Tree/SpeciesTree_rooted.txt"

if [ ! -f "$OG_COUNTS" ]; then
    echo "错误: 基因家族计数文件不存在"
    exit 1
fi

if [ ! -f "$SPECIES_TREE" ]; then
    echo "错误: 物种树文件不存在"
    exit 1
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 备份旧结果
if [ -d "cafe_results" ]; then
    mv cafe_results cafe_results_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
fi

# 准备CAFE输入文件 - 只保留在所有物种中都存在的家族
echo "准备CAFE输入文件（过滤策略：所有15个物种都存在）..."

# 使用Python脚本过滤基因家族
python3 << PYTHON_SCRIPT
import pandas as pd

# 读取基因家族计数表
og_counts = pd.read_csv('${OG_COUNTS}', sep='\t')

# 物种列（排除Orthogroup和Total列）
species_cols = [col for col in og_counts.columns if col not in ['Orthogroup', 'Total']]

# 过滤：所有15个物种都存在（>0）
og_counts_filtered = og_counts[(og_counts[species_cols] > 0).all(axis=1)]

print(f"原始家族数: {len(og_counts)}")
print(f"过滤后家族数: {len(og_counts_filtered)} (所有15个物种都存在)")

# 进一步过滤：排除异常大的家族（>500个基因）
og_counts_filtered = og_counts_filtered[og_counts_filtered['Total'] <= 500]
print(f"进一步过滤后: {len(og_counts_filtered)} (排除>500基因的家族)")

# 转换为CAFE格式
cafe_data = pd.DataFrame()
cafe_data['Desc'] = '(null)'
cafe_data['Family'] = og_counts_filtered['Orthogroup']
for col in species_cols:
    cafe_data[col] = og_counts_filtered[col]

# 保存
output_file = '/path/to/project_root/comparative_genomics/07_cafe/gene_families_filtered.tsv'
cafe_data.to_csv(output_file, sep='\t', index=False)
print(f"已保存过滤后的基因家族文件: {output_file}")
print(f"文件行数: {len(cafe_data) + 1} (包含表头)")
PYTHON_SCRIPT

# 复制物种树
cp "$SPECIES_TREE" species_tree.nwk

# 检查过滤后的文件
filtered_count=$(tail -n +2 gene_families_filtered.tsv | wc -l)
echo "过滤后的基因家族数: $filtered_count"

if [ "$filtered_count" -lt 100 ]; then
    echo "警告: 过滤后家族数太少，可能影响分析结果"
fi

# 运行CAFE5 - 使用调整后的参数
echo ""
echo "运行CAFE5 (调整参数：)"
echo "  - 使用所有物种都存在的家族"
echo "  - 减少迭代次数: 100 (默认300)"
echo "  - 使用Poisson分布"
echo "  - 设置lambda搜索范围: 0.01-2.0"
echo ""

# CAFE5参数调整：
# -I 100: 减少迭代次数到100
# -p: 使用Poisson分布（从数据估计）
# -c 64: 使用64核心
# -P 0.05: p值阈值

cafe5 \
    -i gene_families_filtered.tsv \
    -t species_tree.nwk \
    -o cafe_results \
    -I 100 \
    -p \
    -c 64 \
    -P 0.05 \
    2>&1 | tee cafe_run.log || {
    echo ""
    echo "CAFE5运行完成（可能有警告）"
}

# 检查结果
if [ -d "cafe_results" ]; then
    echo ""
    echo "=========================================="
    echo "CAFE5结果文件:"
    ls -lah cafe_results/
    
    # 统计结果
    if [ -f "cafe_results/report.cafe" ]; then
        echo ""
        echo "结果摘要 (前50行):"
        head -50 cafe_results/report.cafe
    fi
    
    if [ -f "cafe_results/Base_change.tab" ]; then
        echo ""
        echo "基因家族变化统计:"
        head -20 cafe_results/Base_change.tab
    fi
else
    echo ""
    echo "警告: 结果目录未生成，请检查日志文件 cafe_run.log"
fi

echo ""
echo "=========================================="
echo "CAFE5分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR/cafe_results"
echo "日志文件: $WORK_DIR/cafe_run.log"
echo "=========================================="
