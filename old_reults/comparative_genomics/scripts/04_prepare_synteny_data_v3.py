#!/usr/bin/env python3
"""
准备共线性分析所需的BED文件
为JCVI格式准备数据 - 只保留mRNA记录
"""

import os
import re
from collections import defaultdict

def parse_gff_mrna(gff_file, species_prefix):
    """解析GFF文件，只提取mRNA信息"""
    mrnas = []
    
    with open(gff_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            parts = line.strip().split('\t')
            if len(parts) < 9:
                continue
            
            chrom, source, feature, start, end, score, strand, frame, attrs = parts
            
            # 只处理mRNA特征
            if feature != 'mRNA':
                continue
            
            # 提取ID
            mrna_id = None
            for attr in attrs.split(';'):
                if attr.startswith('ID='):
                    mrna_id = attr[3:]
                    break
            
            if mrna_id:
                mrnas.append({
                    'chrom': chrom,
                    'start': int(start),
                    'end': int(end),
                    'mrna_id': mrna_id,
                    'strand': strand,
                    'species': species_prefix
                })
    
    return mrnas

def write_bed(mrnas, output_file, add_prefix=True):
    """写入BED文件"""
    # 按染色体和位置排序
    mrnas.sort(key=lambda x: (x['chrom'], x['start']))
    
    with open(output_file, 'w') as f:
        for m in mrnas:
            mrna_id = m['mrna_id']
            if add_prefix:
                mrna_id = f"{m['species']}_{mrna_id}"
            
            # JCVI BED格式: chrom start end name score strand
            # BED是0-based start
            f.write(f"{m['chrom']}\t{m['start']-1}\t{m['end']}\t{mrna_id}\t0\t{m['strand']}\n")
    
    return len(mrnas)

def main():
    base_dir = '/path/to/project_root'
    out_dir = f'{base_dir}/comparative_genomics/05_synteny/jcvi_data'
    os.makedirs(out_dir, exist_ok=True)
    
    # 定义物种和GFF文件
    species_gff = {
        'BH': f'{base_dir}/annotation/BH/structure/BH_genes.gff3',
        'CK': f'{base_dir}/annotation/CK/structure/CK_genes.gff3',
        'TAU': f'{base_dir}/results/C02/tau.gff3',
        'TCH': f'{base_dir}/results/C03/Tchinensis.gff3',
        'RSO': f'{base_dir}/results/C01/hs.chrom.genome.gff',
    }
    
    print("=" * 60)
    print("准备JCVI共线性分析数据 (仅mRNA)")
    print("=" * 60)
    
    for species, gff_file in species_gff.items():
        print(f"\n处理 {species}...")
        
        if not os.path.exists(gff_file):
            print(f"  警告: GFF文件不存在 {gff_file}")
            continue
        
        # 解析GFF - 只取mRNA
        mrnas = parse_gff_mrna(gff_file, species)
        print(f"  解析到 {len(mrnas)} 个mRNA")
        
        # 写入BED文件
        output_bed = f'{out_dir}/{species}.bed'
        count = write_bed(mrnas, output_bed, add_prefix=True)
        print(f"  输出到 {output_bed}")
    
    # 复制蛋白序列
    print("\n复制蛋白序列...")
    proteomes_dir = f'{base_dir}/comparative_genomics/01_proteomes/filtered'
    for species in species_gff.keys():
        src = f'{proteomes_dir}/{species}.fa'
        dst = f'{out_dir}/{species}.pep'
        if os.path.exists(src):
            # 使用硬链接或复制
            if os.path.exists(dst):
                os.remove(dst)
            os.symlink(src, dst)
            print(f"  {species}.pep -> {src}")
    
    print("\n" + "=" * 60)
    print(f"数据准备完成! 输出目录: {out_dir}")
    print("=" * 60)

if __name__ == '__main__':
    main()

