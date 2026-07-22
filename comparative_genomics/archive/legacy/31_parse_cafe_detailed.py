#!/usr/bin/env python3
"""
详细解析CAFE分析结果
分析994个显著变化的基因家族
"""

import pandas as pd
import os

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    cafe_dir = f"{base_dir}/07_cafe"
    significant_file = f"{cafe_dir}/significant_families.tsv"
    change_file = f"{cafe_dir}/cafe_results/Base_change.tab"
    family_results_file = f"{cafe_dir}/cafe_results/Base_family_results.txt"
    
    print("=" * 60)
    print("详细解析CAFE分析结果")
    print("=" * 60)
    
    # 读取显著变化的家族
    if not os.path.exists(significant_file):
        print(f"错误: 文件不存在 {significant_file}")
        return
    
    significant = pd.read_csv(significant_file, sep='\t')
    print(f"\n显著变化的家族数: {len(significant)}")
    print(f"列名: {list(significant.columns)}")
    
    # 近缘类群物种（注意列名格式可能是 'BH<8>', 'CK<7>' 等）
    target_clade_species_map = {
        'BH': ['BH<8>', 'BH'],
        'CK': ['CK<7>', 'CK'],
        'TAU': ['TAU<5>', 'TAU'],
        'TCH': ['TCH<6>', 'TCH'],
        'RSO': ['RSO<4>', 'RSO']
    }
    
    # 找到实际存在的列名
    available_species = {}
    for sp, possible_names in target_clade_species_map.items():
        for name in possible_names:
            if name in significant.columns:
                available_species[sp] = name
                break
    
    print(f"可用的物种列: {available_species}")
    
    # 分析每个物种的家族变化
    if available_species:
        print("\n" + "=" * 60)
        print("近缘类群物种的家族变化统计")
        print("=" * 60)
        
        for sp, col_name in available_species.items():
            expanded = (significant[col_name] > 0).sum()
            contracted = (significant[col_name] < 0).sum()
            unchanged = (significant[col_name] == 0).sum()
            total_change = significant[col_name].sum()
            
            print(f"\n{sp}:")
            print(f"  扩张: {expanded} 个家族")
            print(f"  收缩: {contracted} 个家族")
            print(f"  不变: {unchanged} 个家族")
            print(f"  净变化: {total_change:+.0f} 个基因")
    
    # 找出变化最大的家族
    print("\n" + "=" * 60)
    print("变化最大的家族（前20个）")
    print("=" * 60)
    
    # 计算总变化量（使用实际存在的列名）
    if available_species:
        species_cols = list(available_species.values())
        significant['Total_Change'] = significant[species_cols].sum(axis=1)
        significant['Max_Change'] = significant[species_cols].abs().max(axis=1)
        
        # 按总变化量排序
        top_changed = significant.nlargest(20, 'Total_Change', keep='all')
        
        print("\n总变化最大的家族:")
        display_cols = ['FamilyID', 'Total_Change'] + species_cols
        print(top_changed[display_cols].to_string(index=False))
        
        # 保存详细结果
        output_file = f"{cafe_dir}/cafe_detailed_analysis.tsv"
        significant.to_csv(output_file, sep='\t', index=False)
        print(f"\n详细分析结果已保存到: {output_file}")
    
    # 统计信息
    print("\n" + "=" * 60)
    print("统计摘要")
    print("=" * 60)
    print(f"显著变化家族总数: {len(significant)}")
    print(f"分析物种数: {len(available_species)}")
    
    # 读取CAFE报告摘要
    report_file = f"{cafe_dir}/cafe_results/Base_results.txt"
    if os.path.exists(report_file):
        print("\nCAFE分析参数:")
        with open(report_file, 'r') as f:
            for line in f:
                print(f"  {line.strip()}")

if __name__ == '__main__':
    main()

