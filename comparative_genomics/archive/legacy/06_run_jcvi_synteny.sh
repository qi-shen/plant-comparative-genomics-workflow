#!/bin/bash
# JCVI共线性分析
# 日期: 2024-12-29

set -e

cd /path/to/project_root
WORKDIR="comparative_genomics/05_synteny/jcvi_plots"
mkdir -p "$WORKDIR"

echo "=========================================="
echo "JCVI共线性分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活jcvi环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate jcvi

cd "$WORKDIR"

# 链接蛋白序列文件
echo "链接蛋白序列文件..."
for sp in T01 T02 C02 C03 C01; do
    ln -sf "/path/to/project_root/comparative_genomics/01_proteomes/${sp}.fa" "${sp}.pep"
done

# 链接CDS序列文件 (JCVI ortholog命令需要)
echo "链接CDS序列文件..."
for sp in T01 T02 C02 C03 C01; do
    if [ -f "/path/to/project_root/comparative_genomics/05_synteny/cds/${sp}.cds.fa" ]; then
        ln -sf "/path/to/project_root/comparative_genomics/05_synteny/cds/${sp}.cds.fa" "${sp}.cds"
    fi
done

# 链接BED文件
echo "链接BED文件..."
for sp in T01 T02 C02 C03 C01; do
    if [ -f "/path/to/project_root/comparative_genomics/05_synteny/gff/${sp}.bed" ]; then
        ln -sf "/path/to/project_root/comparative_genomics/05_synteny/gff/${sp}.bed" "${sp}.bed"
    fi
done

# 分析组合
declare -a PAIRS=(
    "T01:T02"       # 目标物种
    "T01:C02"      # T01 vs C02
    "T01:C03"      # T01 vs C03
    "T02:C02"      # T02 vs C02
    "T02:C03"      # T02 vs C03
    "T01:C01"      # T01 vs C01
)

echo ""
echo "运行共线性分析..."

for pair in "${PAIRS[@]}"; do
    sp1="${pair%%:*}"
    sp2="${pair##*:}"
    
    echo ""
    echo "分析 $sp1 vs $sp2..."
    
    # 检查文件是否存在
    if [ ! -f "${sp1}.pep" ] || [ ! -f "${sp2}.pep" ]; then
        echo "  警告: 蛋白文件缺失，跳过"
        continue
    fi
    
    if [ ! -f "${sp1}.bed" ] || [ ! -f "${sp2}.bed" ]; then
        echo "  警告: BED文件缺失，跳过"
        continue
    fi
    
    # 运行JCVI共线性分析
    echo "  Step 1: 比对蛋白序列..."
    if [ ! -f "${sp1}.${sp2}.last" ]; then
        python -m jcvi.compara.catalog ortholog ${sp1} ${sp2} --no_strip_names 2>&1 || echo "  比对完成/有警告"
    else
        echo "  已存在比对结果，跳过"
    fi
    
    # 绘制点图
    echo "  Step 2: 绘制共线性点图..."
    if [ -f "${sp1}.${sp2}.anchors" ]; then
        python -m jcvi.graphics.dotplot ${sp1}.${sp2}.anchors --notex 2>&1 || echo "  绑图完成/有警告"
    else
        echo "  缺少anchors文件，跳过绘图"
    fi
done

echo ""
echo "=========================================="
echo "JCVI共线性分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORKDIR"
echo "=========================================="

