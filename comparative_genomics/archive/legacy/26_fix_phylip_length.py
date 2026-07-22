#!/usr/bin/env python3
"""
修复phylip文件中的序列长度不一致问题
"""

import os
from Bio import SeqIO
from Bio.Seq import Seq

def fix_phylip_length(phy_file):
    """修复序列长度，确保所有序列长度一致"""
    # 读取序列
    sequences = {}
    with open(phy_file, 'r') as f:
        lines = f.readlines()
    
    if len(lines) < 2:
        return False
    
    # 第一行是物种数和长度
    header = lines[0].strip().split()
    if len(header) < 2:
        return False
    
    n_species = int(header[0])
    expected_len = int(header[1])
    
    # 读取所有序列
    current_species = None
    current_seq = ""
    
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        
        parts = line.split()
        if len(parts) >= 2:
            # 可能是新物种
            species_name = parts[0]
            seq_part = ''.join(parts[1:])
            
            # 检查是否是新的物种（名字长度<=10且后面有空格）
            if len(species_name) <= 10 and species_name not in sequences:
                if current_species:
                    sequences[current_species] = current_seq
                current_species = species_name
                current_seq = seq_part
            else:
                # 继续当前序列
                current_seq += seq_part
    
    if current_species:
        sequences[current_species] = current_seq
    
    # 找到最大长度
    max_len = max(len(seq) for seq in sequences.values()) if sequences else 0
    
    # 统一所有序列长度（用N补齐）
    for species in sequences:
        seq = sequences[species]
        if len(seq) < max_len:
            sequences[species] = seq + 'N' * (max_len - len(seq))
    
    # 写入文件
    with open(phy_file, 'w') as f:
        f.write(f"{len(sequences)} {max_len}\n")
        for species, seq in sequences.items():
            species_name = species[:10].ljust(10)
            f.write(f"{species_name} {seq}\n")
    
    return True

def main():
    base_dir = "/path/to/project_root/comparative_genomics/06_selection/paml_alignments"
    
    print("=" * 60)
    print("修复phylip文件序列长度")
    print("=" * 60)
    
    fixed_count = 0
    for og_dir in os.listdir(base_dir):
        og_path = os.path.join(base_dir, og_dir)
        if not os.path.isdir(og_path):
            continue
        
        phy_file = os.path.join(og_path, f"{og_dir}.phy")
        if os.path.exists(phy_file):
            print(f"修复 {og_dir}...")
            if fix_phylip_length(phy_file):
                fixed_count += 1
                print(f"  ✅ 已修复")
            else:
                print(f"  ⚠️ 修复失败")
    
    print(f"\n共修复 {fixed_count} 个文件")

if __name__ == '__main__':
    main()

