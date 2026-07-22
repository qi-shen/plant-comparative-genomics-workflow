#!/usr/bin/env python3
"""
汇总所有分析结果
生成最终的分析总结
"""

import os
import glob
from datetime import datetime

def get_file_size(filepath):
    """获取文件大小"""
    if os.path.exists(filepath):
        size = os.path.getsize(filepath)
        if size < 1024:
            return f"{size} B"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB"
        elif size < 1024 * 1024 * 1024:
            return f"{size / (1024 * 1024):.1f} MB"
        else:
            return f"{size / (1024 * 1024 * 1024):.1f} GB"
    return "N/A"

def main():
    base_dir = "${PROJECT_ROOT}/comparative_genomics"
    
    print("=" * 80)
    print("比较基因组分析 - 完整结果汇总")
    print(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)
    
    # 1. OrthoFinder结果
    print("\n1. OrthoFinder基因家族分析")
    print("-" * 80)
    of_dir = f"{base_dir}/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"
    og_file = f"{of_dir}/Orthogroups/Orthogroups.GeneCount.tsv"
    tree_file = f"{of_dir}/Species_Tree/SpeciesTree_rooted.txt"
    
    if os.path.exists(og_file):
        print(f"  ✅ 基因家族文件: {get_file_size(og_file)}")
        # 统计家族数
        with open(og_file, 'r') as f:
            lines = [l for l in f if l.strip() and not l.startswith('#')]
            print(f"  ✅ 基因家族数: {len(lines) - 1}")  # 减去表头
    
    if os.path.exists(tree_file):
        print(f"  ✅ 物种树: {get_file_size(tree_file)}")
    
    # 2. 共线性分析
    print("\n2. 共线性分析")
    print("-" * 80)
    synteny_dir = f"{base_dir}/05_synteny/jcvi_analysis"
    dotplot_files = glob.glob(f"{synteny_dir}/*.pdf")
    anchor_files = glob.glob(f"{synteny_dir}/*.anchors")
    
    print(f"  ✅ 共线性点图: {len(dotplot_files)} 个")
    print(f"  ✅ 共线性区块文件: {len(anchor_files)} 个")
    
    # 统计同源基因对
    total_pairs = 0
    for anchor_file in anchor_files:
        with open(anchor_file, 'r') as f:
            lines = [l for l in f if l.strip() and not l.startswith('#')]
            total_pairs += len(lines)
    print(f"  ✅ 同源基因对总数: {total_pairs:,}")
    
    # 3. CAFE分析
    print("\n3. CAFE基因家族动态分析")
    print("-" * 80)
    cafe_dir = f"{base_dir}/07_cafe"
    significant_file = f"{cafe_dir}/significant_families.tsv"
    cafe_results_dir = f"{cafe_dir}/cafe_results"
    
    if os.path.exists(significant_file):
        with open(significant_file, 'r') as f:
            lines = [l for l in f if l.strip()]
            print(f"  ✅ 显著变化家族: {len(lines) - 1} 个")  # 减去表头
        print(f"  ✅ 结果文件: {get_file_size(significant_file)}")
    
    if os.path.exists(cafe_results_dir):
        result_files = glob.glob(f"{cafe_results_dir}/*")
        print(f"  ✅ CAFE结果文件: {len(result_files)} 个")
    
    # 4. PAML分析
    print("\n4. PAML正选择分析")
    print("-" * 80)
    paml_dir = f"{base_dir}/06_selection/paml_alignments"
    mlc_files = glob.glob(f"{paml_dir}/OG*/mlc")
    print(f"  ✅ 已完成分析: {len(mlc_files)} 个家族")
    
    og_dirs = glob.glob(f"{paml_dir}/OG*")
    print(f"  ✅ 准备分析: {len(og_dirs)} 个家族")
    
    # 5. 数据准备
    print("\n5. 数据准备")
    print("-" * 80)
    proteomes_dir = f"{base_dir}/01_proteomes/filtered"
    if os.path.exists(proteomes_dir):
        fa_files = glob.glob(f"{proteomes_dir}/*.fa")
        print(f"  ✅ 蛋白质序列文件: {len(fa_files)} 个物种")
        
        total_size = sum(os.path.getsize(f) for f in fa_files)
        print(f"  ✅ 总大小: {get_file_size(proteomes_dir)}")
    
    # 总结
    print("\n" + "=" * 80)
    print("分析完成度总结")
    print("=" * 80)
    
    completed = 0
    total = 7
    
    if os.path.exists(og_file):
        completed += 1
        print("✅ OrthoFinder基因家族分析")
    else:
        print("⏳ OrthoFinder基因家族分析")
    
    if len(dotplot_files) > 0:
        completed += 1
        print("✅ 共线性分析")
    else:
        print("⏳ 共线性分析")
    
    if os.path.exists(tree_file):
        completed += 1
        print("✅ 系统发育分析")
    else:
        print("⏳ 系统发育分析")
    
    if os.path.exists(significant_file):
        completed += 1
        print("✅ CAFE基因家族动态分析")
    else:
        print("⏳ CAFE基因家族动态分析")
    
    if len(mlc_files) > 0:
        completed += 1
        print(f"🔄 PAML正选择分析 ({len(mlc_files)}/{len(og_dirs)} 完成)")
    else:
        print("⏳ PAML正选择分析")
    
    print("⏳ WGD分析")
    print("⏳ 可视化")
    
    completion_rate = (completed / total) * 100
    print(f"\n总体完成度: {completion_rate:.0f}% ({completed}/{total})")
    
    print("\n" + "=" * 80)
    print("汇总完成")
    print("=" * 80)

if __name__ == '__main__':
    main()

