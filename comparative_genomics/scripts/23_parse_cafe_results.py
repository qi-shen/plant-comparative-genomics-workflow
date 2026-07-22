#!/usr/bin/env python3
"""
解析CAFE分析结果
识别显著扩张/收缩的基因家族
"""

import pandas as pd
import os

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    cafe_dir = f"{base_dir}/07_cafe/cafe_results"
    
    print("=" * 60)
    print("解析CAFE分析结果")
    print("=" * 60)
    
    # 读取家族变化结果
    family_results_file = f"{cafe_dir}/Base_family_results.txt"
    change_file = f"{cafe_dir}/Base_change.tab"
    
    if not os.path.exists(family_results_file):
        print(f"错误: 文件不存在 {family_results_file}")
        return
    
    # 读取显著性结果
    print("\n读取家族显著性结果...")
    # 手动读取，因为列名可能有问题
    with open(family_results_file, 'r') as f:
        header = f.readline().strip()
        print(f"文件头: {header}")
    
    # 重新读取，指定列名
    family_results = pd.read_csv(family_results_file, sep='\t', comment='#', 
                                  names=['FamilyID', 'pvalue', 'Significant'], skiprows=1)
    
    print(f"列名: {list(family_results.columns)}")
    print(f"总家族数: {len(family_results)}")
    
    # 筛选显著变化的家族
    if 'Significant' in family_results.columns:
        significant = family_results[family_results['Significant'] == 'y']
    elif 'pvalue' in family_results.columns:
        significant = family_results[family_results['pvalue'] < 0.05]
    else:
        print("警告: 无法找到显著性列，使用所有家族")
        significant = family_results
    
    print(f"显著变化的家族数: {len(significant)}")
    
    # 读取家族变化详情
    if os.path.exists(change_file):
        print("\n读取家族变化详情...")
        change_data = pd.read_csv(change_file, sep='\t')
        
        # 合并数据
        merged = significant.merge(change_data, left_on='FamilyID', right_on='FamilyID', how='left')
        
        # 分析近缘类群物种的变化（BH, CK, TAU, TCH, RSO）
        target_clade_species = ['T01', 'T02', 'C02', 'C03', 'C01']
        
        print("\n近缘类群物种的家族变化统计:")
        for sp in target_clade_species:
            if sp in merged.columns:
                expanded = (merged[sp] > 0).sum()
                contracted = (merged[sp] < 0).sum()
                print(f"  {sp}: 扩张 {expanded} 个, 收缩 {contracted} 个")
        
        # 保存显著变化的家族
        output_file = f"{base_dir}/07_cafe/significant_families.tsv"
        merged.to_csv(output_file, sep='\t', index=False)
        print(f"\n显著变化的家族已保存到: {output_file}")
        
        # 显示前10个显著变化的家族
        print("\n前10个显著变化的家族:")
        display_cols = ['FamilyID', 'pvalue']
        available_target = [sp for sp in target_clade_species if sp in merged.columns]
        display_cols.extend(available_target)
        print(merged[display_cols].head(10).to_string(index=False))
    
    # 读取CAFE报告
    report_file = f"{cafe_dir}/Base_report.cafe"
    if os.path.exists(report_file):
        print("\n" + "=" * 60)
        print("CAFE分析摘要:")
        print("=" * 60)
        with open(report_file, 'r') as f:
            lines = f.readlines()
            for i, line in enumerate(lines[:30]):  # 显示前30行
                print(line.rstrip())
    
    print("\n" + "=" * 60)
    print("CAFE结果解析完成")
    print("=" * 60)

if __name__ == '__main__':
    main()

