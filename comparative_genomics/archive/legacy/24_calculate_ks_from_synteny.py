#!/usr/bin/env python3
"""
从共线性分析结果计算Ks值（WGD分析替代方案）
使用JCVI anchors文件中的同源基因对
"""

import os
import subprocess
from Bio import SeqIO
from collections import defaultdict

def calculate_ks_pairwise(cds1, cds2, gene1_id, gene2_id):
    """计算两个CDS序列的Ks值"""
    # 使用KaKs_Calculator或其他工具
    # 这里简化处理，实际需要使用KaKs_Calculator
    return None

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    synteny_dir = f"{base_dir}/05_synteny/jcvi_analysis"
    jcvi_data_dir = f"{base_dir}/05_synteny/jcvi_data"
    
    print("=" * 60)
    print("从共线性分析计算Ks值（WGD分析替代方案）")
    print("=" * 60)
    
    # 读取anchors文件
    anchors_files = [
        f"{synteny_dir}/T01.T02.anchors",
        f"{synteny_dir}/T01.C02.anchors",
        f"{synteny_dir}/T02.C02.anchors",
    ]
    
    # 读取CDS文件
    cds_files = {
        'T01': f"{jcvi_data_dir}/T01.cds",
        'T02': f"{jcvi_data_dir}/T02.cds",
        'C02': f"{jcvi_data_dir}/C02.cds",
    }
    
    # 检查文件是否存在
    for f in anchors_files + list(cds_files.values()):
        if not os.path.exists(f):
            print(f"警告: 文件不存在 {f}")
    
    # 统计同源基因对数量
    print("\n同源基因对统计:")
    for anchors_file in anchors_files:
        if os.path.exists(anchors_file):
            with open(anchors_file, 'r') as f:
                lines = [l for l in f if not l.startswith('#') and l.strip()]
                print(f"  {os.path.basename(anchors_file)}: {len(lines)} 对")
    
    print("\n" + "=" * 60)
    print("注意: 需要安装KaKs_Calculator来计算Ks值")
    print("安装: conda install -c bioconda kaks-calculator")
    print("=" * 60)
    
    # 创建Ks计算脚本模板
    output_script = f"{base_dir}/04_wgd/calculate_ks_from_synteny.sh"
    with open(output_script, 'w') as f:
        f.write("""#!/bin/bash
# 从共线性结果计算Ks值
# 需要先安装: conda install -c bioconda kaks-calculator

BASE_DIR="/path/to/project_root/comparative_genomics"
SYNTENY_DIR="$BASE_DIR/05_synteny/jcvi_analysis"
CDS_DIR="$BASE_DIR/05_synteny/jcvi_data"
OUTPUT_DIR="$BASE_DIR/04_wgd/ks_from_synteny"

mkdir -p "$OUTPUT_DIR"

# 对每个anchors文件计算Ks
for anchors_file in "$SYNTENY_DIR"/*.anchors; do
    species_pair=$(basename "$anchors_file" .anchors)
    echo "处理 $species_pair..."
    
    # 提取同源基因对并计算Ks
    # 这里需要根据KaKs_Calculator的格式准备输入
done

echo "Ks计算完成，结果在: $OUTPUT_DIR"
""")
    
    os.chmod(output_script, 0o755)
    print(f"\nKs计算脚本模板已创建: {output_script}")

if __name__ == '__main__':
    main()

