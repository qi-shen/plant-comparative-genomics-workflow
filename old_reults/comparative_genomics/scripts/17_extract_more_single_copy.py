#!/usr/bin/env python3
"""
从OrthoFinder结果中提取更多单拷贝同源基因
（用于正选择分析，需要更多基因）
"""

import os
import pandas as pd
from collections import Counter

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    of_dir = f"{base_dir}/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"
    
    # 读取基因家族计数表
    og_counts_file = f"{of_dir}/Orthogroups/Orthogroups.GeneCount.tsv"
    og_counts = pd.read_csv(og_counts_file, sep='\t')
    
    # 物种列
    species_cols = [col for col in og_counts.columns if col not in ['Orthogroup', 'Total']]
    
    print("=" * 60)
    print("提取单拷贝同源基因")
    print("=" * 60)
    
    # 策略1: 严格单拷贝（每个物种恰好1个基因）
    strict_single = og_counts[
        (og_counts[species_cols] == 1).all(axis=1) & 
        (og_counts['Total'] == len(species_cols))
    ]
    print(f"\n严格单拷贝（每个物种恰好1个）: {len(strict_single)} 个家族")
    
    # 策略2: 宽松单拷贝（每个物种最多1个，但允许缺失）
    relaxed_single = og_counts[
        (og_counts[species_cols] <= 1).all(axis=1) &
        (og_counts[species_cols] > 0).sum(axis=1) >= 10  # 至少10个物种存在
    ]
    print(f"宽松单拷贝（每个物种最多1个，至少10个物种）: {len(relaxed_single)} 个家族")
    
    # 策略3: 核心单拷贝（所有物种都存在，每个物种最多2个）
    core_single = og_counts[
        (og_counts[species_cols] > 0).all(axis=1) &
        (og_counts[species_cols] <= 2).all(axis=1) &
        (og_counts['Total'] <= len(species_cols) * 2)
    ]
    print(f"核心单拷贝（所有物种都存在，每个物种最多2个）: {len(core_single)} 个家族")
    
    # 保存结果
    output_dir = f"{base_dir}/06_selection/single_copy_candidates"
    os.makedirs(output_dir, exist_ok=True)
    
    strict_single[['Orthogroup']].to_csv(f"{output_dir}/strict_single_copy.txt", 
                                         index=False, header=False)
    relaxed_single[['Orthogroup']].to_csv(f"{output_dir}/relaxed_single_copy.txt", 
                                         index=False, header=False)
    core_single[['Orthogroup']].to_csv(f"{output_dir}/core_single_copy.txt", 
                                       index=False, header=False)
    
    print(f"\n结果已保存到: {output_dir}")
    print("=" * 60)

if __name__ == '__main__':
    main()

