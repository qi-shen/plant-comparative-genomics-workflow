#!/usr/bin/env python3
"""
分析CAFE显著变化家族的功能
"""

import os
import pandas as pd
from collections import defaultdict

def load_orthofinder_results():
    """加载OrthoFinder结果"""
    ortho_dir = "${PROJECT_ROOT}/comparative_genomics/02_orthofinder"
    
    if not os.path.exists(ortho_dir):
        return None
    
    # 查找OrthoFinder结果目录
    try:
        results_dirs = [d for d in os.listdir(ortho_dir) if d.startswith("Results_")]
        if not results_dirs:
            return None
        
        results_dir = os.path.join(ortho_dir, results_dirs[0])
        
        # 读取基因家族文件
        families_file = os.path.join(results_dir, "Orthogroups", "Orthogroups.tsv")
        if not os.path.exists(families_file):
            return None
    except:
        return None
    
    print(f"读取OrthoFinder结果: {families_file}")
    families_df = pd.read_csv(families_file, sep='\t')
    
    # 创建家族ID到基因的映射
    family_to_genes = {}
    for idx, row in families_df.iterrows():
        family_id = row['Orthogroup']
        genes = []
        for col in families_df.columns[1:]:
            gene_list = str(row[col])
            if gene_list != 'nan' and gene_list.strip():
                genes.extend([g.strip() for g in gene_list.split(', ') if g.strip()])
        family_to_genes[family_id] = genes
    
    return family_to_genes

def analyze_cafe_families():
    """分析CAFE显著变化家族"""
    cafe_dir = "${PROJECT_ROOT}/comparative_genomics/07_cafe"
    output_dir = "${PROJECT_ROOT}/comparative_genomics/07_cafe"
    
    # 读取显著家族
    sig_file = os.path.join(cafe_dir, "significant_families.tsv")
    if not os.path.exists(sig_file):
        print(f"文件不存在: {sig_file}")
        return
    
    print("=" * 60)
    print("分析CAFE显著变化家族")
    print("=" * 60)
    
    sig_df = pd.read_csv(sig_file, sep='\t')
    print(f"\n显著变化家族总数: {len(sig_df)}")
    
    # 读取详细分析结果
    detailed_file = os.path.join(cafe_dir, "cafe_detailed_analysis.tsv")
    if os.path.exists(detailed_file):
        detailed_df = pd.read_csv(detailed_file, sep='\t')
        print(f"详细分析结果: {len(detailed_df)} 个家族")
        
        # 合并数据
        merged_df = sig_df.merge(detailed_df, on='FamilyID', how='left', suffixes=('', '_detail'))
    else:
        merged_df = sig_df
    
    # 按物种统计扩张/收缩
    print("\n按物种统计显著变化家族:")
    
    target_clade_species = ['T01', 'T02', 'C02', 'C03', 'C01']
    
    for species in target_clade_species:
        # 查找扩张列
        expand_col = None
        contract_col = None
        
        for col in merged_df.columns:
            if species.lower() in col.lower() or species in col:
                if 'expand' in col.lower() or 'gain' in col.lower() or '+' in col:
                    expand_col = col
                elif 'contract' in col.lower() or 'loss' in col.lower() or '-' in col:
                    contract_col = col
        
        if expand_col and expand_col in merged_df.columns:
            expanded = merged_df[merged_df[expand_col] > 0]
            print(f"  {species} 扩张: {len(expanded)} 个家族")
        
        if contract_col and contract_col in merged_df.columns:
            contracted = merged_df[merged_df[contract_col] < 0]
            print(f"  {species} 收缩: {len(contracted)} 个家族")
    
    # 统计C03扩张家族
    c03_expand_cols = [col for col in merged_df.columns if 'c03' in col.lower() and ('expand' in col.lower() or 'gain' in col.lower() or '+' in col)]
    if c03_expand_cols:
        c03_expand_col = c03_expand_cols[0]
        c03_expanded = merged_df[merged_df[c03_expand_col] > 0]
        print(f"\nC03显著扩张家族: {len(c03_expanded)} 个")
        
        # 保存C03扩张家族列表
        c03_output = os.path.join(output_dir, "c03_expanded_families.tsv")
        c03_expanded.to_csv(c03_output, sep='\t', index=False)
        print(f"C03扩张家族列表已保存: {c03_output}")
    
    # 按变化类型分类
    print("\n按变化类型分类:")
    
    # 查找变化相关的列
    change_cols = [col for col in merged_df.columns if 'change' in col.lower() or 'delta' in col.lower()]
    
    if change_cols:
        for col in change_cols[:3]:  # 只显示前3个
            print(f"  列: {col}")
            if merged_df[col].dtype in ['int64', 'float64']:
                print(f"    正值: {(merged_df[col] > 0).sum()}")
                print(f"    负值: {(merged_df[col] < 0).sum()}")
                print(f"    零值: {(merged_df[col] == 0).sum()}")
    
    # 保存分析结果
    analysis_output = os.path.join(output_dir, "cafe_families_analysis.tsv")
    merged_df.to_csv(analysis_output, sep='\t', index=False)
    print(f"\n分析结果已保存: {analysis_output}")
    
    # 生成汇总报告
    summary = {
        'Total_Significant_Families': len(merged_df),
        'Families_Analyzed': len(merged_df)
    }
    
    # 尝试加载OrthoFinder结果以获取基因信息
    family_to_genes = load_orthofinder_results()
    if family_to_genes:
        print("\n关联OrthoFinder基因家族信息...")
        gene_counts = []
        for family_id in merged_df['FamilyID'].head(100):  # 只检查前100个
            if family_id in family_to_genes:
                gene_counts.append(len(family_to_genes[family_id]))
        
        if gene_counts:
            print(f"  平均每个家族基因数: {sum(gene_counts)/len(gene_counts):.1f}")
            print(f"  基因数范围: {min(gene_counts)} - {max(gene_counts)}")
    
    print("\n" + "=" * 60)
    print("CAFE家族分析完成")
    print("=" * 60)

if __name__ == '__main__':
    analyze_cafe_families()

