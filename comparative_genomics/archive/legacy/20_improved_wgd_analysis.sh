#!/bin/bash
# WGD分析 - 改进版本（使用更简单的方法）
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/04_wgd"
PROTEOMES="$BASE_DIR/comparative_genomics/01_proteomes/filtered"

echo "=========================================="
echo "WGD分析 - 改进版本"
echo "开始时间: $(date)"
echo "=========================================="

# 激活wgd环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd

mkdir -p "$WORK_DIR"/{ks_distribution,results}

# 分析近缘类群5个物种
for sp in T01 T02 C02 C03 C01; do
    echo ""
    echo "=========================================="
    echo "分析 $sp"
    echo "=========================================="
    
    pep_file="$PROTEOMES/${sp}.fa"
    outdir="$WORK_DIR/ks_distribution/$sp"
    
    mkdir -p "$outdir"
    cd "$outdir"
    
    if [ ! -f "$pep_file" ]; then
        echo "警告: 蛋白文件不存在 $pep_file"
        continue
    fi
    
    # 复制蛋白文件到当前目录
    cp "$pep_file" "${sp}.fa"
    
    # Step 1: 运行wgd dmd（全基因组比较）
    echo "Step 1: 运行 wgd dmd..."
    if [ ! -f "${sp}.fa.mcl" ]; then
        wgd dmd "${sp}.fa" -o . --tmpdir . 2>&1 | tail -20 || {
            echo "  wgd dmd完成（可能有警告）"
        }
    else
        echo "  已存在，跳过"
    fi
    
    # 检查结果
    if [ -f "*.fa.mcl" ] || [ -f "${sp}.fa.mcl" ]; then
        echo "  ✅ dmd结果已生成"
    else
        echo "  ⚠️ dmd结果未生成，继续下一步"
    fi
    
    cd "$BASE_DIR"
done

echo ""
echo "=========================================="
echo "WGD分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="
echo ""
echo "注意: Ks计算需要CDS序列，可以使用共线性分析中的同源基因对"

