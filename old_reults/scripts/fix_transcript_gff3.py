#!/usr/bin/env python3
"""
修复转录组GFF3格式，为exon添加ID属性
"""

import sys
import re

def fix_transcript_gff3(input_file, output_file, source_name):
    exon_counts = {}
    
    with open(input_file, 'r') as fin, open(output_file, 'w') as fout:
        for line in fin:
            if line.startswith('#'):
                fout.write(line)
                continue
            
            parts = line.strip().split('\t')
            if len(parts) < 9:
                continue
            
            # 修改source列
            parts[1] = source_name
            
            feature_type = parts[2]
            attributes = parts[8]
            
            if feature_type == 'transcript':
                # 转换为mRNA
                parts[2] = 'mRNA'
                # 提取ID
                id_match = re.search(r'ID=([^;]+)', attributes)
                if id_match:
                    mrna_id = id_match.group(1)
                    exon_counts[mrna_id] = 0
                fout.write('\t'.join(parts) + '\n')
                
            elif feature_type == 'exon':
                # 提取Parent
                parent_match = re.search(r'Parent=([^;]+)', attributes)
                if parent_match:
                    parent_id = parent_match.group(1)
                    if parent_id not in exon_counts:
                        exon_counts[parent_id] = 0
                    exon_counts[parent_id] += 1
                    exon_num = exon_counts[parent_id]
                    
                    # 添加ID到attributes
                    new_id = f"{parent_id}.exon{exon_num}"
                    parts[8] = f"ID={new_id};{attributes}"
                    
                fout.write('\t'.join(parts) + '\n')

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <input_gff3> <output_gff3> <source_name>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    source_name = sys.argv[3]
    
    fix_transcript_gff3(input_file, output_file, source_name)
    print(f"Done: {output_file}")

