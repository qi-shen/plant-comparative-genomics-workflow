#!/usr/bin/env python3
"""
修复codeml问题并运行Ks计算
使用更简单的方法：直接使用PAML的2-parameter模型
"""

import os
import subprocess
from Bio import SeqIO
import re
from multiprocessing import Pool

def create_proper_phylip(seq1, seq2, gene1_id, gene2_id, output_file):
    """创建正确的phylip格式文件"""
    seq1 = seq1.upper().rstrip('N')
    seq2 = seq2.upper().rstrip('N')
    
    # 对齐到相同长度
    max_len = max(len(seq1), len(seq2))
    if len(seq1) < max_len:
        seq1 = seq1 + 'N' * (max_len - len(seq1))
    if len(seq2) < max_len:
        seq2 = seq2 + 'N' * (max_len - len(seq2))
    
    # 确保是3的倍数
    if max_len % 3 != 0:
        padding = 3 - (max_len % 3)
        seq1 = seq1 + 'N' * padding
        seq2 = seq2 + 'N' * padding
        max_len += padding
    
    if max_len < 30:
        return None
    
    # 创建phylip格式（名称10字符+空格+序列）
    with open(output_file, 'w') as f:
        f.write(f" 2 {max_len}\n")  # 注意前面有空格
        name1 = (gene1_id[:9] + '_').replace(' ', '_').replace('.', '_')
        name2 = (gene2_id[:9] + '_').replace(' ', '_').replace('.', '_')
        f.write(f"{name1:<10} {seq1}\n")
        f.write(f"{name2:<10} {seq2}\n")
    
    return max_len

def create_simple_tree(gene1_id, gene2_id, output_file):
    """创建简单的树文件"""
    name1 = gene1_id[:9].replace(' ', '_').replace('.', '_')
    name2 = gene2_id[:9].replace(' ', '_').replace('.', '_')
    
    with open(output_file, 'w') as f:
        f.write(f"({name1}:0.1,{name2}:0.1);\n")

def create_simple_ctl(work_dir):
    """创建简化的codeml控制文件"""
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

def run_codeml_single(work_dir):
    """运行单个codeml分析"""
    try:
        result = subprocess.run(
            ['codeml', 'codeml.ctl'],
            cwd=work_dir,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.returncode == 0
    except:
        return False

def extract_ks_from_files(work_dir):
    """从codeml输出文件提取Ks值"""
    # 检查2NG.dS
    ds_file = os.path.join(work_dir, "2NG.dS")
    if os.path.exists(ds_file) and os.path.getsize(ds_file) > 0:
        try:
            with open(ds_file, 'r') as f:
                content = f.read().strip()
                if content:
                    # 提取所有数字
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

def process_single_pair(args):
    """处理单对序列"""
    idx, gene1, gene2, seq1, seq2, work_base = args
    
    work_dir = os.path.join(work_base, f"p{idx}")
    os.makedirs(work_dir, exist_ok=True)
    
    try:
        seq_file = os.path.join(work_dir, "seq.phy")
        tree_file = os.path.join(work_dir, "tree.nwk")
        
        max_len = create_proper_phylip(seq1, seq2, gene1, gene2, seq_file)
        if max_len is None:
            return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': None, 'success': False}
        
        create_simple_tree(gene1, gene2, tree_file)
        create_simple_ctl(work_dir)
        
        # 运行codeml
        if run_codeml_single(work_dir):
            ks = extract_ks_from_files(work_dir)
            return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': ks, 'success': ks is not None}
        else:
            return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': None, 'success': False}
    except Exception as e:
        return {'idx': idx, 'gene1': gene1, 'gene2': gene2, 'ks': None, 'success': False, 'error': str(e)[:30]}

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
    output_base = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    
    print("=" * 60)
    print("Ks计算（修复版）")
    print("=" * 60)
    
    # 只处理T01_T02进行测试
    pair_dir = os.path.join(base_dir, "T01_T02")
    input_file = os.path.join(pair_dir, "kaks_input.fa")
    
    if not os.path.exists(input_file):
        print(f"文件不存在: {input_file}")
        return
    
    # 读取前20对进行测试
    pairs = []
    current = []
    with open(input_file, 'r') as f:
        for record in SeqIO.parse(f, "fasta"):
            current.append((record.id, str(record.seq)))
            if len(current) == 2:
                pairs.append(current)
                current = []
                if len(pairs) >= 20:
                    break
    
    print(f"处理 {len(pairs)} 对序列...")
    
    work_base = os.path.join(output_base, "T01_T02", "codeml_test")
    os.makedirs(work_base, exist_ok=True)
    
    # 准备参数
    args_list = []
    for i, pair in enumerate(pairs):
        g1, s1 = pair[0]
        g2, s2 = pair[1]
        if len(s1) % 3 == 0 and len(s2) % 3 == 0 and len(s1) >= 30 and len(s2) >= 30:
            args_list.append((i, g1, g2, s1, s2, work_base))
    
    # 串行运行（便于调试）
    results = []
    for args in args_list[:5]:  # 只测试前5对
        result = process_single_pair(args)
        results.append(result)
        if result['success']:
            print(f"  ✅ {result['gene1']} vs {result['gene2']}: Ks = {result['ks']:.4f}")
        else:
            print(f"  ❌ {result['gene1']} vs {result['gene2']}: 失败")
    
    successful = sum(1 for r in results if r['success'])
    print(f"\n成功: {successful}/{len(results)}")
    
    if successful > 0:
        print("\n✅ codeml可以正常工作，可以批量运行")
    else:
        print("\n❌ codeml仍有问题，需要进一步调试")

if __name__ == '__main__':
    main()

