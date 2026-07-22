#!/bin/bash
# WGD全基因组复制分析 - Ks分布计算
# 日期: 2024-12-29

set -e

cd /path/to/project_root
WORKDIR="old_reults/comparative_genomics/04_wgd"
PROTEOMES="old_reults/comparative_genomics/01_proteomes/filtered"
LOGFILE="$WORKDIR/wgd_analysis_$(date +%Y%m%d_%H%M%S).log"

echo "=========================================="
echo "WGD全基因组复制分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活wgd环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd

mkdir -p "$WORKDIR"/{ks_distribution,4dtv,paranome}

# 定义CDS文件路径
declare -A CDS_FILES=(
    ["BH"]="new_anno/BH.final.cds.fa"
    ["CK"]="new_anno/CK.final.cds.fa"
    ["TAU"]="old_reults/results/C02/tau.longest_cds.fasta"
    ["TCH"]="old_reults/results/C03/Tchinensis_cds.fa"
    ["RSO"]="old_reults/results/C01/C01.cds.fa"
)

# 分析近缘类群5个物种
for sp in BH CK TAU TCH RSO; do
    echo ""
    echo "=========================================="
    echo "分析 $sp"
    echo "=========================================="
    
    pep_file="$PROTEOMES/${sp}.fa"
    cds_file="${CDS_FILES[$sp]}"
    outdir="$WORKDIR/ks_distribution/$sp"
    
    mkdir -p "$outdir"
    cd "$outdir"
    
    if [ ! -f "$pep_file" ]; then
        echo "警告: 蛋白文件不存在 $pep_file"
        continue
    fi
    
    # Step 1: 运行wgd dmd (全基因组比较)
    echo "Step 1: 运行 wgd dmd..."
    if [ ! -f "${sp}.fa.mcl" ]; then
        wgd dmd "/path/to/project_root/$pep_file" -o . 2>&1 || echo "wgd dmd 可能有警告，继续..."
    else
        echo "  已存在，跳过"
    fi
    
    # Step 2: 运行wgd ksd (Ks计算)
    echo "Step 2: 运行 wgd ksd..."
    if [ -f "*.fa.mcl" ] && [ -f "$cds_file" ]; then
        wgd ksd *.fa.mcl "/path/to/project_root/$cds_file" -o . 2>&1 || echo "wgd ksd 可能有警告，继续..."
    else
        echo "  缺少必要文件，跳过"
    fi
    
    cd /path/to/project_root
done

echo ""
echo "=========================================="
echo "WGD分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORKDIR"
echo "=========================================="

