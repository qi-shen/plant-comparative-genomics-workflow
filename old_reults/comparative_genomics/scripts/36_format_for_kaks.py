#!/usr/bin/env python3
"""
将提取的CDS序列对格式化为KaKs_Calculator输入格式
KaKs_Calculator需要特定的格式：每两行为一对序列
"""

import os
from Bio import SeqIO

def format_for_kaks(input_file, output_file):
    """将FASTA文件格式化为KaKs_Calculator格式"""
    sequences = []
    current_pair = []
    
    with open(input_file, 'r') as f:
        for record in SeqIO.parse(f, "fasta"):
            current_pair.append((record.id, str(record.seq)))
            
            # 每两行为一对
            if len(current_pair) == 2:
                sequences.append(current_pair)
                current_pair = []
    
    # 写入KaKs_Calculator格式
    with open(output_file, 'w') as f:
        for i, (seq1, seq2) in enumerate(sequences, 1):
            gene1_id, seq1_seq = seq1
            gene2_id, seq2_seq = seq2
            
            # KaKs_Calculator格式：每两行为一对
            f.write(f">{gene1_id}\n{seq1_seq}\n")
            f.write(f">{gene2_id}\n{seq2_seq}\n")
    
    return len(sequences)

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
    
    print("=" * 60)
    print("格式化KaKs_Calculator输入文件")
    print("=" * 60)
    
    total_pairs = 0
    
    for pair_dir in os.listdir(base_dir):
        pair_path = os.path.join(base_dir, pair_dir)
        if not os.path.isdir(pair_path):
            continue
        
        input_file = os.path.join(pair_path, "cds_pairs.fa")
        output_file = os.path.join(pair_path, "kaks_input.fa")
        
        if not os.path.exists(input_file):
            continue
        
        print(f"\n处理 {pair_dir}...")
        count = format_for_kaks(input_file, output_file)
        total_pairs += count
        print(f"  格式化完成: {count} 对序列")
        print(f"  输出文件: {output_file}")
    
    print("\n" + "=" * 60)
    print(f"格式化完成，共 {total_pairs} 对序列")
    print("=" * 60)

if __name__ == '__main__':
    main()

