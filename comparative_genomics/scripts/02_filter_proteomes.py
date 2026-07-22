#!/usr/bin/env python3
"""
过滤蛋白质序列:
1. 去除短于50aa的序列
2. 去除含有停止密码子(*)或异常字符的序列
3. 保留最长的转录本
"""

import os
import sys
from collections import defaultdict

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
    # 处理各种格式
    # BH_BH01G000001.1 -> BH_BH01G000001
    # ATH_transcript:AT1G01010.1 -> ATH_transcript:AT1G01010
    parts = seq_id.rsplit('.', 1)
    if len(parts) == 2 and parts[1].isdigit():
        return parts[0]
    return seq_id

def filter_proteome(input_file, output_file, min_length=50):
    """过滤蛋白质组"""
    sequences = parse_fasta(input_file)
    
    # 统计
    stats = {
        'total': len(sequences),
        'too_short': 0,
        'has_stop': 0,
        'invalid_char': 0,
        'kept': 0
    }
    
    # 按基因分组，保留最长转录本
    gene_seqs = defaultdict(list)
    valid_aa = set('ACDEFGHIKLMNPQRSTVWYX')
    
    for seq_id, seq in sequences.items():
        seq = seq.upper().rstrip('*')  # 去除尾部停止密码子
        
        # 检查序列长度
        if len(seq) < min_length:
            stats['too_short'] += 1
            continue
        
        # 检查内部停止密码子
        if '*' in seq:
            stats['has_stop'] += 1
            continue
        
        # 检查异常字符
        invalid = set(seq) - valid_aa
        if invalid:
            stats['invalid_char'] += 1
            continue
        
        gene_id = get_gene_id(seq_id)
        gene_seqs[gene_id].append((seq_id, seq))
    
    # 保留每个基因最长的转录本
    filtered = {}
    for gene_id, transcripts in gene_seqs.items():
        longest = max(transcripts, key=lambda x: len(x[1]))
        filtered[longest[0]] = longest[1]
    
    stats['kept'] = len(filtered)
    
    # 写入输出
    with open(output_file, 'w') as f:
        for seq_id, seq in filtered.items():
            f.write(f'>{seq_id}\n')
            # 按60字符换行
            for i in range(0, len(seq), 60):
                f.write(seq[i:i+60] + '\n')
    
    return stats

def main():
    input_dir = '/path/to/project_root/comparative_genomics/01_proteomes'
    output_dir = '/path/to/project_root/comparative_genomics/01_proteomes/filtered'
    os.makedirs(output_dir, exist_ok=True)
    
    print("=" * 60)
    print("过滤蛋白质序列")
    print("=" * 60)
    
    species_list = ['BH', 'CK', 'TAU', 'TCH', 'RSO', 'CQU', 'GPA', 
                    'APA', 'FMU', 'HAM', 'POL', 'DCA', 'SMO', 'ATH', 'VVI']
    
    all_stats = []
    
    for sp in species_list:
        input_file = os.path.join(input_dir, f'{sp}.fa')
        output_file = os.path.join(output_dir, f'{sp}.fa')
        
        if os.path.exists(input_file):
            stats = filter_proteome(input_file, output_file)
            stats['species'] = sp
            all_stats.append(stats)
            print(f"{sp}: {stats['total']} -> {stats['kept']} 序列 "
                  f"(短序列:{stats['too_short']}, 停止密码子:{stats['has_stop']}, "
                  f"异常字符:{stats['invalid_char']})")
        else:
            print(f"{sp}: 文件不存在")
    
    # 生成统计表
    stats_file = os.path.join(output_dir, 'filter_stats.tsv')
    with open(stats_file, 'w') as f:
        f.write("Species\tTotal\tKept\tToo_Short\tHas_Stop\tInvalid_Char\tRetention_Rate\n")
        for stats in all_stats:
            rate = stats['kept'] / stats['total'] * 100 if stats['total'] > 0 else 0
            f.write(f"{stats['species']}\t{stats['total']}\t{stats['kept']}\t"
                    f"{stats['too_short']}\t{stats['has_stop']}\t{stats['invalid_char']}\t"
                    f"{rate:.1f}%\n")
    
    print("\n" + "=" * 60)
    print(f"过滤完成! 输出目录: {output_dir}")
    print(f"统计文件: {stats_file}")
    print("=" * 60)

if __name__ == '__main__':
    main()

