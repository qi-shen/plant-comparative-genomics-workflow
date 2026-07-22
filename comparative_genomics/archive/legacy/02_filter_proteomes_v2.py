#!/usr/bin/env python3
"""
过滤蛋白质序列 v2:
1. 去除短于50aa的序列
2. 去除或处理停止密码子(*, .)
3. 保留最长的转录本
"""

import os
import sys
from collections import defaultdict
import re

def parse_fasta(filename):
    """解析FASTA文件"""
    sequences = {}
    current_id = None
    current_seq = []
    
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                if current_id:
                    sequences[current_id] = ''.join(current_seq)
                current_id = line[1:].split()[0]  # 取第一个空格前的部分作为ID
                current_seq = []
            else:
                current_seq.append(line)
        if current_id:
            sequences[current_id] = ''.join(current_seq)
    
    return sequences

def get_gene_id(seq_id):
    """从转录本ID提取基因ID"""
    # 去除物种前缀后处理
    # T01_T0101G000001.1 -> T01_T0101G000001
    # O01_transcript:GENE00010.1 -> O01_transcript:GENE00010
    # C02_evm.model.Chr01.1 -> C02_evm.model.Chr01
    
    # 使用正则匹配末尾的.数字模式
    match = re.match(r'^(.+)\.\d+$', seq_id)
    if match:
        return match.group(1)
    return seq_id

def clean_sequence(seq):
    """清理序列"""
    seq = seq.upper()
    # 去除停止标记 (* 和 .)
    seq = seq.replace('*', '').replace('.', '')
    # 去除空白字符
    seq = re.sub(r'\s+', '', seq)
    return seq

def filter_proteome(input_file, output_file, min_length=50):
    """过滤蛋白质组"""
    sequences = parse_fasta(input_file)
    
    # 统计
    stats = {
        'total': len(sequences),
        'too_short': 0,
        'invalid_char': 0,
        'duplicates': 0,
        'kept': 0
    }
    
    # 有效氨基酸字符
    valid_aa = set('ACDEFGHIKLMNPQRSTVWXY')
    
    # 按基因分组，保留最长转录本
    gene_seqs = defaultdict(list)
    
    for seq_id, seq in sequences.items():
        # 清理序列
        seq = clean_sequence(seq)
        
        # 检查序列长度
        if len(seq) < min_length:
            stats['too_short'] += 1
            continue
        
        # 检查异常字符
        invalid = set(seq) - valid_aa
        if invalid:
            stats['invalid_char'] += 1
            # print(f"  Invalid chars in {seq_id}: {invalid}")
            continue
        
        gene_id = get_gene_id(seq_id)
        gene_seqs[gene_id].append((seq_id, seq))
    
    # 保留每个基因最长的转录本
    filtered = {}
    for gene_id, transcripts in gene_seqs.items():
        if len(transcripts) > 1:
            stats['duplicates'] += len(transcripts) - 1
        longest = max(transcripts, key=lambda x: len(x[1]))
        filtered[longest[0]] = longest[1]
    
    stats['kept'] = len(filtered)
    
    # 写入输出
    with open(output_file, 'w') as f:
        for seq_id, seq in sorted(filtered.items()):
            f.write(f'>{seq_id}\n')
            # 按60字符换行
            for i in range(0, len(seq), 60):
                f.write(seq[i:i+60] + '\n')
    
    return stats

def main():
    input_dir = '/path/to/project_root/comparative_genomics/01_proteomes'
    output_dir = '/path/to/project_root/comparative_genomics/01_proteomes/filtered'
    os.makedirs(output_dir, exist_ok=True)
    
    print("=" * 70)
    print("过滤蛋白质序列 v2")
    print("=" * 70)
    
    species_list = ['T01', 'T02', 'C02', 'C03', 'C01', 'C05', 'C07', 
                    'C04', 'C08', 'C09', 'C10', 'C06', 'C11', 'O01', 'O02']
    
    all_stats = []
    
    for sp in species_list:
        input_file = os.path.join(input_dir, f'{sp}.fa')
        output_file = os.path.join(output_dir, f'{sp}.fa')
        
        if os.path.exists(input_file):
            stats = filter_proteome(input_file, output_file)
            stats['species'] = sp
            all_stats.append(stats)
            print(f"{sp:5s}: {stats['total']:6d} -> {stats['kept']:6d} 序列 "
                  f"(短:{stats['too_short']:4d}, 异常:{stats['invalid_char']:4d}, "
                  f"重复:{stats['duplicates']:5d})")
        else:
            print(f"{sp}: 文件不存在")
    
    # 生成统计表
    stats_file = os.path.join(output_dir, 'filter_stats.tsv')
    with open(stats_file, 'w') as f:
        f.write("Species\tTotal\tKept\tToo_Short\tInvalid_Char\tDuplicates\tRetention_Rate\n")
        for stats in all_stats:
            rate = stats['kept'] / stats['total'] * 100 if stats['total'] > 0 else 0
            f.write(f"{stats['species']}\t{stats['total']}\t{stats['kept']}\t"
                    f"{stats['too_short']}\t{stats['invalid_char']}\t{stats['duplicates']}\t"
                    f"{rate:.1f}%\n")
    
    # 打印总结
    print("\n" + "=" * 70)
    total_in = sum(s['total'] for s in all_stats)
    total_out = sum(s['kept'] for s in all_stats)
    print(f"总计: {total_in} -> {total_out} 序列 ({total_out/total_in*100:.1f}% 保留)")
    print(f"过滤完成! 输出目录: {output_dir}")
    print("=" * 70)

if __name__ == '__main__':
    main()

