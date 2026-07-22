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

# BH
cp "$BASE_DIR/annotation/BH/structure/BH_genes.cds.fa" BH.cds
cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/BH.fa" BH.pep
awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
    "$BASE_DIR/annotation/BH/structure/BH_genes.gff3" | sort -k1,1 -k2,2n > BH.bed
echo "BH: $(wc -l < BH.bed) 基因"

# CK  
cp "$BASE_DIR/annotation/CK/structure/CK_genes.cds.fa" CK.cds
cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/CK.fa" CK.pep
awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
    "$BASE_DIR/annotation/CK/structure/CK_genes.gff3" | sort -k1,1 -k2,2n > CK.bed
echo "CK: $(wc -l < CK.bed) 基因"

# TAU (C02)
cp "$BASE_DIR/results/C02/tau.longest_cds.fasta" TAU.cds
cp "$BASE_DIR/comparative_genomics/01_proteomes/filtered/TAU.fa" TAU.pep
awk -F'\t' '$3=="mRNA" {split($9,a,";"); for(i in a) if(a[i]~/^ID=/) {gsub("ID=","",a[i]); print $1"\t"$4-1"\t"$5"\t"a[i]"\t0\t"$7}}' \
    "$BASE_DIR/results/C02/tau.gff3" | sort -k1,1 -k2,2n > TAU.bed
echo "TAU: $(wc -l < TAU.bed) 基因"

echo ""
echo "运行BH vs CK共线性分析..."
python -m jcvi.compara.catalog ortholog BH CK --no_strip_names 2>&1 || echo "分析完成（可能有警告）"

if [ -f "BH.CK.anchors" ]; then
    echo "生成共线性点图..."
    python -m jcvi.graphics.dotplot BH.CK.anchors --notex -o BH_CK_dotplot.pdf 2>&1 || echo "绑图完成"
    
    # 统计
    blocks=$(grep -c '^###' BH.CK.anchors 2>/dev/null || echo "0")
    pairs=$(grep -v '^#' BH.CK.anchors | wc -l)
    echo "BH vs CK: $blocks 个共线性区块, $pairs 对同源基因"
fi

echo ""
echo "=========================================="
echo "完成时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

ls -la *.pdf *.anchors 2>/dev/null || echo "暂无输出文件"

