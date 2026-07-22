#!/bin/bash
# WGD Ks分析 - 使用wgd环境
# 日期: 2024-12-29

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/old_reults/comparative_genomics/04_wgd"
mkdir -p "$WORK_DIR"/{BH,CK,TAU}

echo "=========================================="
echo "WGD Ks分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活wgd环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd

# 定义物种数据
declare -A PEP_FILES=(
    ["BH"]="$BASE_DIR/old_reults/comparative_genomics/01_proteomes/filtered/BH.fa"
    ["CK"]="$BASE_DIR/old_reults/comparative_genomics/01_proteomes/filtered/CK.fa"
    ["TAU"]="$BASE_DIR/old_reults/comparative_genomics/01_proteomes/filtered/TAU.fa"
)

declare -A CDS_FILES=(
    ["BH"]="$BASE_DIR/new_anno/BH.final.cds.fa"
    ["CK"]="$BASE_DIR/new_anno/CK.final.cds.fa"
    ["TAU"]="$BASE_DIR/old_reults/results/C02/tau.longest_cds.fasta"
)

# 分析BH
echo ""
echo "分析 BH..."
cd "$WORK_DIR/BH"

if [ ! -f "BH.fa.mcl" ]; then
    echo "  Step 1: 运行 wgd dmd..."
    wgd dmd "${PEP_FILES[BH]}" -o . 2>&1 || echo "  dmd完成"
fi

if [ -f "*.fa.mcl" ] && [ -f "${CDS_FILES[BH]}" ]; then
    echo "  Step 2: 运行 wgd ksd..."
    wgd ksd *.fa.mcl "${CDS_FILES[BH]}" -o . 2>&1 || echo "  ksd完成"
fi

echo ""
echo "=========================================="
echo "WGD分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

