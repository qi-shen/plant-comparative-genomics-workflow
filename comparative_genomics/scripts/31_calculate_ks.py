#!/usr/bin/env python3
"""
最终可工作的Ks计算脚本
修复所有格式问题，使用正确的phylip格式
"""

import os
import subprocess
from Bio import SeqIO
import re
from multiprocessing import Pool

def clean_sequence(seq):
    """清理序列：去除末尾N，确保是3的倍数"""
    seq = seq.upper().rstrip('N')
    # 确保是3的倍数
    if len(seq) % 3 != 0:
        padding = 3 - (len(seq) % 3)
        seq = seq + 'N' * padding
    return seq

def create_phylip_strict(seq1, seq2, name1, name2, output_file):
    """创建严格的phylip格式文件（无空格分隔）"""
    seq1 = clean_sequence(seq1)
    seq2 = clean_sequence(seq2)
    
    # 对齐到相同长度
    max_len = max(len(seq1), len(seq2))
    if len(seq1) < max_len:
        seq1 = seq1 + 'N' * (max_len - len(seq1))
    if len(seq2) < max_len:
        seq2 = seq2 + 'N' * (max_len - len(seq2))
    
    # 再次确保是3的倍数
    if max_len % 3 != 0:
        padding = 3 - (max_len % 3)
        seq1 = seq1 + 'N' * padding
        seq2 = seq2 + 'N' * padding
        max_len += padding
    
    if max_len < 30:
        return None
    
    # phylip格式：名称10字符（无空格），直接接序列
    name1_clean = name1[:10].replace(' ', '_').replace('.', '_').ljust(10)
    name2_clean = name2[:10].replace(' ', '_').replace('.', '_').ljust(10)
    
    with open(output_file, 'w') as f:
        f.write(f" 2 {max_len}\n")
        f.write(f"{name1_clean}{seq1}\n")
        f.write(f"{name2_clean}{seq2}\n")
    
    return max_len

def create_tree_simple(name1, name2, output_file):
    """创建简单的树文件"""
    name1_clean = name1[:10].replace(' ', '_').replace('.', '_')
    name2_clean = name2[:10].replace(' ', '_').replace('.', '_')
    
    with open(output_file, 'w') as f:
        f.write(f"({name1_clean}:0.1,{name2_clean}:0.1);\n")

def create_ctl_file(work_dir):
    """创建codeml控制文件"""
    ctl_file = os.path.join(work_dir, "codeml.ctl")
    
    with open(ctl_file, 'w') as f:
        f.write("""      seqfile = seq.phy
     treefile = tree.nwk
      outfile = mlc

        noisy = 0
      verbose = 0
      runmode = 0

      seqtype = 1
    CodonFreq = 2

        ndata = 1
        icode = 0

    model = 0
      NSsites = 0

    fix_kappa = 0
        kappa = 2
    fix_omega = 0
        omega = 0.4

    fix_alpha = 1
        alpha = 0
       Malpha = 0
        ncatG = 10

        clock = 0
       getSE = 0
 RateAncestor = 1

   Small_Diff = .5e-6
       method = 0
""")
    return ctl_file

def extract_ks(work_dir):
    """提取Ks值"""
    # 优先检查2NG.dS
    ds_file = os.path.join(work_dir, "2NG.dS")
    if os.path.exists(ds_file) and os.path.getsize(ds_file) > 0:
        try:
            with open(ds_file, 'r') as f:
                content = f.read().strip()
                if content:
                    # 提取数字
                    numbers = re.findall(r'[\d.]+', content)
                    if numbers:
                        values = [float(n) for n in numbers if 0 <= float(n) <= 10]
                        if values:
                            return sum(values) / len(values)
        except:
            pass
    
    # 检查mlc
    mlc_file = os.path.join(work_dir, "mlc")
    if os.path.exists(mlc_file) and os.path.getsize(mlc_file) > 0:
        try:
            with open(mlc_file, 'r') as f:
                content = f.read()
                ds_match = re.search(r'dS\s*=\s*([\d.Ee+-]+)', content, re.IGNORECASE)
                if ds_match:
                    ks = float(ds_match.group(1))
                    if 0 <= ks <= 10:
                        return ks
        except:
            pass
    
    return None

