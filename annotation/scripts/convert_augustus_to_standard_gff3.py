#!/usr/bin/env python3
"""
将AUGUSTUS GFF3格式转换为标准GFF3格式
参考格式: SMT2024.final.relong.gff3

输入格式 (AUGUSTUS):
Chr01  AUGUSTUS  gene        27095  28911  0.04  -  .  ID=g1
Chr01  AUGUSTUS  transcript  27095  28911  0.04  -  .  ID=g1.t1;Parent=g1
Chr01  AUGUSTUS  CDS         27388  27563  0.97  -  2  ID=g1.t1.cds;Parent=g1.t1
Chr01  AUGUSTUS  exon        27095  27563  .     -  .  Parent=g1.t1
Chr01  AUGUSTUS  intron      27564  27880  1     -  .  Parent=g1.t1

输出格式 (标准):
Chr01  .  gene  27095  28911  .  -  .  ID=T0101G000100
Chr01  .  mRNA  27095  28911  .  -  .  ID=T0101G000100.1;Parent=T0101G000100
Chr01  .  exon  27095  27563  .  -  .  ID=T0101G000100.1.exon1;Parent=T0101G000100.1
Chr01  .  CDS   27388  27563  .  -  2  ID=T0101G000100.1.cds1;Parent=T0101G000100.1

基因ID命名规则:
- T0101G000100: T01物种, 01染色体, G表示基因, 000100表示第1个基因(步长100)
- T0201G000100: T02物种, 01染色体, G表示基因, 000100表示第1个基因(步长100)
"""

import sys
import re
from collections import defaultdict
import argparse

def parse_attributes(attr_str):
    """解析GFF3属性字符串"""
    attrs = {}
    if attr_str and attr_str != '.':
        for item in attr_str.split(';'):
            if '=' in item:
                key, value = item.split('=', 1)
                attrs[key] = value
    return attrs

def format_attributes(attrs):
    """格式化属性为GFF3字符串"""
    return ';'.join(f"{k}={v}" for k, v in attrs.items())

def get_chr_num(chr_name):
    """从染色体名称提取数字，如Chr01 -> 01"""
    match = re.search(r'(\d+)$', chr_name)
    if match:
        return match.group(1).zfill(2)
    return "00"

