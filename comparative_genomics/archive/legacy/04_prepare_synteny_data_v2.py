#!/usr/bin/env python3
"""
准备共线性分析所需的BED文件
为JCVI格式准备数据
"""

import os
import re
from collections import defaultdict

def parse_gff(gff_file, species_prefix):
    """解析GFF文件，提取基因信息"""
    genes = []
    
    with open(gff_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            parts = line.strip().split('\t')
            if len(parts) < 9:
                continue
            
            chrom, source, feature, start, end, score, strand, frame, attrs = parts
            
            # 只处理mRNA或gene特征
            if feature not in ['mRNA', 'gene']:
                continue
            
            # 提取ID
            gene_id = None
            for attr in attrs.split(';'):
                if attr.startswith('ID='):
                    gene_id = attr[3:]
                    break
            
            if gene_id:
                genes.append({
                    'chrom': chrom,
                    'start': int(start),
                    'end': int(end),
                    'gene_id': gene_id,
                    'strand': strand,
                    'species': species_prefix
                })
    
    return genes

def write_bed(genes, output_file, add_prefix=True):
    """写入BED文件"""
    # 按染色体和位置排序
    genes.sort(key=lambda x: (x['chrom'], x['start']))
    
    # 去重 - 只保留mRNA（如果有mRNA则跳过对应的gene）
    seen_ids = set()
    unique_genes = []
    
    for g in genes:
        # 标准化ID - 处理各种格式
        gene_id = g['gene_id']
        
        # 跳过已经处理过的
        if gene_id in seen_ids:
            continue
        
        seen_ids.add(gene_id)
        unique_genes.append(g)
    
    with open(output_file, 'w') as f:
        for g in unique_genes:
            gene_id = g['gene_id']
            if add_prefix:
                gene_id = f"{g['species']}_{gene_id}"
            
            # JCVI BED格式: chrom start end name score strand
            # 注意: BED是0-based start, 但JCVI期望的是0-based
            f.write(f"{g['chrom']}\t{g['start']-1}\t{g['end']}\t{gene_id}\t0\t{g['strand']}\n")
    
    return len(unique_genes)

def main():
    base_dir = '/path/to/project_root'
    out_dir = f'{base_dir}/comparative_genomics/05_synteny/jcvi_data'
    os.makedirs(out_dir, exist_ok=True)
    
    # 定义物种和GFF文件
    species_gff = {
        'T01': f'{base_dir}/annotation/T01/structure/T01_genes.gff3',
        'T02': f'{base_dir}/annotation/T02/structure/T02_genes.gff3',
        'C02': f'{base_dir}/results/C02/C02.gff3',
        'C03': f'{base_dir}/results/C03/C03.gff3',
        'C01': f'{base_dir}/results/C01/hs.chrom.genome.gff',
    }
    
    print("=" * 60)
    print("准备JCVI共线性分析数据")
    print("=" * 60)
    
    for species, gff_file in species_gff.items():
        print(f"\n处理 {species}...")
        
        if not os.path.exists(gff_file):
            print(f"  警告: GFF文件不存在 {gff_file}")
            continue
        
        # 解析GFF
        genes = parse_gff(gff_file, species)
        print(f"  解析到 {len(genes)} 条记录")
        
        # 写入BED文件
        output_bed = f'{out_dir}/{species}.bed'
        count = write_bed(genes, output_bed, add_prefix=True)
        print(f"  输出 {count} 个唯一基因到 {output_bed}")
    
    # 复制蛋白序列
    print("\n复制蛋白序列...")
    proteomes_dir = f'{base_dir}/comparative_genomics/01_proteomes/filtered'
    for species in species_gff.keys():
        src = f'{proteomes_dir}/{species}.fa'
        dst = f'{out_dir}/{species}.pep'
        if os.path.exists(src):
            os.system(f'ln -sf {src} {dst}')
            print(f"  {species}.pep -> {src}")
    
    print("\n" + "=" * 60)
    print(f"数据准备完成! 输出目录: {out_dir}")
    print("=" * 60)

if __name__ == '__main__':
    main()

