#!/usr/bin/env python3
"""
汇总比较基因组分析结果
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
        elif size < 1024*1024:
            return f"{size/1024:.1f} KB"
        elif size < 1024*1024*1024:
            return f"{size/(1024*1024):.1f} MB"
        else:
            return f"{size/(1024*1024*1024):.1f} GB"
    return "不存在"

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    
    print("=" * 70)
    print("比较基因组分析结果汇总")
    print(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    # 1. OrthoFinder结果
    print("\n1. OrthoFinder基因家族分析")
    print("-" * 70)
    of_dir = f"{base_dir}/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"
    
    if os.path.exists(f"{of_dir}/Orthogroups/Orthogroups.tsv"):
        print(f"  ✅ 基因家族文件: {get_file_size(f'{of_dir}/Orthogroups/Orthogroups.tsv')}")
    
    if os.path.exists(f"{of_dir}/Species_Tree/SpeciesTree_rooted.txt"):
        print(f"  ✅ 物种树: {get_file_size(f'{of_dir}/Species_Tree/SpeciesTree_rooted.txt')}")
        with open(f"{of_dir}/Species_Tree/SpeciesTree_rooted.txt") as f:
            tree = f.read().strip()
            print(f"  树结构: {tree[:100]}...")
    
    sc_count = len(glob.glob(f"{of_dir}/Single_Copy_Orthologue_Sequences/*.fa"))
    print(f"  ✅ 单拷贝基因家族: {sc_count} 个")
    
    # 2. 共线性分析
    print("\n2. 共线性分析")
    print("-" * 70)
    synteny_dir = f"{base_dir}/05_synteny/jcvi_analysis"
    pdf_files = glob.glob(f"{synteny_dir}/*.pdf")
    print(f"  ✅ 共线性点图: {len(pdf_files)} 个")
    for pdf in pdf_files[:5]:
        name = os.path.basename(pdf)
        print(f"    - {name}: {get_file_size(pdf)}")
    
    anchors_files = glob.glob(f"{synteny_dir}/*.anchors")
    print(f"  ✅ 共线性区块文件: {len(anchors_files)} 个")
    
    # 3. 系统发育分析
    print("\n3. 系统发育分析")
    print("-" * 70)
    phylo_dir = f"{base_dir}/03_phylogeny"
    if os.path.exists(f"{phylo_dir}/orthofinder_species_tree.nwk"):
        print(f"  ✅ OrthoFinder物种树: {get_file_size(f'{phylo_dir}/orthofinder_species_tree.nwk')}")
    
    align_count = len(glob.glob(f"{phylo_dir}/alignments/*.aln"))
    print(f"  ✅ 多序列比对: {align_count} 个")
    
    # 4. CAFE分析
    print("\n4. CAFE基因家族动态分析")
    print("-" * 70)
    cafe_dir = f"{base_dir}/07_cafe"
    if os.path.exists(f"{cafe_dir}/gene_families.tsv"):
        print(f"  ✅ 输入文件: {get_file_size(f'{cafe_dir}/gene_families.tsv')}")
    
    cafe_results = glob.glob(f"{cafe_dir}/cafe_results/*")
    if cafe_results:
        print(f"  ✅ 结果文件: {len(cafe_results)} 个")
        for f in cafe_results[:5]:
            name = os.path.basename(f)
            print(f"    - {name}: {get_file_size(f)}")
    else:
        print("  ⏳ CAFE分析进行中...")
    
    # 5. WGD分析
    print("\n5. WGD分析")
    print("-" * 70)
    wgd_dir = f"{base_dir}/04_wgd"
    wgd_files = glob.glob(f"{wgd_dir}/**/*.tsv", recursive=True) + \
                glob.glob(f"{wgd_dir}/**/*.pdf", recursive=True)
    if wgd_files:
        print(f"  ✅ WGD结果文件: {len(wgd_files)} 个")
    else:
        print("  ⏳ WGD分析待进行")
    
    # 6. 数据准备
    print("\n6. 数据准备")
    print("-" * 70)
    proteome_dir = f"{base_dir}/01_proteomes/filtered"
    proteome_files = glob.glob(f"{proteome_dir}/*.fa")
    print(f"  ✅ 蛋白质序列文件: {len(proteome_files)} 个物种")
    total_size = sum(os.path.getsize(f) for f in proteome_files)
    print(f"  总大小: {total_size/(1024*1024):.1f} MB")
    
    print("\n" + "=" * 70)
    print("汇总完成")
    print("=" * 70)

if __name__ == '__main__':
    main()

