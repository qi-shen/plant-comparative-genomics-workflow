#!/bin/bash
# JCVI更多共线性比较
# 日期: 2024-12-29

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/05_synteny/jcvi_analysis"

echo "=========================================="
echo "JCVI更多共线性比较"
echo "开始时间: $(date)"
echo "=========================================="

# 激活jcvi环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate jcvi

cd "$WORK_DIR"

# 添加TAU数据（如果不存在）
if [ ! -f "TAU.bed" ]; then
    cp "$BASE_DIR/results/C02/tau.longest_cds.fasta" TAU.cds
    cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/TAU.fa" TAU.pep
    awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
        "$BASE_DIR/results/C02/tau.gff3" | sort -k1,1 -k2,2n > TAU.bed
    echo "TAU数据准备完成: $(wc -l < TAU.bed) 基因"
fi

# BH vs TAU
echo ""
echo "分析 BH vs TAU..."
if [ ! -f "BH.TAU.anchors" ]; then
    python -m jcvi.compara.catalog ortholog BH TAU --no_strip_names 2>&1 | tail -5 || echo "完成"
fi

if [ -f "BH.TAU.anchors" ]; then
    python -m jcvi.graphics.dotplot BH.TAU.anchors --notex -o BH_TAU_dotplot.pdf 2>&1 | tail -3 || echo "绑图完成"
    blocks=$(grep -c '^###' BH.TAU.anchors 2>/dev/null || echo "0")
    pairs=$(grep -v '^#' BH.TAU.anchors | wc -l)
    echo "BH vs TAU: $blocks 个共线性区块, $pairs 对同源基因"
fi

# CK vs TAU
echo ""
echo "分析 CK vs TAU..."
if [ ! -f "CK.TAU.anchors" ]; then
    python -m jcvi.compara.catalog ortholog CK TAU --no_strip_names 2>&1 | tail -5 || echo "完成"
fi

if [ -f "CK.TAU.anchors" ]; then
    python -m jcvi.graphics.dotplot CK.TAU.anchors --notex -o CK_TAU_dotplot.pdf 2>&1 | tail -3 || echo "绑图完成"
    blocks=$(grep -c '^###' CK.TAU.anchors 2>/dev/null || echo "0")
    pairs=$(grep -v '^#' CK.TAU.anchors | wc -l)
    echo "CK vs TAU: $blocks 个共线性区块, $pairs 对同源基因"
fi

echo ""
echo "=========================================="
echo "完成时间: $(date)"
echo "=========================================="

# 汇总结果
echo ""
echo "共线性分析汇总:"
echo "-----------------"
for f in *.anchors; do
    if [ -f "$f" ]; then
        name=$(basename "$f" .anchors)
        blocks=$(grep -c '^###' "$f" 2>/dev/null || echo "0")
        pairs=$(grep -v '^#' "$f" | wc -l)
        echo "$name: $blocks 区块, $pairs 基因对"
    fi
done

echo ""
echo "生成的点图文件:"
ls -la *_dotplot.pdf 2>/dev/null

