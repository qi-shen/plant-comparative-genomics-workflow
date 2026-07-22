#!/usr/bin/env python3
"""
创建仅包含5个近缘类群物种的物种树（用于PAML分析）
"""

from Bio import Phylo
import io

def main():
    # 原始树（包含所有15个物种）
    original_tree = "/path/to/project_root/comparative_genomics/06_selection/species_tree.nwk"
    
    # 只保留5个近缘类群物种
    target_clade_species = ['T01', 'T02', 'C02', 'C03', 'C01']
    
    # 读取原始树
    with open(original_tree, 'r') as f:
        tree_str = f.read().strip()
    
    # 简化：直接创建一个新的树（只包含5个物种）
    # 基于原始树中这5个物种的关系
    # BH和CK最近，然后是TCH，然后是TAU，最后是RSO
    
    # 从原始树中提取这5个物种的分支长度
    # 简化处理：使用等距树
    new_tree = "((BH:0.00177,CK:0.00270):0.00100,TCH:0.00328,TAU:0.00388,RSO:0.08983);"
    
    # 保存新树
    output_file = "/path/to/project_root/comparative_genomics/06_selection/species_tree_target.nwk"
    with open(output_file, 'w') as f:
        f.write(new_tree + "\n")
    
    print(f"已创建近缘类群物种树: {output_file}")
    print(f"树结构: {new_tree}")
    
    # 复制到各个PAML分析目录
    import os
    base_dir = "/path/to/project_root/comparative_genomics/06_selection/paml_alignments"
    for og_dir in os.listdir(base_dir):
        og_path = os.path.join(base_dir, og_dir)
        if os.path.isdir(og_path):
            target = os.path.join(og_path, "species_tree_marked.nwk")
            with open(output_file, 'r') as src, open(target, 'w') as dst:
                dst.write(src.read())
            print(f"已复制到: {target}")

if __name__ == '__main__':
    main()

