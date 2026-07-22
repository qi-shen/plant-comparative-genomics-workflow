#!/usr/bin/env python3
"""
处理Diamond注释结果，提取功能注释信息（不依赖pandas）
"""

import sys
import re
from collections import defaultdict

def parse_swissprot_title(title):
    """解析SwissProt标题，提取信息"""
    info = {
        'accession': '',
        'gene_name': '',
        'protein_name': '',
        'organism': '',
        'taxon_id': ''
    }
    
    # 提取accession
    acc_match = re.search(r'sp\|([^|]+)\|', title)
    if acc_match:
        info['accession'] = acc_match.group(1)
    
    # 提取基因名
    gn_match = re.search(r'GN=([^\s]+)', title)
    if gn_match:
        info['gene_name'] = gn_match.group(1)
    
    # 提取蛋白名（在GN之前的部分）
    protein_match = re.search(r'\|\w+\s+(.+?)(?:\s+OS=|$)', title)
    if protein_match:
        info['protein_name'] = protein_match.group(1).strip()
    
    # 提取物种
    os_match = re.search(r'OS=([^=]+?)(?:\s+OX=|$)', title)
    if os_match:
        info['organism'] = os_match.group(1).strip()
    
    # 提取taxon ID
    ox_match = re.search(r'OX=(\d+)', title)
    if ox_match:
        info['taxon_id'] = ox_match.group(1)
    
    return info

def process_diamond_results(input_file, output_file):
    """处理Diamond注释结果"""
    
    print(f"读取Diamond结果: {input_file}")
    
    # 读取结果
    hits = []
    with open(input_file, 'r') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 13:
                hits.append({
                    'query': parts[0],
                    'sseqid': parts[1],
                    'pident': float(parts[2]),
                    'length': int(parts[3]),
                    'mismatch': int(parts[4]),
                    'gapopen': int(parts[5]),
                    'qstart': int(parts[6]),
                    'qend': int(parts[7]),
                    'sstart': int(parts[8]),
                    'send': int(parts[9]),
                    'evalue': float(parts[10]),
                    'bitscore': float(parts[11]),
                    'stitle': parts[12] if len(parts) > 12 else ''
                })
    
    print(f"总匹配数: {len(hits)}")
    
    # 按query分组，取top hit
    query_hits = defaultdict(list)
    for hit in hits:
        query_hits[hit['query']].append(hit)
    
    # 对每个query的hits按bitscore排序
    for query in query_hits:
        query_hits[query].sort(key=lambda x: x['bitscore'], reverse=True)
    
    print(f"唯一基因数: {len(query_hits)}")
    
    # 准备输出
    results = []
    all_matches_dict = {}
    
    for query, hit_list in sorted(query_hits.items()):
        top_hit = hit_list[0]
        swissprot_info = parse_swissprot_title(top_hit['stitle'])
        
        # 收集所有匹配（最多5个）
        all_matches = []
        for h in hit_list[:5]:
            match_str = f"{h['sseqid']}({h['pident']:.1f}%,{h['evalue']:.2e})"
            all_matches.append(match_str)
        
        results.append({
            'Gene_ID': query,
            'SwissProt_Accession': swissprot_info['accession'],
            'SwissProt_Gene_Name': swissprot_info['gene_name'],
            'SwissProt_Protein_Name': swissprot_info['protein_name'],
            'SwissProt_Organism': swissprot_info['organism'],
            'SwissProt_Taxon_ID': swissprot_info['taxon_id'],
            'Identity': f"{top_hit['pident']:.2f}",
            'Alignment_Length': str(top_hit['length']),
            'E_value': f"{top_hit['evalue']:.2e}",
            'Bit_Score': f"{top_hit['bitscore']:.2f}",
            'Query_Start': str(top_hit['qstart']),
            'Query_End': str(top_hit['qend']),
            'Subject_Start': str(top_hit['sstart']),
            'Subject_End': str(top_hit['send']),
            'All_Matches': ';'.join(all_matches)
        })
    
    # 写入结果
    print(f"写入结果: {output_file}")
    with open(output_file, 'w') as f:
        # 写入表头
        header = ['Gene_ID', 'SwissProt_Accession', 'SwissProt_Gene_Name', 
                 'SwissProt_Protein_Name', 'SwissProt_Organism', 'SwissProt_Taxon_ID',
                 'Identity', 'Alignment_Length', 'E_value', 'Bit_Score',
                 'Query_Start', 'Query_End', 'Subject_Start', 'Subject_End', 'All_Matches']
        f.write('\t'.join(header) + '\n')
        
        # 写入数据
        for result in results:
            f.write('\t'.join([str(result.get(col, '')) for col in header]) + '\n')
    
    # 统计信息
    annotated = sum(1 for r in results if r['SwissProt_Accession'])
    total = len(results)
    avg_identity = sum(float(r['Identity']) for r in results) / total if total > 0 else 0
    
    print(f"\n统计信息:")
    print(f"  总基因数: {total}")
    print(f"  有注释的基因: {annotated}")
    print(f"  注释率: {annotated / total * 100:.2f}%")
    print(f"  平均identity: {avg_identity:.2f}%")
    
    return results

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <diamond_output> <annotation_output>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    process_diamond_results(input_file, output_file)
