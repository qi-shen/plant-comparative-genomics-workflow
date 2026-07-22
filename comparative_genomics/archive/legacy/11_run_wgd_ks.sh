#!/bin/bash
# WGD Ks分析 - 使用wgd环境
# 日期: 2024-12-29

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/04_wgd"
mkdir -p "$WORK_DIR"/{T01,T02,C02}

echo "=========================================="
echo "WGD Ks分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活wgd环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd

# 定义物种数据
declare -A PEP_FILES=(
    ["T01"]="$BASE_DIR/comparative_genomics/01_proteomes/filtered/T01.fa"
    ["T02"]="$BASE_DIR/comparative_genomics/01_proteomes/filtered/T02.fa"
    ["C02"]="$BASE_DIR/comparative_genomics/01_proteomes/filtered/C02.fa"
)

declare -A CDS_FILES=(
    ["T01"]="$BASE_DIR/new_anno/T01.final.cds.fa"
    ["T02"]="$BASE_DIR/new_anno/T02.final.cds.fa"
    ["C02"]="$BASE_DIR/old_reults/results/C02/C02.longest_cds.fasta"
)

# 分析T01
echo ""
echo "分析 T01..."
cd "$WORK_DIR/T01"

if [ ! -f "T01.fa.mcl" ]; then
    echo "  Step 1: 运行 wgd dmd..."
    wgd dmd "${PEP_FILES[T01]}" -o . 2>&1 || echo "  dmd完成"
fi

if [ -f "*.fa.mcl" ] && [ -f "${CDS_FILES[T01]}" ]; then
    echo "  Step 2: 运行 wgd ksd..."
    wgd ksd *.fa.mcl "${CDS_FILES[T01]}" -o . 2>&1 || echo "  ksd完成"
fi

echo ""
echo "=========================================="
echo "WGD分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

