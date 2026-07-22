#!/usr/bin/env python3
"""
改进的PAML codeml批量Ks计算
修复序列格式问题，改进结果解析
"""

import os
import subprocess
from Bio import SeqIO
import re
from multiprocessing import Pool
import shutil

def create_phylip_file(seq1, seq2, gene1_id, gene2_id, output_file):
    """创建phylip格式的序列文件（改进版）"""
    # 去除末尾的N
    seq1 = seq1.rstrip('N').upper()
    seq2 = seq2.rstrip('N').upper()
    
    # 确保序列长度一致
    max_len = max(len(seq1), len(seq2))
    if len(seq1) < max_len:
        seq1 = seq1 + 'N' * (max_len - len(seq1))
    if len(seq2) < max_len:
        seq2 = seq2 + 'N' * (max_len - len(seq2))
    
    # 确保长度是3的倍数
    if max_len % 3 != 0:
        padding = 3 - (max_len % 3)
        seq1 = seq1 + 'N' * padding
        seq2 = seq2 + 'N' * padding
        max_len += padding
    
    if max_len < 30:
        return None
    
    # 创建phylip格式（严格格式：名称10字符，空格，序列）
    with open(output_file, 'w') as f:
        f.write(f"2 {max_len}\n")
        name1 = gene1_id[:10].replace(' ', '_').replace('.', '_').ljust(10)
        name2 = gene2_id[:10].replace(' ', '_').replace('.', '_').ljust(10)
        f.write(f"{name1} {seq1}\n")
        f.write(f"{name2} {seq2}\n")
    
    return max_len

def create_tree_file(gene1_id, gene2_id, output_file):
    """创建树文件"""
    name1 = gene1_id[:10].replace(' ', '_').replace('.', '_')
    name2 = gene2_id[:10].replace(' ', '_').replace('.', '_')
    
    with open(output_file, 'w') as f:
        f.write(f"({name1}:0.1,{name2}:0.1);\n")

