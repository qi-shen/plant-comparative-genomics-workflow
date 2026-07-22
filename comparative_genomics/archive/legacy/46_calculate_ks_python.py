#!/usr/bin/env python3
"""
使用Python实现Nei-Gojobori方法计算Ks值
这是codeml的替代方案
"""

import os
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.Data import CodonTable
import numpy as np
from multiprocessing import Pool
from collections import defaultdict

# 标准密码子表
standard_table = CodonTable.unambiguous_dna_by_id[1]

def get_synonymous_sites(codon):
    """计算密码子的同义位点数"""
    if len(codon) != 3:
        return 0, 0
    
    aa = standard_table.forward_table.get(codon, '*')
    if aa == '*':
        return 0, 0
    
    syn_sites = 0
    non_syn_sites = 0
    
    for pos in range(3):
        for base in 'ATCG':
            if base == codon[pos]:
                continue
            new_codon = codon[:pos] + base + codon[pos+1:]
            new_aa = standard_table.forward_table.get(new_codon, '*')
            if new_aa == aa:
                syn_sites += 1
            elif new_aa != '*':
                non_syn_sites += 1
    
    return syn_sites, non_syn_sites

def count_synonymous_differences(codon1, codon2):
    """计算两个密码子之间的同义和非同义差异"""
    if len(codon1) != 3 or len(codon2) != 3:
        return 0, 0, 0, 0
    
    aa1 = standard_table.forward_table.get(codon1, '*')
    aa2 = standard_table.forward_table.get(codon2, '*')
    
    if aa1 == '*' or aa2 == '*':
        return 0, 0, 0, 0
    
    # 计算差异位点
    diffs = sum(1 for i in range(3) if codon1[i] != codon2[i])
    
    if diffs == 0:
        return 0, 0, 0, 0
    
    # 计算同义和非同义位点
    syn_sites1, non_syn_sites1 = get_synonymous_sites(codon1)
    syn_sites2, non_syn_sites2 = get_synonymous_sites(codon2)
    
    avg_syn_sites = (syn_sites1 + syn_sites2) / 2.0
    avg_non_syn_sites = (non_syn_sites1 + non_syn_sites2) / 2.0
    
    # 判断是同义还是非同义替换
    if aa1 == aa2:
        syn_diffs = diffs
        non_syn_diffs = 0
    else:
        syn_diffs = 0
        non_syn_diffs = diffs
    
    return syn_diffs, non_syn_diffs, avg_syn_sites, avg_non_syn_sites

def calculate_ks_nei_gojobori(seq1, seq2):
    """使用Nei-Gojobori方法计算Ks和Ka"""
    seq1 = seq1.upper().replace('-', '').replace('N', '')
    seq2 = seq2.upper().replace('-', '').replace('N', '')
    
    # 确保长度是3的倍数
    if len(seq1) % 3 != 0:
        seq1 = seq1[:-(len(seq1) % 3)]
    if len(seq2) % 3 != 0:
        seq2 = seq2[:-(len(seq2) % 3)]
    
    min_len = min(len(seq1), len(seq2))
    if min_len < 30:
        return None, None, None
    
    seq1 = seq1[:min_len]
    seq2 = seq2[:min_len]
    
    # 对齐到3的倍数
    if min_len % 3 != 0:
        trim = min_len % 3
        seq1 = seq1[:-trim]
        seq2 = seq2[:-trim]
        min_len = len(seq1)
    
    if min_len < 30:
        return None, None, None
    
    # 统计同义和非同义差异
    total_syn_diffs = 0
    total_non_syn_diffs = 0
    total_syn_sites = 0
    total_non_syn_sites = 0
    valid_codons = 0
    
    for i in range(0, min_len, 3):
        codon1 = seq1[i:i+3]
        codon2 = seq2[i:i+3]
        
        # 跳过包含N的密码子
        if 'N' in codon1 or 'N' in codon2:
            continue
        
        # 跳过终止密码子
        if codon1 in standard_table.stop_codons or codon2 in standard_table.stop_codons:
            continue
        
        syn_diffs, non_syn_diffs, syn_sites, non_syn_sites = count_synonymous_differences(codon1, codon2)
        
        total_syn_diffs += syn_diffs
        total_non_syn_diffs += non_syn_diffs
        total_syn_sites += syn_sites
        total_non_syn_sites += non_syn_sites
        valid_codons += 1
    
    if valid_codons < 10:
        return None, None, None
    
    # 计算Ks和Ka
    if total_syn_sites > 0:
        pS = total_syn_diffs / total_syn_sites
        # Jukes-Cantor校正
        if pS < 0.75:
            ks = -0.75 * np.log(1 - 4 * pS / 3)
        else:
            ks = None
    else:
        ks = None
    
    if total_non_syn_sites > 0:
        pN = total_non_syn_diffs / total_non_syn_sites
        if pN < 0.75:
            ka = -0.75 * np.log(1 - 4 * pN / 3)
        else:
            ka = None
    else:
        ka = None
    
    return ks, ka, valid_codons