def convert_augustus_gff3(input_file, output_file, species_prefix):
    """转换AUGUSTUS GFF3为标准格式"""
    
    # 存储所有基因信息
    genes = defaultdict(lambda: {
        'chr': None,
        'start': None,
        'end': None,
        'strand': None,
        'transcripts': defaultdict(lambda: {
            'start': None,
            'end': None,
            'exons': [],
            'cds': []
        })
    })
    
    # 第一遍：读取并解析所有数据
    print(f"读取输入文件: {input_file}", file=sys.stderr)
    
    with open(input_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            fields = line.split('\t')
            if len(fields) != 9:
                continue
            
            chr_name, source, feature, start, end, score, strand, phase, attrs_str = fields
            attrs = parse_attributes(attrs_str)
            start, end = int(start), int(end)
            
            # 跳过非标准特征
            if feature in ['intron', 'start_codon', 'stop_codon', 
                          'transcription_start_site', 'transcription_end_site']:
                continue
            
            if feature == 'gene':
                gene_id = attrs.get('ID')
                if gene_id:
                    genes[gene_id]['chr'] = chr_name
                    genes[gene_id]['start'] = start
                    genes[gene_id]['end'] = end
                    genes[gene_id]['strand'] = strand
            
            elif feature == 'transcript':
                parent = attrs.get('Parent')
                trans_id = attrs.get('ID')
                if parent and trans_id:
                    genes[parent]['transcripts'][trans_id]['start'] = start
                    genes[parent]['transcripts'][trans_id]['end'] = end
            
            elif feature == 'exon':
                parent = attrs.get('Parent')
                if parent:
                    # 找到对应的基因
                    for gene_id, gene_info in genes.items():
                        if parent in gene_info['transcripts']:
                            gene_info['transcripts'][parent]['exons'].append({
                                'start': start,
                                'end': end,
                                'strand': strand
                            })
                            break
            
            elif feature == 'CDS':
                parent = attrs.get('Parent')
                if parent:
                    for gene_id, gene_info in genes.items():
                        if parent in gene_info['transcripts']:
                            gene_info['transcripts'][parent]['cds'].append({
                                'start': start,
                                'end': end,
                                'strand': strand,
                                'phase': phase
                            })
                            break
    
    # 按染色体和位置排序基因
    print(f"共读取 {len(genes)} 个基因", file=sys.stderr)
    
    # 按染色体分组并排序
    chr_genes = defaultdict(list)
    for gene_id, gene_info in genes.items():
        if gene_info['chr'] and gene_info['start']:
            chr_genes[gene_info['chr']].append((gene_id, gene_info))
    
    # 对每个染色体内的基因按位置排序
    for chr_name in chr_genes:
        chr_genes[chr_name].sort(key=lambda x: x[1]['start'])
    
    # 生成新ID并写入输出
    print(f"写入输出文件: {output_file}", file=sys.stderr)
    
    with open(output_file, 'w') as out:
        out.write("##gff-version 3\n")
        
        # 按染色体顺序处理
        chr_list = sorted(chr_genes.keys(), key=lambda x: (len(x), x))
        
        for chr_name in chr_list:
            chr_num = get_chr_num(chr_name)
            gene_count = 0
            
            for old_gene_id, gene_info in chr_genes[chr_name]:
                gene_count += 1
                # 新基因ID: T0101G000100 格式 (步长100)
                new_gene_id = f"{species_prefix}{chr_num}G{gene_count * 100:06d}"
                
                # 写入gene行
                out.write(f"{chr_name}\t.\tgene\t{gene_info['start']}\t{gene_info['end']}\t.\t{gene_info['strand']}\t.\tID={new_gene_id}\n")
                
                # 处理转录本
                trans_count = 0
                for old_trans_id, trans_info in gene_info['transcripts'].items():
                    trans_count += 1
                    new_trans_id = f"{new_gene_id}.{trans_count}"
                    
                    # 确定mRNA的范围
                    trans_start = trans_info['start'] or gene_info['start']
                    trans_end = trans_info['end'] or gene_info['end']
                    
                    # 写入mRNA行
                    out.write(f"{chr_name}\t.\tmRNA\t{trans_start}\t{trans_end}\t.\t{gene_info['strand']}\t.\tID={new_trans_id};Parent={new_gene_id}\n")
                    
                    # 对exon按位置排序
                    exons = sorted(trans_info['exons'], key=lambda x: x['start'])
                    
                    # 对于负链，exon编号需要从后往前
                    if gene_info['strand'] == '-':
                        exons = list(reversed(exons))
                    
                    # 写入exon行
                    for i, exon in enumerate(exons, 1):
                        exon_id = f"{new_trans_id}.exon{i}"
                        out.write(f"{chr_name}\t.\texon\t{exon['start']}\t{exon['end']}\t.\t{gene_info['strand']}\t.\tID={exon_id};Parent={new_trans_id}\n")
                    
                    # 对CDS按位置排序
                    cds_list = sorted(trans_info['cds'], key=lambda x: x['start'])
                    
                    # 对于负链，CDS编号需要从后往前
                    if gene_info['strand'] == '-':
                        cds_list = list(reversed(cds_list))
                    
                    # 写入CDS行
                    for i, cds in enumerate(cds_list, 1):
                        cds_id = f"{new_trans_id}.cds{i}"
                        out.write(f"{chr_name}\t.\tCDS\t{cds['start']}\t{cds['end']}\t.\t{gene_info['strand']}\t{cds['phase']}\tID={cds_id};Parent={new_trans_id}\n")
            
            print(f"  {chr_name}: {gene_count} 个基因", file=sys.stderr)
    
    print(f"转换完成!", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description='将AUGUSTUS GFF3转换为标准格式')
    parser.add_argument('input', help='输入AUGUSTUS GFF3文件')
    parser.add_argument('output', help='输出标准GFF3文件')
    parser.add_argument('-p', '--prefix', required=True, help='物种前缀 (如T01或T02)')
    
    args = parser.parse_args()
    convert_augustus_gff3(args.input, args.output, args.prefix)

if __name__ == '__main__':
    main()

