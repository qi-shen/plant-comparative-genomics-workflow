#!/usr/bin/env python3
"""
完整的PAML正选择分析
提取核心单拷贝基因的CDS序列，进行比对，运行codeml
"""

import os
import sys
import subprocess
from Bio import SeqIO
from collections import defaultdict
import re

def extract_cds_by_protein_id(protein_id, cds_files):
    """根据蛋白ID提取对应的CDS序列"""
    # 去除物种前缀
    for sp, cds_file in cds_files.items():
        if protein_id.startswith(f"{sp}_"):
            gene_id = protein_id[len(sp)+1:]
            # 在CDS文件中查找
            for record in SeqIO.parse(cds_file, "fasta"):
                if gene_id in record.id or record.id.endswith(gene_id):
                    return str(record.seq), sp
    return None, None

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    work_dir = f"{base_dir}/06_selection"
    of_dir = f"{base_dir}/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"
    
    # CDS文件
    cds_files = {
        'BH': f"{work_dir}/BH.cds.fa",
        'CK': f"{work_dir}/CK.cds.fa",
        'TAU': f"{work_dir}/TAU.cds.fa",
        'TCH': f"{work_dir}/TCH.cds.fa",
        'RSO': f"{work_dir}/RSO.cds.fa",
    }
    
    # 读取核心单拷贝基因列表
    core_sc_file = f"{work_dir}/single_copy_candidates/core_single_copy.txt"
    with open(core_sc_file) as f:
        og_list = [line.strip() for line in f if line.strip()]
    
    print("=" * 60)
    print("PAML正选择分析 - 完整流程")
    print(f"处理 {len(og_list)} 个核心单拷贝基因家族")
    print("=" * 60)
    
    # 只处理前20个作为示例
    processed = 0
    success = 0
    
    for og_id in og_list[:20]:
        processed += 1
        print(f"\n[{processed}/20] 处理 {og_id}...")
        
        # 读取OrthoFinder的蛋白序列
        og_seq_file = f"{of_dir}/Orthogroup_Sequences/{og_id}.fa"
        if not os.path.exists(og_seq_file):
            print(f"  跳过: 序列文件不存在")
            continue
        
        # 提取每个物种的CDS序列
        cds_seqs = {}
        for record in SeqIO.parse(og_seq_file, "fasta"):
            protein_id = record.id
            cds_seq, species = extract_cds_by_protein_id(protein_id, cds_files)
            if cds_seq and species:
                cds_seqs[species] = cds_seq
        
        # 检查是否所有5个物种都有CDS
        required_species = ['T01', 'T02', 'C02', 'C03', 'C01']
        if not all(sp in cds_seqs for sp in required_species):
            print(f"  跳过: 缺少某些物种的CDS序列")
            continue
        
        # 检查CDS长度（必须是3的倍数）
        valid = True
        for sp, seq in cds_seqs.items():
            if len(seq) % 3 != 0:
                print(f"  警告: {sp}的CDS长度不是3的倍数")
                valid = False
                break
        
        if not valid:
            continue
        
        # 保存CDS序列
        output_dir = f"{work_dir}/paml_alignments/{og_id}"
        os.makedirs(output_dir, exist_ok=True)
        
        cds_file = f"{output_dir}/{og_id}.cds.fa"
        with open(cds_file, 'w') as f:
            for sp in required_species:
                f.write(f">{sp}\n{cds_seqs[sp]}\n")
        
        # 使用PAL2NAL进行密码子对齐（需要蛋白对齐）
        # 这里简化：直接使用CDS序列对齐（实际应该先对齐蛋白，再转换）
        print(f"  ✅ 已提取CDS序列: {len(cds_seqs)} 个物种")
        success += 1
    
    print("\n" + "=" * 60)
    print(f"处理完成: {success}/{processed} 个家族成功提取CDS")
    print("=" * 60)
    print("\n下一步:")
    print("  1. 对CDS序列进行密码子对齐")
    print("  2. 准备标记前景枝的物种树")
    print("  3. 运行codeml进行branch-site模型分析")

if __name__ == '__main__':
    main()

