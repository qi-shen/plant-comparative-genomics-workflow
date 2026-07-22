#!/usr/bin/env python3
"""
重新创建phylip文件，确保包含BH物种
"""

import os
from Bio import SeqIO

def main():
    base_dir = "/path/to/project_root/comparative_genomics/06_selection/paml_alignments"
    
    print("=" * 60)
    print("重新创建phylip文件（包含BH）")
    print("=" * 60)
    
    # 处理每个OG目录
    for og_dir in os.listdir(base_dir):
        og_path = os.path.join(base_dir, og_dir)
        if not os.path.isdir(og_path):
            continue
        
        cds_file = os.path.join(og_path, f"{og_dir}.cds.fa")
        phy_file = os.path.join(og_path, f"{og_dir}.phy")
        
        if not os.path.exists(cds_file):
            continue
        
        print(f"\n处理 {og_dir}...")
        
        # 读取CDS序列
        sequences = {}
        for record in SeqIO.parse(cds_file, "fasta"):
            species = record.id
            sequences[species] = str(record.seq)
        
        # 检查是否有所有5个物种
        required_species = ['T01', 'T02', 'C02', 'C03', 'C01']
        missing = [sp for sp in required_species if sp not in sequences]
        
        if missing:
            print(f"  ⚠️ 缺少物种: {missing}")
            continue
        
        # 检查序列长度（必须是3的倍数）
        all_lengths = [len(seq) for seq in sequences.values()]
        max_len = max(all_lengths)
        
        # 统一长度（用N补齐）
        for species in sequences:
            seq = sequences[species]
            if len(seq) < max_len:
                sequences[species] = seq + 'N' * (max_len - len(seq))
        
        # 写入phylip文件
        with open(phy_file, 'w') as f:
            f.write(f"{len(sequences)} {max_len}\n")
            for species in required_species:
                species_name = species[:10].ljust(10)
                f.write(f"{species_name} {sequences[species]}\n")
        
        print(f"  ✅ 已重新创建phylip文件: {len(sequences)} 个物种, {max_len} bp")

if __name__ == '__main__':
    main()

