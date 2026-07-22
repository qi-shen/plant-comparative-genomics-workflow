#!/usr/bin/env python3
"""
将EVM输出转换为标准GFF3格式
基因ID格式: BH01G000100
"""

import sys
import re
from collections import defaultdict

def convert_evm_gff3(input_gff, output_gff, species_prefix):
    """
    转换EVM GFF3到标准格式
    species_prefix: T01 或 T02
    """
    
    # 首先按染色体和位置排序基因
    genes = []
    features = defaultdict(list)  # gene_id -> features
    
    print(f"读取输入文件: {input_gff}")
    
    with open(input_gff, 'r') as f:
        current_gene_id = None
        for line in f:
            if line.startswith('#') or line.strip() == '':
                continue
            
            parts = line.strip().split('\t')
            if len(parts) < 9:
                continue
            
            seqid = parts[0]
            feature_type = parts[2]
            start = int(parts[3])
            end = int(parts[4])
            attributes = parts[8]
            
            if feature_type == 'gene':
                # 提取gene ID
                id_match = re.search(r'ID=([^;]+)', attributes)
                if id_match:
                    current_gene_id = id_match.group(1)
                    genes.append({
                        'chr': seqid,
                        'start': start,
                        'end': end,
                        'old_id': current_gene_id,
                        'line': line.strip()
                    })
                    features[current_gene_id] = []
            else:
                # 找到Parent
                parent_match = re.search(r'Parent=([^;]+)', attributes)
                if parent_match:
                    parent_id = parent_match.group(1)
                    # 找到对应的gene
                    for gene in reversed(genes):
                        if parent_id.startswith('evm.model'):
                            gene_part = parent_id.replace('evm.model.', 'evm.TU.')
                        else:
                            gene_part = parent_id
                        
                        if gene['old_id'] == gene_part or parent_id.replace('evm.model.', 'evm.TU.').split('.exon')[0] == gene['old_id'].replace('.', '.'):
                            features[gene['old_id']].append(line.strip())
                            break
                    else:
                        # 查找基于染色体和gene number
                        for gene in reversed(genes):
                            if parent_id.startswith(f"evm.model.{gene['chr']}") or \
                               parent_id.startswith(f"cds.evm.model.{gene['chr']}"):
                                gene_num_match = re.search(r'\.(\d+)(?:\.|$)', parent_id)
                                old_num_match = re.search(r'\.(\d+)$', gene['old_id'])
                                if gene_num_match and old_num_match:
                                    if gene_num_match.group(1) == old_num_match.group(1):
                                        features[gene['old_id']].append(line.strip())
                                        break
    
    # 按染色体排序，提取染色体编号
    def chr_sort_key(gene):
        chr_name = gene['chr']
        # 提取染色体编号
        match = re.search(r'(\d+)', chr_name)
        if match:
            return (int(match.group(1)), gene['start'])
        return (0, gene['start'])
    
    # 按染色体分组并在每个染色体内按位置排序
    chr_genes = defaultdict(list)
    for gene in genes:
        chr_genes[gene['chr']].append(gene)
    
    # 对每个染色体的基因按位置排序
    for chr_name in chr_genes:
        chr_genes[chr_name].sort(key=lambda x: x['start'])
    
    # 按染色体编号排序
    sorted_chrs = sorted(chr_genes.keys(), key=lambda x: int(re.search(r'(\d+)', x).group(1)) if re.search(r'(\d+)', x) else 0)
    
    # 创建ID映射
    id_map = {}  # old_id -> new_id
    gene_count = defaultdict(int)
    
    for chr_name in sorted_chrs:
        # 提取染色体编号
        chr_match = re.search(r'Chr(\d+)', chr_name)
        if chr_match:
            chr_num = chr_match.group(1).zfill(2)
        else:
            chr_num = '00'
        
        for gene in chr_genes[chr_name]:
            gene_count[chr_name] += 1
            new_gene_id = f"{species_prefix}{chr_num}G{gene_count[chr_name]:06d}"
            old_gene_id = gene['old_id']
            id_map[old_gene_id] = new_gene_id
            
            # 映射mRNA ID
            old_mrna_id = old_gene_id.replace('evm.TU.', 'evm.model.')
            new_mrna_id = f"{new_gene_id}.1"
            id_map[old_mrna_id] = new_mrna_id
    
    print(f"基因总数: {sum(gene_count.values())}")
    for chr_name in sorted_chrs:
        print(f"  {chr_name}: {gene_count[chr_name]} 基因")
    
    # 写入输出文件
    print(f"写入输出文件: {output_gff}")
    
    with open(output_gff, 'w') as out:
        out.write("##gff-version 3\n")
        
        for chr_name in sorted_chrs:
            for gene in chr_genes[chr_name]:
                old_gene_id = gene['old_id']
                new_gene_id = id_map[old_gene_id]
                old_mrna_id = old_gene_id.replace('evm.TU.', 'evm.model.')
                new_mrna_id = id_map[old_mrna_id]
                
                # 写入gene行
                parts = gene['line'].split('\t')
                parts[1] = '.'  # 清空source
                # 更新attributes
                parts[8] = f"ID={new_gene_id}"
                out.write('\t'.join(parts) + '\n')
                
                # 处理子特征
                exon_count = 0
                cds_count = 0
                
                for feat_line in features[old_gene_id]:
                    feat_parts = feat_line.split('\t')
                    feat_type = feat_parts[2]
                    feat_parts[1] = '.'  # 清空source
                    
                    if feat_type == 'mRNA':
                        feat_parts[8] = f"ID={new_mrna_id};Parent={new_gene_id}"
                    elif feat_type == 'exon':
                        exon_count += 1
                        feat_parts[8] = f"ID={new_mrna_id}.exon{exon_count};Parent={new_mrna_id}"
                    elif feat_type == 'CDS':
                        cds_count += 1
                        feat_parts[8] = f"ID={new_mrna_id}.cds{cds_count};Parent={new_mrna_id}"
                    
                    out.write('\t'.join(feat_parts) + '\n')
    
    # 返回ID映射用于更新其他文件
    return id_map, sum(gene_count.values())

def create_id_mapping_file(id_map, output_file):
    """创建ID映射文件"""
    with open(output_file, 'w') as f:
        f.write("old_id\tnew_id\n")
        for old_id, new_id in sorted(id_map.items()):
            f.write(f"{old_id}\t{new_id}\n")
    print(f"ID映射文件已保存: {output_file}")

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <input_gff3> <output_gff3> <species_prefix> [mapping_file]")
        sys.exit(1)
    
    input_gff = sys.argv[1]
    output_gff = sys.argv[2]
    species_prefix = sys.argv[3]
    mapping_file = sys.argv[4] if len(sys.argv) > 4 else None
    
    id_map, gene_count = convert_evm_gff3(input_gff, output_gff, species_prefix)
    
    if mapping_file:
        create_id_mapping_file(id_map, mapping_file)
    
    print(f"\n转换完成！共 {gene_count} 个基因")

