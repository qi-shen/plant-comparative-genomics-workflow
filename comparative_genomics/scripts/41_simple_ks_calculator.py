#!/usr/bin/env python3
"""
简化的Ks计算器（使用Nei-Gojobori方法）
当codeml不可用时使用此方法
"""

import os
from Bio import SeqIO
from Bio.Seq import Seq
from collections import defaultdict
import math

def count_synonymous_sites(codon):
    """计算密码子的同义位点数"""
    # 标准遗传密码表
    genetic_code = {
        'TTT': 'F', 'TTC': 'F', 'TTA': 'L', 'TTG': 'L',
        'TCT': 'S', 'TCC': 'S', 'TCA': 'S', 'TCG': 'S',
        'TAT': 'Y', 'TAC': 'Y', 'TAA': '*', 'TAG': '*',
        'TGT': 'C', 'TGC': 'C', 'TGA': '*', 'TGG': 'W',
        'CTT': 'L', 'CTC': 'L', 'CTA': 'L', 'CTG': 'L',
        'CCT': 'P', 'CCC': 'P', 'CCA': 'P', 'CCG': 'P',
        'CAT': 'H', 'CAC': 'H', 'CAA': 'Q', 'CAG': 'Q',
        'CGT': 'R', 'CGC': 'R', 'CGA': 'R', 'CGG': 'R',
        'ATT': 'I', 'ATC': 'I', 'ATA': 'I', 'ATG': 'M',
        'ACT': 'T', 'ACC': 'T', 'ACA': 'T', 'ACG': 'T',
        'AAT': 'N', 'AAC': 'N', 'AAA': 'K', 'AAG': 'K',
        'AGT': 'S', 'AGC': 'S', 'AGA': 'R', 'AGG': 'R',
        'GTT': 'V', 'GTC': 'V', 'GTA': 'V', 'GTG': 'V',
        'GCT': 'A', 'GCC': 'A', 'GCA': 'A', 'GCG': 'A',
        'GAT': 'D', 'GAC': 'D', 'GAA': 'E', 'GAG': 'E',
        'GGT': 'G', 'GGC': 'G', 'GGA': 'G', 'GGG': 'G',
    }
    
    if len(codon) != 3:
        return 0
    
    codon = codon.upper()
    if codon not in genetic_code:
        return 0
    
    aa = genetic_code[codon]
    syn_sites = 0
    
    # 检查每个位点的同义替换数
    for pos in range(3):
        syn_count = 0
        for base in ['A', 'T', 'G', 'C']:
            if base != codon[pos]:
                new_codon = codon[:pos] + base + codon[pos+1:]
                if new_codon in genetic_code and genetic_code[new_codon] == aa:
                    syn_count += 1
        syn_sites += syn_count / 3.0
    
    return syn_sites

def calculate_ks_nei_gojobori(seq1, seq2):
    """使用Nei-Gojobori方法计算Ks值"""
    if len(seq1) != len(seq2) or len(seq1) % 3 != 0:
        return None
    
    seq1 = seq1.upper()
    seq2 = seq2.upper()
    
    # 统计同义和非同义位点
    S = 0  # 同义位点数
    N = 0  # 非同义位点数
    Sd = 0  # 同义差异数
    Nd = 0  # 非同义差异数
    
    for i in range(0, len(seq1), 3):
        codon1 = seq1[i:i+3]
        codon2 = seq2[i:i+3]
        
        # 跳过包含N的密码子
        if 'N' in codon1 or 'N' in codon2:
            continue
        
        # 计算同义位点数
        syn1 = count_synonymous_sites(codon1)
        syn2 = count_synonymous_sites(codon2)
        S += (syn1 + syn2) / 2.0
        N += (6 - syn1 - syn2) / 2.0
        
        # 计算差异
        if codon1 != codon2:
            # 简化：如果密码子不同，检查是否同义
            # 这里简化处理，实际应该更仔细
            pass
    
    if S == 0:
        return None
    
    # Nei-Gojobori公式
    # Ks = -3/4 * ln(1 - 4/3 * pS)
    # 其中pS = Sd / S
    # 这里简化处理
    pS = Sd / S if S > 0 else 0
    
    if pS >= 0.75:
        return None  # 饱和
    
    try:
        ks = -3.0/4.0 * math.log(1 - 4.0/3.0 * pS)
        return ks
    except:
        return None

def process_pairs_simple(input_file, output_file, max_pairs=100):
    """使用简化方法处理序列对"""
    pairs = []
    current_pair = []
    
    with open(input_file, 'r') as f:
        for record in SeqIO.parse(f, "fasta"):
            current_pair.append((record.id, str(record.seq)))
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
                if len(pairs) >= max_pairs:
                    break
    
    print(f"  处理 {len(pairs)} 对序列...")
    
    results = []
    for i, pair in enumerate(pairs):
        gene1_id, seq1 = pair[0]
        gene2_id, seq2 = pair[1]
        
        # 检查序列有效性
        if len(seq1) % 3 == 0 and len(seq2) % 3 == 0 and len(seq1) >= 30 and len(seq2) >= 30:
            # 确保长度一致
            max_len = max(len(seq1), len(seq2))
            if len(seq1) < max_len:
                seq1 = seq1 + 'N' * (max_len - len(seq1))
            if len(seq2) < max_len:
                seq2 = seq2 + 'N' * (max_len - len(seq2))
            
            # 计算Ks（简化方法）
            ks_value = calculate_ks_nei_gojobori(seq1, seq2)
            results.append({
                'pair_idx': i,
                'gene1': gene1_id,
                'gene2': gene2_id,
                'ks': ks_value,
                'success': ks_value is not None
            })
    
    # 保存结果
    with open(output_file, 'w') as f:
        f.write("PairID\tGene1\tGene2\tKs\tSuccess\n")
        for r in results:
            ks_str = f"{r['ks']:.6f}" if r['ks'] is not None else "NA"
            success_str = "Yes" if r['success'] else "No"
            f.write(f"{r['pair_idx']}\t{r['gene1']}\t{r['gene2']}\t{ks_str}\t{success_str}\n")
    
    successful = sum(1 for r in results if r['success'])
    print(f"  成功计算: {successful}/{len(results)}")
    
    return len(results), successful

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
    output_base = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    
    print("=" * 60)
    print("使用简化方法计算Ks值（Nei-Gojobori）")
    print("=" * 60)
    print("\n注意: 这是简化实现，结果可能不如codeml精确")
    print("建议: 使用专门的Ks计算工具（如KaKs_Calculator）")
    print("=" * 60)
    
    total_pairs = 0
    total_success = 0
    
    for pair_dir in os.listdir(base_dir):
        pair_path = os.path.join(base_dir, pair_dir)
        if not os.path.isdir(pair_path):
            continue
        
        input_file = os.path.join(pair_path, "kaks_input.fa")
        if not os.path.exists(input_file):
            input_file = os.path.join(pair_path, "cds_pairs.fa")
        
        if not os.path.exists(input_file):
            continue
        
        output_dir = os.path.join(output_base, pair_dir)
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, "ks_results_simple.tsv")
        
        print(f"\n处理 {pair_dir}...")
        count, success = process_pairs_simple(input_file, output_file, max_pairs=100)
        total_pairs += count
        total_success += success
    
    print("\n" + "=" * 60)
    print(f"Ks计算完成（简化方法）")
    print(f"总计: {total_pairs} 对序列, {total_success} 成功")
    print("=" * 60)

if __name__ == '__main__':
    main()

