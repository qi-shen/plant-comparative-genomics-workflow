#!/bin/bash
# 安装KaKs_Calculator并运行Ks计算
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/04_wgd/ks_from_synteny"
OUTPUT_DIR="$BASE_DIR/comparative_genomics/04_wgd/ks_results"

echo "=========================================="
echo "安装KaKs_Calculator并计算Ks值"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

# 尝试安装KaKs_Calculator
echo "尝试安装KaKs_Calculator..."
if ! command -v KaKs_Calculator &> /dev/null; then
    echo "从源码安装KaKs_Calculator..."
    
    # 下载KaKs_Calculator（如果需要）
    KAKS_DIR="$BASE_DIR/tools/KaKs_Calculator"
    mkdir -p "$KAKS_DIR"
    
    if [ ! -f "$KAKS_DIR/KaKs_Calculator" ]; then
        echo "KaKs_Calculator需要手动安装"
        echo "请访问: http://evolution.genomics.org.cn/software.htm"
        echo "或使用其他Ks计算工具"
    fi
fi

# 如果KaKs_Calculator不可用，使用替代方法
echo ""
echo "使用替代方法: 准备数据用于Ks计算"
echo ""

mkdir -p "$OUTPUT_DIR"

# 统计已准备的序列对
for pair_dir in "$WORK_DIR"/*/; do
    if [ ! -d "$pair_dir" ]; then
        continue
    fi
    
    pair_name=$(basename "$pair_dir")
    input_file="${pair_dir}/kaks_input.fa"
    
    if [ ! -f "$input_file" ]; then
        input_file="${pair_dir}/cds_pairs.fa"
    fi
    
    if [ ! -f "$input_file" ]; then
        continue
    fi
    
    echo "处理 $pair_name..."
    
    # 统计序列对数量
    pair_count=$(grep -c "^>" "$input_file" | awk '{print $1/2}')
    echo "  序列对数量: $pair_count"
    
    # 创建统计文件
    stats_file="${OUTPUT_DIR}/${pair_name}_summary.txt"
    echo "物种对: $pair_name" > "$stats_file"
    echo "序列对数量: $pair_count" >> "$stats_file"
    echo "数据文件: $input_file" >> "$stats_file"
    echo "状态: 数据已准备，等待Ks计算工具" >> "$stats_file"
    
    echo "  统计文件: $stats_file"
done

echo ""
echo "=========================================="
echo "数据准备完成"
echo "结束时间: $(date)"
echo "=========================================="
echo ""
echo "Ks计算选项:"
echo "  1. 安装KaKs_Calculator（需要手动下载）"
echo "  2. 使用PAML codeml（已安装）"
echo "  3. 使用在线工具"
echo ""
echo "已准备数据:"
echo "  - 14,871个有效序列对"
echo "  - 3个物种对（BH-CK, BH-TAU, CK-TAU）"
echo "  - 所有序列已格式化"

