#!/usr/bin/env python3
"""
汇总WGD分析结果
"""

import os
import pandas as pd
import numpy as np

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    output_dir = "/path/to/project_root/comparative_genomics/04_wgd"
    
    print("=" * 60)
    print("WGD分析结果汇总")
    print("=" * 60)
    
    all_results = []
    
    for pair_dir in os.listdir(base_dir):
        pair_path = os.path.join(base_dir, pair_dir)
        if not os.path.isdir(pair_path):
            continue
        
        result_file = os.path.join(pair_path, "ks_results_python.tsv")
        if not os.path.exists(result_file):
            continue
        
        print(f"\n处理 {pair_dir}...")
        df = pd.read_csv(result_file, sep='\t')
        df['Pair'] = pair_dir
        
        # 过滤有效Ks值
        valid_df = df[(df['Success'] == 'Yes') & (df['Ks'] != 'NA')]
        valid_ks = pd.to_numeric(valid_df['Ks'], errors='coerce')
        valid_ks = valid_ks[(valid_ks > 0) & (valid_ks <= 5)]
        
        print(f"  总序列对: {len(df)}")
        print(f"  成功计算: {len(valid_ks)} ({len(valid_ks)/len(df)*100:.1f}%)")
        if len(valid_ks) > 0:
            print(f"  Ks范围: {valid_ks.min():.4f} - {valid_ks.max():.4f}")
            print(f"  Ks平均值: {valid_ks.mean():.4f}")
            print(f"  Ks中位数: {valid_ks.median():.4f}")
            print(f"  Ks标准差: {valid_ks.std():.4f}")
        
        all_results.append(df)
    
    if not all_results:
        print("\n没有找到结果文件")
        return
    
    # 合并所有结果
    combined = pd.concat(all_results, ignore_index=True)
    combined['Ks_numeric'] = pd.to_numeric(combined['Ks'], errors='coerce')
    valid_all = combined[(combined['Success'] == 'Yes') & (combined['Ks_numeric'] > 0) & (combined['Ks_numeric'] <= 5)]
    
    print("\n" + "=" * 60)
    print("总体统计")
    print("=" * 60)
    print(f"总序列对数: {len(combined)}")
    print(f"成功计算: {len(valid_all)} ({len(valid_all)/len(combined)*100:.1f}%)")
    
    if len(valid_all) > 0:
        print(f"\nKs值统计:")
        print(f"  范围: {valid_all['Ks_numeric'].min():.4f} - {valid_all['Ks_numeric'].max():.4f}")
        print(f"  平均值: {valid_all['Ks_numeric'].mean():.4f}")
        print(f"  中位数: {valid_all['Ks_numeric'].median():.4f}")
        print(f"  标准差: {valid_all['Ks_numeric'].std():.4f}")
        
        # 按物种对统计
        print(f"\n按物种对统计:")
        for pair in valid_all['Pair'].unique():
            pair_ks = valid_all[valid_all['Pair'] == pair]['Ks_numeric']
            print(f"  {pair}: {len(pair_ks)}个有效值, 平均Ks={pair_ks.mean():.4f}, 中位数={pair_ks.median():.4f}")
        
        # 保存完整结果
        output_file = os.path.join(output_dir, "ks_all_results.tsv")
        combined.to_csv(output_file, sep='\t', index=False)
        print(f"\n完整结果已保存: {output_file}")
        
        # WGD事件检测（Ks峰值分析）
        print(f"\nWGD事件检测（基于Ks分布）:")
        for pair in valid_all['Pair'].unique():
            pair_ks = valid_all[valid_all['Pair'] == pair]['Ks_numeric']
            # 简单的峰值检测：查找Ks值在0.3-2.0范围内的峰值
            hist, bins = np.histogram(pair_ks[(pair_ks >= 0.3) & (pair_ks <= 2.0)], bins=50)
            peak_idx = np.argmax(hist)
            peak_ks = (bins[peak_idx] + bins[peak_idx+1]) / 2
            print(f"  {pair}: 可能的WGD事件在Ks≈{peak_ks:.4f}附近")
    
    print("\n" + "=" * 60)

if __name__ == '__main__':
    main()

