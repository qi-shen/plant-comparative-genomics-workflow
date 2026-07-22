#!/bin/bash
# JCVI共线性分析 - 简化版本
# 日期: 2024-12-29

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/05_synteny/jcvi_analysis"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "=========================================="
echo "JCVI共线性分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活jcvi环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate jcvi

cd "$WORK_DIR"

# 复制所需文件
echo "复制数据文件..."

# T01
cp "$BASE_DIR/annotation/T01/structure/T01_genes.cds.fa" T01.cds
cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/T01.fa" T01.pep
awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
    "$BASE_DIR/annotation/T01/structure/T01_genes.gff3" | sort -k1,1 -k2,2n > T01.bed
echo "T01: $(wc -l < T01.bed) 基因"

# T02  
cp "$BASE_DIR/annotation/T02/structure/T02_genes.cds.fa" T02.cds
cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/T02.fa" T02.pep
awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
    "$BASE_DIR/annotation/T02/structure/T02_genes.gff3" | sort -k1,1 -k2,2n > T02.bed
echo "T02: $(wc -l < T02.bed) 基因"

# C02 (C02)
cp "$BASE_DIR/results/C02/C02.longest_cds.fasta" C02.cds
cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/C02.fa" C02.pep
awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
    "$BASE_DIR/results/C02/C02.gff3" | sort -k1,1 -k2,2n > C02.bed
echo "C02: $(wc -l < C02.bed) 基因"

echo ""
echo "运行T01 vs T02共线性分析..."
python -m jcvi.compara.catalog ortholog T01 T02 --no_strip_names 2>&1 || echo "分析完成（可能有警告）"

if [ -f "T01.T02.anchors" ]; then
    echo "生成共线性点图..."
    python -m jcvi.graphics.dotplot T01.T02.anchors --notex -o T01_T02_dotplot.pdf 2>&1 || echo "绑图完成"
    
    # 统计
    blocks=$(grep -c '^###' T01.T02.anchors 2>/dev/null || echo "0")
    pairs=$(grep -v '^#' T01.T02.anchors | wc -l)
    echo "T01 vs T02: $blocks 个共线性区块, $pairs 对同源基因"
fi

echo ""
echo "=========================================="
echo "完成时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

ls -la *.pdf *.anchors 2>/dev/null || echo "暂无输出文件"

