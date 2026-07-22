#!/usr/bin/env python3
"""
从共线性anchors文件提取同源基因对，准备Ks计算
"""

import os
from Bio import SeqIO
from collections import defaultdict

def load_cds_sequences(cds_file):
    """加载CDS序列到字典，支持多种ID格式"""
    sequences = {}
    for record in SeqIO.parse(cds_file, "fasta"):
        seq_id = record.id
        seq = str(record.seq)
        
        # 存储多种可能的ID格式
        # 完整ID
        sequences[seq_id] = seq
        # 去除版本号
        if '.' in seq_id:
            gene_id_base = seq_id.split('.')[0]
            sequences[gene_id_base] = seq
        # 去除物种前缀（如果有）
        if '_' in seq_id:
            parts = seq_id.split('_', 1)
            if len(parts) > 1:
                sequences[parts[1]] = seq
                # 如果还有版本号
                if '.' in parts[1]:
                    sequences[parts[1].split('.')[0]] = seq
    return sequences

def parse_anchors_file(anchors_file):
    """解析anchors文件，提取同源基因对"""
    pairs = []
    with open(anchors_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            parts = line.strip().split()
            if len(parts) >= 2:
                gene1 = parts[0]
                gene2 = parts[1]
                pairs.append((gene1, gene2))
    return pairs

def extract_cds_pairs(anchors_file, cds1_file, cds2_file, output_dir, max_pairs=5000):
    """提取同源基因对的CDS序列"""
    print(f"处理 {os.path.basename(anchors_file)}...")
    
    # 加载CDS序列
    print("  加载CDS序列...")
    cds1_seqs = load_cds_sequences(cds1_file)
    cds2_seqs = load_cds_sequences(cds2_file)
    print(f"  {os.path.basename(cds1_file)}: {len(cds1_seqs)} 条序列")
    print(f"  {os.path.basename(cds2_file)}: {len(cds2_seqs)} 条序列")
    
    # 解析anchors文件
    print("  解析anchors文件...")
    pairs = parse_anchors_file(anchors_file)
    print(f"  找到 {len(pairs)} 个同源基因对")
    
    # 限制数量（用于测试）
    if len(pairs) > max_pairs:
        pairs = pairs[:max_pairs]
        print(f"  限制为前 {max_pairs} 对（用于测试）")
    
    # 提取序列对
    valid_pairs = []
    missing_count = 0
    
    for gene1, gene2 in pairs:
        # 尝试不同的ID格式匹配
        seq1 = None
        seq2 = None
        
        # 尝试多种匹配方式
        for test_id in [gene1, gene1.split('.')[0], gene1.replace('_', ''), gene1.split('_')[-1] if '_' in gene1 else None]:
            if test_id and test_id in cds1_seqs:
                seq1 = cds1_seqs[test_id]
                break
        
        for test_id in [gene2, gene2.split('.')[0], gene2.replace('_', ''), gene2.split('_')[-1] if '_' in gene2 else None]:
            if test_id and test_id in cds2_seqs:
                seq2 = cds2_seqs[test_id]
                break
        
        if seq1 and seq2:
            # 检查长度（必须是3的倍数）
            if len(seq1) % 3 == 0 and len(seq2) % 3 == 0:
                # 检查最小长度（至少30bp）
                if len(seq1) >= 30 and len(seq2) >= 30:
                    valid_pairs.append((gene1, gene2, seq1, seq2))
                else:
                    missing_count += 1
            else:
                missing_count += 1
        else:
            missing_count += 1
    
    print(f"  有效序列对: {len(valid_pairs)}")
    print(f"  缺失序列: {missing_count}")
    
    # 保存为FASTA格式（KaKs_Calculator输入格式）
    output_file = os.path.join(output_dir, "cds_pairs.fa")
    with open(output_file, 'w') as f:
        for i, (gene1, gene2, seq1, seq2) in enumerate(valid_pairs, 1):
            f.write(f">{gene1}\n{seq1}\n")
            f.write(f">{gene2}\n{seq2}\n")
    
    print(f"  已保存到: {output_file}")
    
    # 保存基因对列表
    pair_list_file = os.path.join(output_dir, "gene_pairs.txt")
    with open(pair_list_file, 'w') as f:
        for gene1, gene2, _, _ in valid_pairs:
            f.write(f"{gene1}\t{gene2}\n")
    
    return len(valid_pairs)

def main():
    base_dir = "/path/to/project_root/comparative_genomics"
    synteny_dir = f"{base_dir}/05_synteny/jcvi_analysis"
    # CDS文件在06_selection目录
    cds_dir = f"{base_dir}/06_selection"
    output_base = f"{base_dir}/04_wgd/ks_from_synteny"
    
    print("=" * 60)
    print("从共线性结果提取Ks计算数据")
    print("=" * 60)
    
    # 定义物种对
    pairs = [
        ("BH", "CK", f"{synteny_dir}/BH.CK.anchors"),
        ("BH", "TAU", f"{synteny_dir}/BH.TAU.anchors"),
        ("CK", "TAU", f"{synteny_dir}/CK.TAU.anchors"),
    ]
    
    total_pairs = 0
    
    for sp1, sp2, anchors_file in pairs:
        if not os.path.exists(anchors_file):
            print(f"跳过 {sp1}-{sp2}: anchors文件不存在")
            continue
        
        cds1_file = f"{cds_dir}/{sp1}.cds.fa"
        cds2_file = f"{cds_dir}/{sp2}.cds.fa"
        
        if not os.path.exists(cds1_file) or not os.path.exists(cds2_file):
            print(f"跳过 {sp1}-{sp2}: CDS文件不存在")
            continue
        
        pair_dir = f"{output_base}/{sp1}_{sp2}"
        os.makedirs(pair_dir, exist_ok=True)
        
        print(f"\n处理 {sp1} vs {sp2}...")
        count = extract_cds_pairs(anchors_file, cds1_file, cds2_file, pair_dir, max_pairs=5000)
        total_pairs += count
    
    print("\n" + "=" * 60)
    print(f"提取完成，共 {total_pairs} 个有效序列对")
    print("=" * 60)
    print("\n下一步: 运行KaKs_Calculator计算Ks值")

if __name__ == '__main__':
    main()

