#!/usr/bin/env python3
"""
修复PAML分析中的物种名匹配问题
确保phylip文件中的物种名与树文件中的一致
"""

import os
import re

def fix_phylip_species_names(phy_file, tree_file):
    """修复phylip文件中的物种名，使其与树文件匹配"""
    # 读取树文件中的物种名
    with open(tree_file, 'r') as f:
        tree_content = f.read()
    
    # 从树中提取物种名
    species_in_tree = re.findall(r'([A-Z]+):', tree_content)
    species_in_tree = list(set(species_in_tree))
    
    # 读取phylip文件
    with open(phy_file, 'r') as f:
        lines = f.readlines()
    
    if len(lines) < 2:
        return False
    
    # 第一行
    header = lines[0].strip().split()
    n_species = int(header[0])
    seq_len = int(header[1])
    
    # 读取序列
    sequences = {}
    current_species = None
    current_seq = ""
    
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        
        parts = line.split()
        if len(parts) >= 2:
            species_name = parts[0].strip()
            seq_part = ''.join(parts[1:])
            
            # 检查是否是新的物种（名字长度<=10且不在sequences中）
            if len(species_name) <= 10 and species_name not in sequences:
                if current_species:
                    sequences[current_species] = current_seq
                current_species = species_name
                current_seq = seq_part
            else:
                current_seq += seq_part
    
    if current_species:
        sequences[current_species] = current_seq
    
    # 检查物种名是否匹配
    phy_species = list(sequences.keys())
    
    # 如果phylip中的物种名与树中的不匹配，需要映射
    # 假设phylip中的顺序是：CK, TAU, TCH, RSO（缺少BH）
    # 树中的顺序是：BH, CK, TCH, TAU, RSO
    
    # 重新排序和命名
    if 'BH' not in phy_species:
        # 需要添加BH或重命名
        # 检查是否有4个物种
        if len(phy_species) == 4:
            # 假设顺序是CK, TAU, TCH, RSO
            # 但树中需要BH, CK, TCH, TAU, RSO
            # 这里需要从原始CDS文件中重新提取
    
    # 写入修复后的文件
    with open(phy_file, 'w') as f:
        f.write(f"{len(sequences)} {seq_len}\n")
        for species in sorted(sequences.keys()):
            species_name = species[:10].ljust(10)
            f.write(f"{species_name} {sequences[species]}\n")
    
    return True

def main():
    base_dir = "/path/to/project_root/comparative_genomics/06_selection/paml_alignments"
    
    print("=" * 60)
    print("修复PAML物种名匹配问题")
    print("=" * 60)
    
    # 检查第一个文件
    og_dir = os.path.join(base_dir, "OG0006264")
    phy_file = os.path.join(og_dir, "OG0006264.phy")
    tree_file = os.path.join(og_dir, "species_tree_marked.nwk")
    
    if os.path.exists(phy_file) and os.path.exists(tree_file):
        print(f"检查 {og_dir}...")
        with open(phy_file, 'r') as f:
            first_line = f.readline()
            print(f"  phylip首行: {first_line.strip()}")
        
        with open(tree_file, 'r') as f:
            tree_content = f.read()
            print(f"  树文件: {tree_content.strip()}")
        
        # 检查物种
        with open(phy_file, 'r') as f:
            lines = f.readlines()
            species_in_phy = []
            for line in lines[1:6]:  # 前5行
                parts = line.split()
                if parts:
                    species_in_phy.append(parts[0].strip())
            print(f"  phylip中的物种: {species_in_phy}")
        
        import re
        species_in_tree = re.findall(r'([A-Z]+):', tree_content)
        species_in_tree = list(set(species_in_tree))
        print(f"  树中的物种: {species_in_tree}")
        
        # 检查是否匹配
        missing = set(species_in_tree) - set(species_in_phy)
        extra = set(species_in_phy) - set(species_in_tree)
        
        if missing:
            print(f"  ⚠️ 树中有但phylip中缺少: {missing}")
        if extra:
            print(f"  ⚠️ phylip中有但树中缺少: {extra}")
        if not missing and not extra:
            print(f"  ✅ 物种名匹配")

if __name__ == '__main__':
    main()

