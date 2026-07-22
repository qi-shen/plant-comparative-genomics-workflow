#!/usr/bin/env python3
"""
使用ID映射更新功能注释文件
"""

import sys
import pandas as pd

def update_annotation(input_file, mapping_file, output_file):
    """更新功能注释文件中的基因ID"""
    
    print(f"读取ID映射: {mapping_file}")
    mapping_df = pd.read_csv(mapping_file, sep='\t')
    
    # 创建从mRNA ID到新ID的映射
    # EVM的mRNA ID格式: evm.model.Chr01.1
    # 我们需要映射到 BH01G000001.1
    id_map = {}
    for _, row in mapping_df.iterrows():
        old_id = row['old_id']
        new_id = row['new_id']
        
        # 处理mRNA ID
        if old_id.startswith('evm.model.'):
            # 从 evm.model.Chr01.1 提取 Chr01.1
            parts = old_id.replace('evm.model.', '').split('.')
            if len(parts) >= 2:
                transcript_id = f"{parts[0]}.{parts[1]}"
                id_map[transcript_id] = new_id
        
        # 处理gene ID
        if old_id.startswith('evm.TU.'):
            gene_part = old_id.replace('evm.TU.', '')
            id_map[gene_part] = new_id
    
    print(f"映射条目数: {len(id_map)}")
    
    print(f"读取功能注释: {input_file}")
    try:
        anno_df = pd.read_csv(input_file, sep='\t')
    except Exception as e:
        print(f"错误: {e}")
        return 0, 0
    
    if 'Gene_ID' not in anno_df.columns:
        print("警告: 找不到Gene_ID列")
        print(f"列名: {list(anno_df.columns)}")
        return 0, 0
    
    updated = 0
    unmapped = 0
    
    for idx, row in anno_df.iterrows():
        old_gene_id = str(row['Gene_ID'])
        
        # 尝试多种映射方式
        new_id = None
        
        # 直接映射
        if old_gene_id in id_map:
            new_id = id_map[old_gene_id]
        else:
            # 尝试添加.t1后缀
            if f"{old_gene_id}" in id_map:
                new_id = id_map[f"{old_gene_id}"]
        
        if new_id:
            anno_df.at[idx, 'Gene_ID'] = new_id
            updated += 1
        else:
            unmapped += 1
    
    print(f"更新: {updated}, 未映射: {unmapped}")
    
    anno_df.to_csv(output_file, sep='\t', index=False)
    print(f"保存到: {output_file}")
    
    return updated, unmapped

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <input_annotation> <mapping_file> <output_annotation>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    mapping_file = sys.argv[2]
    output_file = sys.argv[3]
    
    update_annotation(input_file, mapping_file, output_file)

