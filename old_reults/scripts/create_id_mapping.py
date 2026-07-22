#!/usr/bin/env python3
"""
从AUGUSTUS GFF3和新GFF3创建基因ID映射表
"""

import sys
import re
from collections import defaultdict

def parse_attributes(attr_str):
    """解析GFF3属性字符串"""
    attrs = {}
    if attr_str and attr_str != '.':
        for item in attr_str.split(';'):
            if '=' in item:
                key, value = item.split('=', 1)
                attrs[key] = value
    return attrs

def create_mapping(augustus_gff, new_gff, output_file):
    """创建ID映射表"""
    
    # 从AUGUSTUS GFF读取旧基因信息（按染色体和位置）
    old_genes = []
    print(f"读取AUGUSTUS GFF: {augustus_gff}", file=sys.stderr)
    
    with open(augustus_gff, 'r') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            fields = line.strip().split('\t')
            if len(fields) != 9:
                continue
            
            chr_name, source, feature, start, end, score, strand, phase, attrs_str = fields
            
            if feature == 'gene':
                attrs = parse_attributes(attrs_str)
                gene_id = attrs.get('ID')
                if gene_id:
                    old_genes.append({
                        'chr': chr_name,
                        'start': int(start),
                        'end': int(end),
                        'strand': strand,
                        'id': gene_id
                    })
    
    # 从新GFF读取新基因信息
    new_genes = []
    print(f"读取新GFF: {new_gff}", file=sys.stderr)
    
    with open(new_gff, 'r') as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            fields = line.strip().split('\t')
            if len(fields) != 9:
                continue
            
            chr_name, source, feature, start, end, score, strand, phase, attrs_str = fields
            
            if feature == 'gene':
                attrs = parse_attributes(attrs_str)
                gene_id = attrs.get('ID')
                if gene_id:
                    new_genes.append({
                        'chr': chr_name,
                        'start': int(start),
                        'end': int(end),
                        'strand': strand,
                        'id': gene_id
                    })
    
    # 创建位置索引进行匹配
    print(f"旧基因数: {len(old_genes)}, 新基因数: {len(new_genes)}", file=sys.stderr)
    
    # 建立位置到新ID的映射
    pos_to_new = {}
    for gene in new_genes:
        key = (gene['chr'], gene['start'], gene['end'], gene['strand'])
        pos_to_new[key] = gene['id']
    
    # 匹配并输出映射
    mapping = {}
    matched = 0
    
    for gene in old_genes:
        key = (gene['chr'], gene['start'], gene['end'], gene['strand'])
        if key in pos_to_new:
            old_id = gene['id']
            new_id = pos_to_new[key]
            # 基因ID映射
            mapping[old_id] = new_id
            # 转录本ID映射 (g1 -> g1.t1 对应 BH01G000100 -> BH01G000100.1)
            mapping[f"{old_id}.t1"] = f"{new_id}.1"
            matched += 1
    
    print(f"匹配成功: {matched} 个基因", file=sys.stderr)
    
    # 写入映射文件
    with open(output_file, 'w') as out:
        out.write("old_id\tnew_id\n")
        for old_id, new_id in sorted(mapping.items()):
            out.write(f"{old_id}\t{new_id}\n")
    
    print(f"映射表已写入: {output_file}", file=sys.stderr)
    return mapping

def main():
    if len(sys.argv) != 4:
        print("Usage: python create_id_mapping.py <augustus.gff3> <new.gff3> <output.tsv>")
        sys.exit(1)
    
    create_mapping(sys.argv[1], sys.argv[2], sys.argv[3])

if __name__ == '__main__':
    main()

