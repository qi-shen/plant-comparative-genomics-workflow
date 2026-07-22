#!/usr/bin/env python3
"""
使用ID映射表更新功能注释文件中的基因ID
"""

import sys

def load_mapping(mapping_file):
    """加载ID映射表"""
    mapping = {}
    with open(mapping_file, 'r') as f:
        next(f)  # 跳过表头
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) == 2:
                mapping[parts[0]] = parts[1]
    return mapping

def update_annotation(input_file, output_file, mapping):
    """更新功能注释文件中的基因ID"""
    updated = 0
    not_found = 0
    
    with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
        # 写入表头
        header = f_in.readline()
        f_out.write(header)
        
        for line in f_in:
            parts = line.strip().split('\t')
            if parts:
                old_id = parts[0]
                if old_id in mapping:
                    parts[0] = mapping[old_id]
                    updated += 1
                else:
                    not_found += 1
                f_out.write('\t'.join(parts) + '\n')
    
    print(f"更新: {updated} 行", file=sys.stderr)
    print(f"未找到映射: {not_found} 行", file=sys.stderr)

def main():
    if len(sys.argv) != 4:
        print("Usage: python update_annotation_ids.py <annotation.txt> <mapping.tsv> <output.txt>")
        sys.exit(1)
    
    mapping = load_mapping(sys.argv[2])
    print(f"加载映射: {len(mapping)} 条记录", file=sys.stderr)
    update_annotation(sys.argv[1], sys.argv[3], mapping)

if __name__ == '__main__':
    main()