def process_single_pair(args):
    """处理单对序列"""
    idx, gene1, gene2, seq1, seq2 = args
    
    try:
        ks, ka, valid_codons = calculate_ks_nei_gojobori(seq1, seq2)
        
        if ks is not None and 0 <= ks <= 5:  # 合理的Ks范围
            return {
                'idx': idx,
                'gene1': gene1,
                'gene2': gene2,
                'ks': ks,
                'ka': ka if ka is not None else None,
                'valid_codons': valid_codons,
                'success': True
            }
        else:
            return {
                'idx': idx,
                'gene1': gene1,
                'gene2': gene2,
                'ks': None,
                'ka': None,
                'valid_codons': valid_codons if valid_codons else 0,
                'success': False
            }
    except Exception as e:
        return {
            'idx': idx,
            'gene1': gene1,
            'gene2': gene2,
            'ks': None,
            'ka': None,
            'valid_codons': 0,
            'success': False,
            'error': str(e)[:50]
        }

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
    output_base = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    
    print("=" * 60)
    print("使用Python Nei-Gojobori方法计算Ks值")
    print("=" * 60)
    
    total_pairs = 0
    total_success = 0
    
    for pair_name in ['T01_T02', 'T01_C02', 'T02_C02']:
        pair_dir = os.path.join(base_dir, pair_name)
        input_file = os.path.join(pair_dir, "kaks_input.fa")
        
        if not os.path.exists(input_file):
            continue
        
        print(f"\n处理 {pair_name}...")
        
        # 读取序列对
        pairs = []
        current = []
        with open(input_file, 'r') as f:
            for record in SeqIO.parse(f, "fasta"):
                current.append((record.id, str(record.seq)))
                if len(current) == 2:
                    pairs.append(current)
                    current = []
        
        print(f"  读取到 {len(pairs)} 对序列")
        
        # 准备参数
        args_list = []
        for i, pair in enumerate(pairs):
            g1, s1 = pair[0]
            g2, s2 = pair[1]
            args_list.append((i, g1, g2, s1, s2))
        
        # 并行计算
        print(f"  计算Ks值（使用32核心）...")
        with Pool(processes=32) as pool:
            results = pool.map(process_single_pair, args_list)
        
        # 保存结果
        output_dir = os.path.join(output_base, pair_name)
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, "ks_results_python.tsv")
        
        with open(output_file, 'w') as f:
            f.write("PairID\tGene1\tGene2\tKs\tKa\tValidCodons\tSuccess\n")
            for r in results:
                ks_str = f"{r['ks']:.6f}" if r['ks'] is not None else "NA"
                ka_str = f"{r['ka']:.6f}" if r['ka'] is not None else "NA"
                success_str = "Yes" if r['success'] else "No"
                f.write(f"{r['idx']}\t{r['gene1']}\t{r['gene2']}\t{ks_str}\t{ka_str}\t{r['valid_codons']}\t{success_str}\n")
        
        successful = sum(1 for r in results if r['success'])
        valid_ks = [r['ks'] for r in results if r['ks'] is not None]
        
        print(f"  成功: {successful}/{len(results)} ({successful/len(results)*100:.1f}%)")
        if valid_ks:
            print(f"  Ks范围: {min(valid_ks):.4f} - {max(valid_ks):.4f}")
            print(f"  Ks平均值: {sum(valid_ks)/len(valid_ks):.4f}")
            print(f"  Ks中位数: {np.median(valid_ks):.4f}")
        
        total_pairs += len(results)
        total_success += successful
    
    print("\n" + "=" * 60)
    print(f"总计: {total_pairs} 对序列, {total_success} 成功 ({total_success/total_pairs*100:.1f}%)")
    print("=" * 60)

if __name__ == '__main__':
    main()

