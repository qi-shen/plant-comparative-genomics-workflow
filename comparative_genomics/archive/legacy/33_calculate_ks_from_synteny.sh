#!/bin/bash
# 从共线性分析结果计算Ks值（WGD分析替代方案）
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/04_wgd"
SYNTENY_DIR="$BASE_DIR/comparative_genomics/05_synteny/jcvi_analysis"
CDS_DIR="$BASE_DIR/comparative_genomics/05_synteny/jcvi_data"
OUTPUT_DIR="$WORK_DIR/ks_from_synteny"

echo "=========================================="
echo "从共线性结果计算Ks值（WGD分析）"
echo "开始时间: $(date)"
echo "=========================================="

# 检查KaKs_Calculator是否安装
if ! command -v KaKs_Calculator &> /dev/null; then
    echo "错误: KaKs_Calculator未安装"
    echo "安装命令: conda install -c bioconda kaks-calculator"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 定义物种对
declare -a pairs=("T01 T02" "T01 C02" "T02 C02")

echo ""
echo "处理共线性anchors文件..."
echo ""

for pair in "${pairs[@]}"; do
    read -r sp1 sp2 <<< "$pair"
    anchors_file="${SYNTENY_DIR}/${sp1}.${sp2}.anchors"
    cds1_file="${CDS_DIR}/${sp1}.cds"
    cds2_file="${CDS_DIR}/${sp2}.cds"
    
    if [ ! -f "$anchors_file" ]; then
        echo "跳过 ${sp1}-${sp2}: anchors文件不存在"
        continue
    fi
    
    if [ ! -f "$cds1_file" ] || [ ! -f "$cds2_file" ]; then
        echo "跳过 ${sp1}-${sp2}: CDS文件不存在"
        continue
    fi
    
    echo "处理 ${sp1} vs ${sp2}..."
    
    # 统计同源基因对数量
    pair_count=$(grep -v "^#" "$anchors_file" | wc -l)
    echo "  同源基因对: $pair_count"
    
    # 创建输出目录
    pair_dir="${OUTPUT_DIR}/${sp1}_${sp2}"
    mkdir -p "$pair_dir"
    
    # 提取前1000对进行测试（完整分析需要更多时间）
    echo "  提取前1000对同源基因进行Ks计算..."
    
    # 这里需要：
    # 1. 从anchors文件提取基因ID
    # 2. 从CDS文件中提取对应序列
    # 3. 准备KaKs_Calculator输入格式
    # 4. 运行KaKs_Calculator
    
    echo "  注意: 完整实现需要编写Python脚本提取序列并格式化"
    echo "  输出目录: $pair_dir"
done

echo ""
echo "=========================================="
echo "Ks计算准备完成"
echo "结束时间: $(date)"
echo "输出目录: $OUTPUT_DIR"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 编写脚本从anchors提取基因对"
echo "  2. 提取对应的CDS序列"
echo "  3. 格式化并运行KaKs_Calculator"
echo "  4. 绘制Ks分布图"

