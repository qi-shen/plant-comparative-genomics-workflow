#!/usr/bin/env python3
"""
修复phylip格式文件，确保符合PAML要求
"""

import os
import sys

def fix_phylip_file(phy_file):
    """修复phylip文件格式"""
    with open(phy_file, 'r') as f:
        lines = [l.strip() for l in f if l.strip()]
    
    if not lines:
        return False
    
    # 第一行应该是物种数和序列长度
    first_line = lines[0].split()
    if len(first_line) >= 2:
        try:
            n_species = int(first_line[0])
            seq_len = int(first_line[1])
        except:
            # 重新计算
            n_species = 0
            seq_len = 0
            for i, line in enumerate(lines[1:], 1):
                parts = line.split()
                if len(parts) >= 2:
                    n_species += 1
                    if seq_len == 0:
                        seq_len = len(''.join(parts[1:]))
    else:
        return False
    
    # 重新格式化
    output_lines = [f"{n_species} {seq_len}"]
    
    for i in range(1, len(lines)):
        line = lines[i]
        parts = line.split()
        if len(parts) >= 2:
            species_name = parts[0][:10].ljust(10)  # 最多10个字符
            sequence = ''.join(parts[1:])
            output_lines.append(f"{species_name} {sequence}")
    
    # 写入文件
    with open(phy_file, 'w') as f:
        f.write('\n'.join(output_lines) + '\n')
    
    return True

def main():
    base_dir = "/path/to/project_root/comparative_genomics/06_selection/paml_alignments"
    
    print("=" * 60)
    print("修复phylip格式文件")
    print("=" * 60)
    
    fixed_count = 0
    for og_dir in os.listdir(base_dir):
        og_path = os.path.join(base_dir, og_dir)
        if not os.path.isdir(og_path):
            continue
        
        phy_file = os.path.join(og_path, f"{og_dir}.phy")
        if os.path.exists(phy_file):
            print(f"修复 {og_dir}...")
            if fix_phylip_file(phy_file):
                fixed_count += 1
                print(f"  ✅ 已修复")
            else:
                print(f"  ⚠️ 修复失败")
    
    print(f"\n共修复 {fixed_count} 个文件")

if __name__ == '__main__':
    main()