def create_codeml_ctl(seq_file, tree_file, work_dir):
    """创建codeml控制文件（使用model=0, NSsites=0）"""
    ctl_file = os.path.join(work_dir, "codeml.ctl")
    
    with open(ctl_file, 'w') as f:
        f.write(f"""      seqfile = {os.path.basename(seq_file)}
     treefile = {os.path.basename(tree_file)}
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

def parse_codeml_result(work_dir):
    """从codeml结果文件中解析Ks值（改进版）"""
    # 优先检查2NG.dS文件（Nei-Gojobori方法）
    ds_file = os.path.join(work_dir, "2NG.dS")
    if os.path.exists(ds_file) and os.path.getsize(ds_file) > 0:
        try:
            with open(ds_file, 'r') as f:
                content = f.read().strip()
                if content:
                    # 可能是单行或多行
                    lines = [l.strip() for l in content.split('\n') if l.strip() and not l.startswith('#')]
                    if lines:
                        values = []
                        for line in lines:
                            # 尝试提取数字
                            nums = re.findall(r'[\d.]+', line)
                            for num_str in nums:
                                try:
                                    val = float(num_str)
                                    if 0 <= val <= 10:
                                        values.append(val)
                                except:
                                    continue
                        if values:
                            return sum(values) / len(values)
        except:
            pass
    
    # 检查mlc文件
    mlc_file = os.path.join(work_dir, "mlc")
    if os.path.exists(mlc_file) and os.path.getsize(mlc_file) > 0:
        try:
            with open(mlc_file, 'r') as f:
                content = f.read()
                # 查找dS值
                patterns = [
                    r'dS\s*=\s*([\d.Ee+-]+)',
                    r'dS\s+([\d.Ee+-]+)',
                    r'synonymous.*?([\d.Ee+-]+)',
                ]
                for pattern in patterns:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    if matches:
                        try:
                            ks_value = float(matches[-1])
                            if 0 <= ks_value <= 10:
                                return ks_value
                        except:
                            continue
        except:
            pass
    
    return None

def calculate_ks_single_pair(args):
    """计算单对序列的Ks值（改进版）"""
    pair_idx, gene1_id, gene2_id, seq1, seq2, work_base = args
    
    work_dir = os.path.join(work_base, f"pair_{pair_idx}")
    os.makedirs(work_dir, exist_ok=True)
    
    try:
        # 创建输入文件
        seq_file = os.path.join(work_dir, "seq.phy")
        tree_file = os.path.join(work_dir, "tree.nwk")
        
        max_len = create_phylip_file(seq1, seq2, gene1_id, gene2_id, seq_file)
        if max_len is None:
            return {'pair_idx': pair_idx, 'gene1': gene1_id, 'gene2': gene2_id, 'ks': None, 'success': False, 'error': 'invalid_seq'}
        
        create_tree_file(gene1_id, gene2_id, tree_file)
        ctl_file = create_codeml_ctl(seq_file, tree_file, work_dir)
        
        # 运行codeml
        result = subprocess.run(
            ['codeml', 'codeml.ctl'],
            cwd=work_dir,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        # 解析结果
        ks_value = parse_codeml_result(work_dir)
        
        # 清理临时文件（可选，保留用于调试）
        # if ks_value is not None:
        #     shutil.rmtree(work_dir)
        
        return {
            'pair_idx': pair_idx,
            'gene1': gene1_id,
            'gene2': gene2_id,
            'ks': ks_value,
            'success': ks_value is not None
        }
        
    except subprocess.TimeoutExpired:
        return {'pair_idx': pair_idx, 'gene1': gene1_id, 'gene2': gene2_id, 'ks': None, 'success': False, 'error': 'timeout'}
    except Exception as e:
        return {'pair_idx': pair_idx, 'gene1': gene1_id, 'gene2': gene2_id, 'ks': None, 'success': False, 'error': str(e)[:50]}

def process_pairs_parallel(input_file, output_file, max_pairs=100, n_cores=32):
    """并行处理序列对（改进版）"""
    pairs = []
    current_pair = []
    
    with open(input_file, 'r') as f:
        for record in SeqIO.parse(f, "fasta"):
            current_pair.append((record.id, str(record.seq)))
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
                if len(pairs) >= max_pairs:
                    break
    
    print(f"  处理 {len(pairs)} 对序列（使用 {n_cores} 核心）...")
    
    work_base = os.path.join(os.path.dirname(output_file), "codeml_work")
    os.makedirs(work_base, exist_ok=True)
    
    # 准备参数
    args_list = []
    for i, pair in enumerate(pairs):
        gene1_id, seq1 = pair[0]
        gene2_id, seq2 = pair[1]
        
        if len(seq1) % 3 == 0 and len(seq2) % 3 == 0 and len(seq1) >= 30 and len(seq2) >= 30:
            args_list.append((i, gene1_id, gene2_id, seq1, seq2, work_base))
    
    # 并行计算
    results = []
    if args_list:
        with Pool(processes=n_cores) as pool:
            results = pool.map(calculate_ks_single_pair, args_list)
    
    # 保存结果
    with open(output_file, 'w') as f:
        f.write("PairID\tGene1\tGene2\tKs\tSuccess\n")
        for r in results:
            ks_str = f"{r['ks']:.6f}" if r['ks'] is not None else "NA"
            success_str = "Yes" if r['success'] else "No"
            f.write(f"{r['pair_idx']}\t{r['gene1']}\t{r['gene2']}\t{ks_str}\t{success_str}\n")
    
    # 统计
    successful = sum(1 for r in results if r['success'])
    valid_ks = [r['ks'] for r in results if r['ks'] is not None]
    
    print(f"  成功计算: {successful}/{len(results)}")
    if valid_ks:
        print(f"  Ks值范围: {min(valid_ks):.4f} - {max(valid_ks):.4f}")
        print(f"  Ks平均值: {sum(valid_ks)/len(valid_ks):.4f}")
    
    return len(results), successful

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
    output_base = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    
    print("=" * 60)
    print("使用PAML codeml批量计算Ks值（改进版）")
    print("=" * 60)
    
    # 检查codeml
    try:
        result = subprocess.run(['codeml'], capture_output=True, timeout=5)
    except:
        print("错误: codeml未找到")
        return
    
    total_pairs = 0
    total_success = 0
    
    for pair_dir in os.listdir(base_dir):
        pair_path = os.path.join(base_dir, pair_dir)
        if not os.path.isdir(pair_path):
            continue
        
        input_file = os.path.join(pair_path, "kaks_input.fa")
        if not os.path.exists(input_file):
            input_file = os.path.join(pair_path, "cds_pairs.fa")
        
        if not os.path.exists(input_file):
            continue
        
        output_dir = os.path.join(output_base, pair_dir)
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, "ks_results.tsv")
        
        print(f"\n处理 {pair_dir}...")
        
        # 先处理前50对进行测试
        count, success = process_pairs_parallel(
            input_file, 
            output_file, 
            max_pairs=50,  # 测试用
            n_cores=32
        )
        
        total_pairs += count
        total_success += success
        print(f"  结果已保存: {output_file}")
    
    print("\n" + "=" * 60)
    print(f"Ks计算完成")
    print(f"总计: {total_pairs} 对序列, {total_success} 成功")
    print("=" * 60)

if __name__ == '__main__':
    main()

