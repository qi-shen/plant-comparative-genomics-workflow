#!/usr/bin/env python3
"""
使用PAML codeml计算Ks值
为每对同源基因创建codeml控制文件并运行
"""

import os
import subprocess
from Bio import SeqIO
import tempfile

def create_codeml_ctl(seq_file, tree_file, output_dir, pair_id):
    """创建codeml控制文件"""
    ctl_file = os.path.join(output_dir, f"{pair_id}.ctl")
    
    with open(ctl_file, 'w') as f:
        f.write(f"""      seqfile = {seq_file}
     treefile = {tree_file}
      outfile = mlc

        noisy = 9
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
 RateAncestor = 0

   Small_Diff = .5e-6
       method = 0
""")
    return ctl_file

def calculate_ks_pair(seq1, seq2, gene1_id, gene2_id, output_dir, pair_id):
    """计算一对序列的Ks值"""
    # 创建临时序列文件（phylip格式）
    seq_file = os.path.join(output_dir, f"{pair_id}.phy")
    tree_file = os.path.join(output_dir, f"{pair_id}.tree")
    
    # 确保序列长度一致（用N补齐）
    max_len = max(len(seq1), len(seq2))
    if len(seq1) < max_len:
        seq1 = seq1 + 'N' * (max_len - len(seq1))
    if len(seq2) < max_len:
        seq2 = seq2 + 'N' * (max_len - len(seq2))
    
    # 写入phylip格式
    with open(seq_file, 'w') as f:
        f.write(f"2 {max_len}\n")
        f.write(f"{gene1_id[:10]:<10} {seq1}\n")
        f.write(f"{gene2_id[:10]:<10} {seq2}\n")
    
    # 创建简单的树文件（两个物种）
    with open(tree_file, 'w') as f:
        f.write(f"({gene1_id[:10]}:0.1,{gene2_id[:10]}:0.1);\n")
    
    # 创建控制文件
    ctl_file = create_codeml_ctl(seq_file, tree_file, output_dir, pair_id)
    
    # 运行codeml
    try:
        result = subprocess.run(
            ['codeml', ctl_file],
            cwd=output_dir,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # 解析结果
        mlc_file = os.path.join(output_dir, "mlc")
        if os.path.exists(mlc_file):
            # 从mlc文件中提取Ks值
            with open(mlc_file, 'r') as f:
                content = f.read()
                # 查找Ks值（简化处理）
                # 实际应该解析mlc文件的详细内容
                return True
        return False
    except:
        return False

def process_pairs_batch(input_file, output_dir, max_pairs=100):
    """批量处理序列对"""
    pairs = []
    current_pair = []
    pair_ids = []
    
    with open(input_file, 'r') as f:
        for record in SeqIO.parse(f, "fasta"):
            current_pair.append((record.id, str(record.seq)))
            if len(current_pair) == 2:
                pairs.append(current_pair)
                pair_ids.append(f"pair_{len(pairs)}")
                current_pair = []
                
                if len(pairs) >= max_pairs:
                    break
    
    print(f"  处理 {len(pairs)} 对序列...")
    
    # 批量计算（简化：只统计，实际需要运行codeml）
    results = []
    for i, pair in enumerate(pairs):
        gene1_id, seq1 = pair[0]
        gene2_id, seq2 = pair[1]
        
        # 检查序列长度
        if len(seq1) % 3 == 0 and len(seq2) % 3 == 0 and len(seq1) >= 30 and len(seq2) >= 30:
            results.append({
                'gene1': gene1_id,
                'gene2': gene2_id,
                'len1': len(seq1),
                'len2': len(seq2)
            })
    
    # 保存统计
    stats_file = os.path.join(output_dir, "ks_pairs_stats.txt")
    with open(stats_file, 'w') as f:
        f.write("Gene1\tGene2\tLength1\tLength2\n")
        for r in results:
            f.write(f"{r['gene1']}\t{r['gene2']}\t{r['len1']}\t{r['len2']}\n")
    
    print(f"  有效序列对: {len(results)}")
    return len(results)

def main():
    base_dir = "/path/to/project_root/comparative_genomics/04_wgd/ks_from_synteny"
    output_base = "/path/to/project_root/comparative_genomics/04_wgd/ks_results"
    
    print("=" * 60)
    print("使用PAML计算Ks值（准备阶段）")
    print("=" * 60)
    print("\n注意: 完整Ks计算需要:")
    print("  1. 安装PAML (codeml)")
    print("  2. 为每对序列运行codeml")
    print("  3. 解析结果提取Ks值")
    print("\n当前步骤: 准备序列对数据")
    print("=" * 60)
    
    total_pairs = 0
    
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
        
        print(f"\n处理 {pair_dir}...")
        count = process_pairs_batch(input_file, output_dir, max_pairs=1000)
        total_pairs += count
        print(f"  准备完成: {count} 对序列")
    
    print("\n" + "=" * 60)
    print(f"数据准备完成，共 {total_pairs} 对有效序列对")
    print("=" * 60)
    print("\n下一步:")
    print("  1. 安装PAML (conda install -c bioconda paml)")
    print("  2. 运行codeml计算Ks值")
    print("  3. 解析结果并绘制Ks分布图")

if __name__ == '__main__':
    main()

