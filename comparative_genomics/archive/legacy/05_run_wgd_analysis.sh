#!/bin/bash
# WGD全基因组复制分析 - Ks分布计算
# 日期: 2024-12-29
# 修改: 2026-01-13 - 使用CDS文件运行wgd

set -e

BASE_DIR="/path/to/project_root"
cd $BASE_DIR
WORKDIR="$BASE_DIR/comparative_genomics/04_wgd"

echo "=========================================="
echo "WGD全基因组复制分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活wgd环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd
# 绕过用户级Python包冲突
export PYTHONNOUSERSITE=1

mkdir -p "$WORKDIR/ks_distribution"

# 定义CDS文件路径
declare -A CDS_FILES=(
    ["T01"]="$BASE_DIR/new_anno/T01.final.cds.fa"
    ["T02"]="$BASE_DIR/new_anno/T02.final.cds.fa"
    ["C02"]="$BASE_DIR/old_reults/results/C02/C02.longest_cds.fasta"
    ["C03"]="$BASE_DIR/old_reults/results/C03/C03_cds.fa"
    ["C01"]="$BASE_DIR/old_reults/results/C01/C01.cds.fa"
)

# 分析近缘类群5个物种
for sp in T01 T02 C02 C03 C01; do
    echo ""
    echo "=========================================="
    echo "分析 $sp"
    echo "=========================================="

    cds_file="${CDS_FILES[$sp]}"
    outdir="$WORKDIR/ks_distribution/$sp"

    mkdir -p "$outdir"
    cd "$outdir"

    if [ ! -f "$cds_file" ]; then
        echo "警告: CDS文件不存在 $cds_file"
        continue
    fi

    # 复制CDS文件到工作目录（添加物种前缀）
    cds_local="${sp}.cds.fa"
    if [ ! -f "$cds_local" ]; then
        awk -v sp="$sp" '/^>/{gsub(/^>/, ">" sp "_"); print; next} {print}' "$cds_file" > "$cds_local"
        echo "已复制CDS文件: $cds_local"
    fi

    # Step 1: 运行wgd dmd (全基因组比较，使用CDS)
    echo "Step 1: 运行 wgd dmd..."
    mcl_file=$(ls *.mcl 2>/dev/null | head -1)
    if [ -z "$mcl_file" ]; then
        wgd dmd "$cds_local" -o . -n 16 2>&1 || echo "wgd dmd 可能有警告，继续..."
        mcl_file=$(ls *.mcl 2>/dev/null | head -1)
    else
        echo "  已存在MCL文件: $mcl_file，跳过"
    fi

    # Step 2: 运行wgd ksd (Ks计算)
    echo "Step 2: 运行 wgd ksd..."
    if [ -n "$mcl_file" ] && [ -f "$mcl_file" ]; then
        echo "  使用MCL文件: $mcl_file"
        wgd ksd "$mcl_file" "$cds_local" -o . -n 16 2>&1 || echo "wgd ksd 可能有警告，继续..."
    else
        echo "  缺少MCL文件，跳过ksd步骤"
    fi

    cd $BASE_DIR
done

echo ""
echo "=========================================="
echo "WGD分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORKDIR/ks_distribution"
echo "=========================================="
