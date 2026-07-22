#!/usr/bin/env python3
"""
汇总Ks计算结果并生成Ks分布图
"""

import os
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')  # 非交互式后端
import matplotlib.pyplot as plt

def collect_ks_results(results_dir):
    """收集所有Ks结果"""
    all_results = []
    
    for pair_dir in os.listdir(results_dir):
        pair_path = os.path.join(results_dir, pair_dir)
        if not os.path.isdir(pair_path):
            continue
        
        result_file = os.path.join(pair_path, "ks_results.tsv")
        if not os.path.exists(result_file):
            continue
        
        try:
            df = pd.read_csv(result_file, sep='\t')
            df['Pair'] = pair_dir
            all_results.append(df)
        except:
            continue
    
    if not all_results:
        return None
    
    combined = pd.concat(all_results, ignore_index=True)
    return combined

def plot_ks_distribution(df, output_file):
    """绘制Ks分布图"""
    # 过滤有效Ks值
    valid_ks = df[df['Ks'] != 'NA']['Ks'].astype(float)
    valid_ks = valid_ks[(valid_ks > 0) & (valid_ks <= 5)]  # 合理范围
    
    if len(valid_ks) == 0:
        print("  没有有效的Ks值用于绘图")
        return False
    
    fig, axes = plt.subplots(2, 1, figsize=(10, 8))
    
    # 整体分布
    axes[0].hist(valid_ks, bins=50, edgecolor='black', alpha=0.7)
    axes[0].set_xlabel('Ks (synonymous substitution rate)')
    axes[0].set_ylabel('Frequency')
    axes[0].set_title('Ks Distribution (All Pairs)')
    axes[0].grid(False)
    
    # 按物种对分组
    for pair in df['Pair'].unique():
        pair_ks = df[(df['Pair'] == pair) & (df['Ks'] != 'NA')]['Ks'].astype(float)
        pair_ks = pair_ks[(pair_ks > 0) & (pair_ks <= 5)]
        if len(pair_ks) > 0:
            axes[1].hist(pair_ks, bins=30, alpha=0.6, label=pair, edgecolor='black')
    
    axes[1].set_xlabel('Ks (synonymous substitution rate)')
    axes[1].set_ylabel('Frequency')
    axes[1].set_title('Ks Distribution by Species Pair')
    axes[1].legend()
    axes[1].grid(False)
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    return True

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    output_dir = "/path/to/project_root/comparative_genomics/04_wgd"
    
    print("=" * 60)
    print("汇总Ks计算结果")
    print("=" * 60)
    
    # 收集结果
    df = collect_ks_results(base_dir)
    
    if df is None or len(df) == 0:
        print("没有找到Ks结果文件")
        return
    
    print(f"\n总序列对数: {len(df)}")
    print(f"成功计算: {len(df[df['Success'] == 'Yes'])}")
    print(f"失败: {len(df[df['Success'] == 'No'])}")
    
    # 统计有效Ks值
    valid_ks = df[df['Ks'] != 'NA']['Ks'].astype(float)
    valid_ks = valid_ks[(valid_ks > 0) & (valid_ks <= 5)]
    
    if len(valid_ks) > 0:
        print(f"\n有效Ks值: {len(valid_ks)}")
        print(f"Ks范围: {valid_ks.min():.4f} - {valid_ks.max():.4f}")
        print(f"Ks平均值: {valid_ks.mean():.4f}")
        print(f"Ks中位数: {valid_ks.median():.4f}")
        
        # 保存汇总结果
        summary_file = os.path.join(output_dir, "ks_summary.tsv")
        df.to_csv(summary_file, sep='\t', index=False)
        print(f"\n汇总结果已保存: {summary_file}")
        
        # 绘制分布图
        plot_file = os.path.join(output_dir, "ks_distribution.pdf")
        if plot_ks_distribution(df, plot_file):
            print(f"Ks分布图已保存: {plot_file}")
    else:
        print("\n警告: 没有有效的Ks值")
        print("可能原因:")
        print("  1. codeml运行失败")
        print("  2. 序列格式问题")
        print("  3. 需要检查codeml输出文件")
    
    print("\n" + "=" * 60)

if __name__ == '__main__':
    main()

