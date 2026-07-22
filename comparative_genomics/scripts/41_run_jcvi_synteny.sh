#!/bin/bash
# JCVI共线性分析 v2
# 日期: 2024-12-29

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

WORKDIR="comparative_genomics/05_synteny/jcvi_data"
OUTDIR="comparative_genomics/05_synteny/jcvi_plots"
mkdir -p "$OUTDIR"

echo "=========================================="
echo "JCVI共线性分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活jcvi环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate jcvi

cd "$OUTDIR"

# 检查数据文件
echo "检查数据文件..."
for sp in T01 T02 C02 C03 C01; do
    if [ -f "../jcvi_data/${sp}.bed" ] && [ -f "../jcvi_data/${sp}.pep" ]; then
        ln -sf "../jcvi_data/${sp}.bed" "${sp}.bed"
        ln -sf "../jcvi_data/${sp}.pep" "${sp}.pep"
        bed_count=$(wc -l < "${sp}.bed")
        pep_count=$(grep -c '^>' "${sp}.pep")
        echo "  $sp: $bed_count BED记录, $pep_count 蛋白序列"
    else
        echo "  $sp: 缺少数据文件"
    fi
done

# 分析组合
declare -a PAIRS=(
    "T01:T02"       # 目标物种
    "T01:C02"      # T01 vs C02
    "T02:C02"      # T02 vs C02
)

echo ""
echo "运行共线性分析..."

for pair in "${PAIRS[@]}"; do
    sp1="${pair%%:*}"
    sp2="${pair##*:}"
    
    echo ""
    echo "=========================================="
    echo "分析 $sp1 vs $sp2..."
    echo "=========================================="
    
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
    echo "  Step 1: 比对蛋白序列并识别共线性区块..."
    if [ ! -f "${sp1}.${sp2}.anchors" ]; then
        python -m jcvi.compara.catalog ortholog ${sp1} ${sp2} --no_strip_names 2>&1 | tail -20 || echo "  比对完成"
    else
        echo "  已存在anchors文件"
    fi
    
    # 绘制点图
    echo "  Step 2: 绘制共线性点图..."
    if [ -f "${sp1}.${sp2}.anchors" ]; then
        python -m jcvi.graphics.dotplot ${sp1}.${sp2}.anchors --notex -o "${sp1}_${sp2}_dotplot.pdf" 2>&1 | tail -5 || echo "  绑图完成"
    else
        echo "  缺少anchors文件，跳过绘图"
    fi
    
    # 统计共线性区块
    if [ -f "${sp1}.${sp2}.anchors" ]; then
        anchors_count=$(grep -c '^###' "${sp1}.${sp2}.anchors" || echo "0")
        gene_pairs=$(grep -v '^#' "${sp1}.${sp2}.anchors" | wc -l)
        echo "  统计: $anchors_count 个共线性区块, $gene_pairs 对同源基因"
    fi
done

echo ""
echo "=========================================="
echo "JCVI共线性分析完成"
echo "结束时间: $(date)"
echo "输出目录: $OUTDIR"
echo "=========================================="

# 列出生成的文件
echo ""
echo "生成的文件:"
ls -la *.pdf *.anchors 2>/dev/null | head -20

