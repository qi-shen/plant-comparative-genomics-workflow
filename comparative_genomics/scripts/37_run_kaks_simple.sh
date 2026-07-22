#!/bin/bash
# 使用Python实现简单的Ks计算（如果KaKs_Calculator不可用）
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/04_wgd/ks_from_synteny"
OUTPUT_DIR="$BASE_DIR/comparative_genomics/04_wgd/ks_results"

echo "=========================================="
echo "计算Ks值（使用Biopython）"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

mkdir -p "$OUTPUT_DIR"

# 使用Python脚本计算Ks
python3 << 'PYTHON_SCRIPT'
import os
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.Align import PairwiseAligner
import numpy as np

def calculate_ks_simple(seq1, seq2):
    """简单计算Ks值（使用4-fold degenerate sites）"""
    # 这里使用简化的方法
    # 实际应该使用专门的Ks计算工具
    # 这里只是示例，实际应该使用KaKs_Calculator或PAML
    
    # 检查序列长度
    if len(seq1) != len(seq2) or len(seq1) % 3 != 0:
        return None
    
    # 计算4-fold degenerate sites的差异
    # 简化处理：计算同义替换率
    # 实际应该使用密码子模型
    
    # 这里返回占位符，实际需要专门的工具
    return None

def process_pairs(input_file, output_file):
    """处理序列对并计算Ks"""
    pairs = []
    current_pair = []
    
    with open(input_file, 'r') as f:
        for record in SeqIO.parse(f, "fasta"):
            current_pair.append(str(record.seq))
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
    
    print(f"  处理 {len(pairs)} 对序列...")
    print("  注意: 完整Ks计算需要使用KaKs_Calculator或PAML")
    print("  这里只统计序列对数量")
    
    # 保存统计信息
    with open(output_file, 'w') as f:
        f.write("Gene1\tGene2\tLength1\tLength2\n")
        for i, (seq1, seq2) in enumerate(pairs):
            f.write(f"Pair{i+1}\tPair{i+1}\t{len(seq1)}\t{len(seq2)}\n")
    
    return len(pairs)

# 主程序
base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
output_base = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"

total_pairs = 0
for pair_dir in os.listdir(base_dir):
    pair_path = os.path.join(base_dir, pair_dir)
    if not os.path.isdir(pair_path):
        continue
    
    input_file = os.path.join(pair_path, "kaks_input.fa")
    if not os.path.exists(input_file):
        input_file = os.path.join(pair_path, "cds_pairs.fa")
    
    if not os.path.exists(input_file):
        continue
    
    print(f"\n处理 {pair_dir}...")
    output_file = os.path.join(output_base, f"{pair_dir}_ks_stats.txt")
    count = process_pairs(input_file, output_file)
    total_pairs += count
    print(f"  统计完成: {count} 对序列")

print(f"\n总计: {total_pairs} 对序列")
print("\n注意: 实际Ks计算需要使用KaKs_Calculator或PAML")
PYTHON_SCRIPT

echo ""
echo "=========================================="
echo "Ks计算准备完成"
echo "结束时间: $(date)"
echo "=========================================="
echo ""
echo "注意: 完整Ks计算需要使用KaKs_Calculator"
echo "建议: 安装KaKs_Calculator或使用PAML codeml"

