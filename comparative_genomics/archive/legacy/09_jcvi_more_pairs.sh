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

# 添加C02数据（如果不存在）
if [ ! -f "C02.bed" ]; then
    cp "$BASE_DIR/results/C02/C02.longest_cds.fasta" C02.cds
    cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/C02.fa" C02.pep
    awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
        "$BASE_DIR/results/C02/C02.gff3" | sort -k1,1 -k2,2n > C02.bed
    echo "C02数据准备完成: $(wc -l < C02.bed) 基因"
fi

# T01 vs C02
echo ""
echo "分析 T01 vs C02..."
if [ ! -f "T01.C02.anchors" ]; then
    python -m jcvi.compara.catalog ortholog T01 C02 --no_strip_names 2>&1 | tail -5 || echo "完成"
fi

if [ -f "T01.C02.anchors" ]; then
    python -m jcvi.graphics.dotplot T01.C02.anchors --notex -o T01_C02_dotplot.pdf 2>&1 | tail -3 || echo "绑图完成"
    blocks=$(grep -c '^###' T01.C02.anchors 2>/dev/null || echo "0")
    pairs=$(grep -v '^#' T01.C02.anchors | wc -l)
    echo "T01 vs C02: $blocks 个共线性区块, $pairs 对同源基因"
fi

# T02 vs C02
echo ""
echo "分析 T02 vs C02..."
if [ ! -f "T02.C02.anchors" ]; then
    python -m jcvi.compara.catalog ortholog T02 C02 --no_strip_names 2>&1 | tail -5 || echo "完成"
fi

if [ -f "T02.C02.anchors" ]; then
    python -m jcvi.graphics.dotplot T02.C02.anchors --notex -o T02_C02_dotplot.pdf 2>&1 | tail -3 || echo "绑图完成"
    blocks=$(grep -c '^###' T02.C02.anchors 2>/dev/null || echo "0")
    pairs=$(grep -v '^#' T02.C02.anchors | wc -l)
    echo "T02 vs C02: $blocks 个共线性区块, $pairs 对同源基因"
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

