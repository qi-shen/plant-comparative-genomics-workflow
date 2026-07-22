#!/usr/bin/env python3
"""
解析所有PAML分析结果
提取正选择基因信息
"""

import os
import re
import pandas as pd
from glob import glob

def parse_mlc_file(mlc_file):
    """解析PAML mlc文件，提取dN/dS等信息"""
    results = {
        'omega': None,
        'dN': None,
        'dS': None,
        'dN_dS': None,
        'lnL': None,
        'success': False
    }
    
    if not os.path.exists(mlc_file) or os.path.getsize(mlc_file) == 0:
        return results
    
    try:
        with open(mlc_file, 'r') as f:
            lines = f.readlines()
            # 读取最后200行（通常omega值在文件末尾）
            content = ''.join(lines[-200:])
            full_content = ''.join(lines)  # 也保留完整内容用于其他搜索
            
            # 提取omega (dN/dS) - 多种格式
            omega_patterns = [
                r'omega\s*\(dN/dS\)\s*=\s*([\d.Ee+-]+)',
                r'omega\s*=\s*([\d.Ee+-]+)',
                r'dN/dS\s*=\s*([\d.Ee+-]+)',
                r'w\s*=\s*([\d.Ee+-]+)',
                r'w\s+\(dN/dS\)\s+([\d.Ee+-]+)',  # 空格分隔
            ]
            for pattern in omega_patterns:
                omega_match = re.search(pattern, content, re.IGNORECASE)
                if omega_match:
                    try:
                        results['omega'] = float(omega_match.group(1))
                        break
                    except:
                        continue
            
            # 提取dN - 多种格式
            dn_patterns = [
                r'dN\s*=\s*([\d.Ee+-]+)',
                r'dN:\s*([\d.Ee+-]+)',
            ]
            for pattern in dn_patterns:
                dn_match = re.search(pattern, content, re.IGNORECASE)
                if dn_match:
                    try:
                        results['dN'] = float(dn_match.group(1))
                        break
                    except:
                        continue
            
            # 提取dS - 多种格式
            ds_patterns = [
                r'dS\s*=\s*([\d.Ee+-]+)',
                r'dS:\s*([\d.Ee+-]+)',
            ]
            for pattern in ds_patterns:
                ds_match = re.search(pattern, content, re.IGNORECASE)
                if ds_match:
                    try:
                        results['dS'] = float(ds_match.group(1))
                        break
                    except:
                        continue
            
            # 提取lnL - 多种格式
            lnl_patterns = [
                r'lnL\s*\(ntime:\s*\d+\):\s*([\d.Ee+-]+)',
                r'lnL\s*\(nt:\s*\d+\):\s*([\d.Ee+-]+)',
                r'lnL\s*=\s*([\d.Ee+-]+)',
                r'lnL:\s*([\d.Ee+-]+)',
            ]
            for pattern in lnl_patterns:
                lnl_match = re.search(pattern, content, re.IGNORECASE)
                if lnl_match:
                    try:
                        results['lnL'] = float(lnl_match.group(1))
                        break
                    except:
                        continue
            
            # 尝试从Nei & Gojobori部分提取dN/dS
            # 查找Nei & Gojobori部分
            nei_start = full_content.find('Nei & Gojobori')
            if nei_start != -1:
                nei_section = full_content[nei_start:nei_start+2000]  # 取后面2000字符
                # 查找所有dN/dS值（格式：1.1757 (2.0102 1.7098)）
                nei_values = re.findall(r'(\d+\.\d+)\s*\(([\d.]+)\s+([\d.]+)\)', nei_section)
                if nei_values:
                    # 取第一个非-1的值
                    for dnds, dn, ds in nei_values:
                        try:
                            dnds_val = float(dnds)
                            if dnds_val > 0 and dnds_val != -1.0:
                                results['omega'] = dnds_val
                                results['dN'] = float(dn)
                                results['dS'] = float(ds)
                                results['dN_dS'] = dnds_val
                                results['success'] = True
                                break
                        except:
                            continue
            
            # 如果找到omega，认为成功
            if results['omega'] is not None:
                results['success'] = True
                # 如果没有单独的dN/dS，使用omega
                if results['dN_dS'] is None:
                    results['dN_dS'] = results['omega']
    except Exception as e:
        print(f"  解析错误 {mlc_file}: {e}")
    
    return results

def main():
    paml_dir = "/path/to/project_root/comparative_genomics/06_selection/paml_alignments"
    output_file = "/path/to/project_root/comparative_genomics/06_selection/paml_results_summary.tsv"
    
    print("=" * 60)
    print("解析PAML分析结果")
    print("=" * 60)
    
    # 查找所有OG目录
    og_dirs = sorted([d for d in glob(os.path.join(paml_dir, "OG*")) if os.path.isdir(d)])
    
    print(f"\n找到 {len(og_dirs)} 个基因家族目录")
    
    results = []
    
    for og_dir in og_dirs:
        family_id = os.path.basename(og_dir)
        mlc_file = os.path.join(og_dir, "mlc")
        
        result = parse_mlc_file(mlc_file)
        result['FamilyID'] = family_id
        results.append(result)
    
    # 转换为DataFrame
    df = pd.DataFrame(results)
    
    # 统计
    successful = df['success'].sum()
    print(f"\n成功解析: {successful} / {len(df)} ({successful/len(df)*100:.1f}%)")
    
    # 筛选正选择基因（omega > 1）
    positive_selection = df[(df['omega'] > 1) & (df['omega'].notna())]
    print(f"正选择基因（omega > 1）: {len(positive_selection)} 个")
    
    if len(positive_selection) > 0:
        print(f"  omega范围: {positive_selection['omega'].min():.4f} - {positive_selection['omega'].max():.4f}")
        print(f"  omega平均值: {positive_selection['omega'].mean():.4f}")
    
    # 保存结果
    df.to_csv(output_file, sep='\t', index=False)
    print(f"\n结果已保存: {output_file}")
    
    # 保存正选择基因列表
    if len(positive_selection) > 0:
        ps_output = "/path/to/project_root/comparative_genomics/06_selection/positive_selection_genes.tsv"
        positive_selection.to_csv(ps_output, sep='\t', index=False)
        print(f"正选择基因列表已保存: {ps_output}")
    
    # 显示前10个正选择基因
    if len(positive_selection) > 0:
        print("\n前10个正选择基因（按omega排序）:")
        top_ps = positive_selection.nlargest(10, 'omega')
        for idx, row in top_ps.iterrows():
            dn_str = f"{row['dN']:.4f}" if pd.notna(row['dN']) else "NA"
            ds_str = f"{row['dS']:.4f}" if pd.notna(row['dS']) else "NA"
            print(f"  {row['FamilyID']}: omega={row['omega']:.4f}, dN={dn_str}, dS={ds_str}")
    
    print("\n" + "=" * 60)

if __name__ == '__main__':
    main()

