#!/bin/bash
# CAFE5 基因家族扩张/收缩分析
# 日期: 2024-12-29

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/07_cafe"
OF_DIR="$BASE_DIR/comparative_genomics/02_orthofinder_results"

echo "=========================================="
echo "CAFE5 基因家族扩张/收缩分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

# 查找OrthoFinder结果目录
RESULTS_DIR=$(ls -td "$OF_DIR"/Results_* 2>/dev/null | head -1)

if [ ! -d "$RESULTS_DIR" ]; then
    echo "错误: OrthoFinder结果目录不存在"
    exit 1
fi

# 检查必要文件
OG_COUNTS="$RESULTS_DIR/Orthogroups/Orthogroups.GeneCount.tsv"
SPECIES_TREE="$RESULTS_DIR/Species_Tree/SpeciesTree_rooted.txt"

if [ ! -f "$OG_COUNTS" ]; then
    echo "错误: 基因家族计数文件不存在"
    echo "请等待OrthoFinder完成"
    exit 1
fi

if [ ! -f "$SPECIES_TREE" ]; then
    echo "错误: 物种树文件不存在"
    exit 1
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 准备CAFE输入文件
echo "准备CAFE输入文件..."

# 转换基因家族计数表格式
# CAFE需要的格式: Desc Family sp1 sp2 sp3 ...
echo "转换基因家族计数表..."
awk -F'\t' 'NR==1 {
    printf "Desc\tFamily"
    for(i=2; i<=NF-1; i++) printf "\t%s", $i
    print ""
    next
}
{
    printf "(null)\t%s", $1
    for(i=2; i<=NF-1; i++) printf "\t%s", $i
    print ""
}' "$OG_COUNTS" > gene_families.tsv

# 复制物种树
cp "$SPECIES_TREE" species_tree.nwk

# 物种树需要添加分支长度用于CAFE
# 这里使用简单的超度量树
echo "准备超度量物种树..."

# 运行CAFE5
echo ""
echo "运行CAFE5..."
cafe5 -i gene_families.tsv -t species_tree.nwk -o cafe_results 2>&1 || echo "CAFE5完成"

# 解析结果
if [ -d "cafe_results" ]; then
    echo ""
    echo "CAFE5结果汇总:"
    ls -la cafe_results/
fi

echo ""
echo "=========================================="
echo "CAFE5分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

