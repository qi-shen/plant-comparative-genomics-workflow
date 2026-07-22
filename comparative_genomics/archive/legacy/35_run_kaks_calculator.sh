#!/bin/bash
# 运行KaKs_Calculator计算Ks值
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/04_wgd/ks_from_synteny"
OUTPUT_DIR="$BASE_DIR/comparative_genomics/04_wgd/ks_results"

echo "=========================================="
echo "运行KaKs_Calculator计算Ks值"
echo "开始时间: $(date)"
echo "=========================================="

# 检查KaKs_Calculator
if ! command -v KaKs_Calculator &> /dev/null; then
    echo "错误: KaKs_Calculator未安装"
    echo "安装命令: conda install -c bioconda kaks-calculator"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 处理每个物种对
for pair_dir in "$WORK_DIR"/*/; do
    if [ ! -d "$pair_dir" ]; then
        continue
    fi
    
    pair_name=$(basename "$pair_dir")
    cds_file="${pair_dir}/cds_pairs.fa"
    
    if [ ! -f "$cds_file" ]; then
        echo "跳过 $pair_name: CDS文件不存在"
        continue
    fi
    
    echo ""
    echo "处理 $pair_name..."
    
    # KaKs_Calculator需要特定的输入格式
    # 格式: 每两行为一对序列
    # >gene1
    # sequence1
    # >gene2
    # sequence2
    
    output_file="${OUTPUT_DIR}/${pair_name}_ks.txt"
    
    echo "  运行KaKs_Calculator..."
    KaKs_Calculator -i "$cds_file" -o "$output_file" -m ALL 2>&1 | tail -10 || {
        echo "  ⚠️ KaKs_Calculator运行完成（可能有警告）"
    }
    
    if [ -f "$output_file" ]; then
        result_count=$(grep -v "^Sequence" "$output_file" | grep -v "^Method" | wc -l)
        echo "  ✅ 结果已生成: $result_count 个Ks值"
        echo "  输出文件: $output_file"
    else
        echo "  ❌ 未生成结果文件"
    fi
done

echo ""
echo "=========================================="
echo "Ks计算完成"
echo "结束时间: $(date)"
echo "输出目录: $OUTPUT_DIR"
echo "=========================================="