def process_pair(args):
    """处理单对序列"""
    idx, gene1, gene2, seq1, seq2, work_base = args
    
    work_dir = os.path.join(work_base, f"pair_{idx}")
    os.makedirs(work_dir, exist_ok=True)
    
    try:
        seq_file = os.path.join(work_dir, "seq.phy")
        tree_file = os.path.join(work_dir, "tree.nwk")
        
        max_len = create_phylip_strict(seq1, seq2, gene1, gene2, seq_file)
        if max_len is None:
            return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': None, 'success': False}
        
        create_tree_simple(gene1, gene2, tree_file)
        create_ctl_file(work_dir)
        
        # 运行codeml
        result = subprocess.run(
            ['codeml', 'codeml.ctl'],
            cwd=work_dir,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            ks = extract_ks(work_dir)
            return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': ks, 'success': ks is not None}
        else:
            return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': None, 'success': False}
    except Exception as e:
        return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': None, 'success': False, 'error': str(e)[:30]}

def main():
    base_dir = "${PROJECT_ROOT}/comparative_genomics/04_wgd/ks_from_synteny"
    output_base = "${PROJECT_ROOT}/comparative_genomics/04_wgd/ks_results"
    
    print("=" * 60)
    print("Ks计算 - 最终版本")
    print("=" * 60)
    
    # 处理所有物种对
    total_pairs = 0
    total_success = 0
    
    for pair_name in ['T01_T02', 'T01_C02', 'T02_C02']:
        pair_dir = os.path.join(base_dir, pair_name)
        input_file = os.path.join(pair_dir, "kaks_input.fa")
        
        if not os.path.exists(input_file):
            continue
        
        print(f"\n处理 {pair_name}...")
        
        # 读取序列对
        pairs = []
        current = []
        with open(input_file, 'r') as f:
            for record in SeqIO.parse(f, "fasta"):
                current.append((record.id, str(record.seq)))
                if len(current) == 2:
                    pairs.append(current)
                    current = []
        
        print(f"  读取到 {len(pairs)} 对序列")
        
        # 过滤有效序列对
        valid_pairs = []
        for pair in pairs:
            g1, s1 = pair[0]
            g2, s2 = pair[1]
            s1_clean = clean_sequence(s1)
            s2_clean = clean_sequence(s2)
            if len(s1_clean) >= 30 and len(s2_clean) >= 30 and len(s1_clean) % 3 == 0 and len(s2_clean) % 3 == 0:
                valid_pairs.append((g1, g2, s1, s2))
        
        print(f"  有效序列对: {len(valid_pairs)}")
        
        if len(valid_pairs) == 0:
            continue
        
        # 准备输出
        output_dir = os.path.join(output_base, pair_name)
        os.makedirs(output_dir, exist_ok=True)
        work_base = os.path.join(output_dir, "codeml_work")
        os.makedirs(work_base, exist_ok=True)
        
        # 准备参数（先处理前100对测试）
        args_list = [(i, g1, g2, s1, s2, work_base) for i, (g1, g2, s1, s2) in enumerate(valid_pairs[:100])]
        
        # 并行处理
        print(f"  计算Ks值（使用32核心）...")
        with Pool(processes=32) as pool:
            results = pool.map(process_pair, args_list)
        
        # 保存结果
        output_file = os.path.join(output_dir, "ks_results.tsv")
        with open(output_file, 'w') as f:
            f.write("PairID\tGene1\tGene2\tKs\tSuccess\n")
            for r in results:
                ks_str = f"{r['ks']:.6f}" if r['ks'] is not None else "NA"
                success_str = "Yes" if r['success'] else "No"
                f.write(f"{r['idx']}\t{r['gene1']}\t{r['gene2']}\t{ks_str}\t{success_str}\n")
        
        successful = sum(1 for r in results if r['success'])
        valid_ks = [r['ks'] for r in results if r['ks'] is not None]
        
        print(f"  成功: {successful}/{len(results)}")
        if valid_ks:
            print(f"  Ks范围: {min(valid_ks):.4f} - {max(valid_ks):.4f}")
            print(f"  Ks平均: {sum(valid_ks)/len(valid_ks):.4f}")
        
        total_pairs += len(results)
        total_success += successful
    
    print("\n" + "=" * 60)
    print(f"总计: {total_pairs} 对序列, {total_success} 成功")
    print("=" * 60)

if __name__ == '__main__':
    main()

