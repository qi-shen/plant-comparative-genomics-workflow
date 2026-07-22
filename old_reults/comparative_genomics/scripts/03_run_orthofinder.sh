#!/bin/bash
# OrthoFinder基因家族鉴定
# 日期: 2024-12-29

set -e

# 配置
WORKDIR="/path/to/project_root/old_reults/comparative_genomics"
PROTEOMES="$WORKDIR/01_proteomes"
OUTDIR="$WORKDIR/02_orthofinder_results"
THREADS=120
LOGFILE="$WORKDIR/logs/orthofinder_$(date +%Y%m%d_%H%M%S).log"

# OrthoFinder路径
ORTHOFINDER="/home/shenq/Biosofts/OrthoFinder_source/orthofinder.py"

echo "=========================================="
echo "OrthoFinder基因家族鉴定"
echo "开始时间: $(date)"
echo "=========================================="
echo ""

# 激活conda环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

# 检查输入文件
echo "检查输入文件..."
for f in "$PROTEOMES"/*.fa; do
    count=$(grep -c '^>' "$f")
    name=$(basename "$f")
    echo "  $name: $count 序列"
done
echo ""

# 确保输出目录不存在（OrthoFinder要求）
if [ -d "$OUTDIR" ]; then
    echo "警告: 输出目录已存在，删除旧目录..."
    rm -rf "$OUTDIR"
fi

# 运行OrthoFinder
echo "运行OrthoFinder..."
echo "使用 $THREADS 线程"
echo ""

python $ORTHOFINDER \
    -f "$PROTEOMES" \
    -t $THREADS \
    -a 64 \
    -S diamond \
    -M msa \
    -o "$OUTDIR" \
    2>&1 | tee -a "$LOGFILE"

echo ""
echo "=========================================="
echo "OrthoFinder完成"
echo "结束时间: $(date)"
echo "输出目录: $OUTDIR"
echo "=========================================="

# 生成结果摘要
RESULTS_DIR=$(ls -td "$OUTDIR"/Results_* 2>/dev/null | head -1)
if [ -d "$RESULTS_DIR" ]; then
    echo ""
    echo "结果摘要:"
    echo "==========="
    
    # 统计基因家族数量
    if [ -f "$RESULTS_DIR/Orthogroups/Orthogroups.tsv" ]; then
        og_count=$(wc -l < "$RESULTS_DIR/Orthogroups/Orthogroups.tsv")
        echo "基因家族数量: $((og_count - 1))"
    fi
    
    # 统计单拷贝同源基因数量
    if [ -d "$RESULTS_DIR/Single_Copy_Orthologue_Sequences" ]; then
        sc_count=$(ls "$RESULTS_DIR/Single_Copy_Orthologue_Sequences"/*.fa 2>/dev/null | wc -l)
        echo "单拷贝同源基因数量: $sc_count"
    fi
    
    # 显示统计文件
    if [ -f "$RESULTS_DIR/Comparative_Genomics_Statistics/Statistics_Overall.tsv" ]; then
        echo ""
        echo "整体统计:"
        cat "$RESULTS_DIR/Comparative_Genomics_Statistics/Statistics_Overall.tsv"
    fi
fi

