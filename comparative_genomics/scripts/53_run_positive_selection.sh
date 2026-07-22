#!/bin/bash
# 正选择分析 - 近缘类群5物种
# T01和T02作为前景枝，C02/C03/C01作为背景枝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

BASE_DIR="${PROJECT_ROOT}/comparative_genomics"
WORK_DIR="$BASE_DIR/06_selection"
OF_DIR="$BASE_DIR/02_orthofinder_results/Results_Jan12"
THREADS=16

echo "=========================================="
echo "正选择分析 - 近缘类群5物种"
echo "开始时间: $(date)"
echo "=========================================="

source $(conda info --base)/etc/profile.d/conda.sh
conda activate wgd

mkdir -p "$WORK_DIR"/{cds_seqs,alignments,paml_input,paml_output}
cd "$WORK_DIR"

# CDS文件路径
declare -A CDS_FILES=(
    ["T01"]="$BASE_DIR/../new_anno/T01.final.cds.fa"
    ["T02"]="$BASE_DIR/../new_anno/T02.final.cds.fa"
    ["C02"]="$BASE_DIR/../old_reults/results/C02/cds.fa"
    ["C03"]="$BASE_DIR/../old_reults/results/comp/C03/cds.fa"
    ["C01"]="$BASE_DIR/../old_reults/results/C01/C01.cds.fa"
)

# Step 1: 建立CDS索引
echo ""
echo "Step 1: 建立CDS序列索引..."
for sp in T01 T02 C02 C03 C01; do
    if [ ! -f "cds_seqs/${sp}.cds.index" ]; then
        python3 << PYEOF
import os
cds_file = "${CDS_FILES[$sp]}"
index = {}
current_id = None
current_seq = []

with open(cds_file) as f:
    for line in f:
        if line.startswith('>'):
            if current_id:
                index[current_id] = ''.join(current_seq)
            current_id = line[1:].split()[0]
            current_seq = []
        else:
            current_seq.append(line.strip())
    if current_id:
        index[current_id] = ''.join(current_seq)

# 保存为简单格式
with open("cds_seqs/${sp}.cds.fa", "w") as f:
    for gid, seq in index.items():
        f.write(f">${sp}_{gid}\n{seq}\n")
print(f"  $sp: {len(index)} 条CDS序列")
PYEOF
    fi
done

# Step 2: 提取单拷贝基因CDS序列
echo ""
echo "Step 2: 提取单拷贝基因CDS序列..."

python3 << 'PYEOF'
import os

# 读取单拷贝基因列表
with open("target_single_copy_orthogroups.txt") as f:
    sc_ogs = [line.strip() for line in f if line.strip()]

print(f"  共 {len(sc_ogs)} 个单拷贝基因家族")

# 读取Orthogroups
og_file = "../02_orthofinder_results/Results_Jan12/Orthogroups/Orthogroups.tsv"
target_species = ["T01", "T02", "C02", "C03", "C01"]

og_genes = {}
with open(og_file) as f:
    header = f.readline().strip().split('\t')
    species_idx = {sp: header.index(sp) for sp in target_species}

    for line in f:
        parts = line.strip().split('\t')
        og = parts[0]
        if og in sc_ogs:
            og_genes[og] = {}
            for sp, idx in species_idx.items():
                if idx < len(parts) and parts[idx].strip():
                    og_genes[og][sp] = parts[idx].strip()

# 读取CDS序列
cds_seqs = {}
for sp in target_species:
    cds_seqs[sp] = {}
    with open(f"cds_seqs/{sp}.cds.fa") as f:
        current_id = None
        current_seq = []
        for line in f:
            if line.startswith('>'):
                if current_id:
                    cds_seqs[sp][current_id] = ''.join(current_seq)
                current_id = line[1:].strip().replace(f"{sp}_", "")
                current_seq = []
            else:
                current_seq.append(line.strip())
        if current_id:
            cds_seqs[sp][current_id] = ''.join(current_seq)

# 提取每个OG的CDS序列
extracted = 0
for og in sc_ogs[:500]:  # 先处理前500个
    if og not in og_genes:
        continue

    outfile = f"cds_seqs/{og}.cds.fa"
    with open(outfile, "w") as f:
        for sp in target_species:
            if sp in og_genes[og]:
                gene_id = og_genes[og][sp]
                if gene_id in cds_seqs[sp]:
                    seq = cds_seqs[sp][gene_id]
                    # 确保序列长度是3的倍数
                    seq = seq[:len(seq) - len(seq) % 3]
                    f.write(f">{sp}\n{seq}\n")
    extracted += 1

print(f"  已提取 {extracted} 个基因家族的CDS序列")
PYEOF

# Step 3: 多序列比对
echo ""
echo "Step 3: 运行MAFFT比对..."
cd cds_seqs

count=0
total=$(ls OG*.cds.fa 2>/dev/null | wc -l)
for fa in OG*.cds.fa; do
    og="${fa%.cds.fa}"
    if [ ! -f "../alignments/${og}.aln.fa" ]; then
        mafft --auto --quiet "$fa" > "../alignments/${og}.aln.fa" 2>/dev/null
    fi
    count=$((count + 1))
    if [ $((count % 100)) -eq 0 ]; then
        echo "  已比对 $count / $total"
    fi
done
echo "  比对完成: $count 个基因家族"

cd "$WORK_DIR"

# Step 4: 准备PAML输入
echo ""
echo "Step 4: 准备PAML输入文件..."

python3 << 'PYEOF'
import os
import glob

def fasta_to_phylip(fasta_file, phylip_file):
    """转换FASTA为PHYLIP格式"""
    seqs = {}
    with open(fasta_file) as f:
        current_id = None
        current_seq = []
        for line in f:
            if line.startswith('>'):
                if current_id:
                    seqs[current_id] = ''.join(current_seq)
                current_id = line[1:].strip()[:10]  # PAML限制10字符
                current_seq = []
            else:
                current_seq.append(line.strip().upper())
        if current_id:
            seqs[current_id] = ''.join(current_seq)

    if len(seqs) < 3:
        return False

    # 确保所有序列长度相同
    lengths = set(len(s) for s in seqs.values())
    if len(lengths) > 1:
        max_len = max(lengths)
        for k in seqs:
            seqs[k] = seqs[k].ljust(max_len, '-')

    seq_len = len(list(seqs.values())[0])

    with open(phylip_file, 'w') as f:
        f.write(f"  {len(seqs)}  {seq_len}\n")
        for name, seq in seqs.items():
            f.write(f"{name:10s}{seq}\n")

    return True

# 转换所有比对文件
aln_files = glob.glob("alignments/OG*.aln.fa")
converted = 0
for aln in aln_files:
    og = os.path.basename(aln).replace(".aln.fa", "")
    phy_file = f"paml_input/{og}.phy"
    if fasta_to_phylip(aln, phy_file):
        converted += 1

print(f"  已转换 {converted} 个比对文件为PHYLIP格式")
PYEOF

# Step 5: 创建物种树文件 (T01和T02标记为前景枝)
echo ""
echo "Step 5: 创建物种树..."

cat > "$WORK_DIR/paml_input/tree_T01_foreground.nwk" << 'TREE'
((T01 #1, T02), (C02, (C03, C01)));
TREE

cat > "$WORK_DIR/paml_input/tree_T01_T02_foreground.nwk" << 'TREE'
((T01 #1, T02 #1), (C02, (C03, C01)));
TREE

# Step 6: 创建codeml控制文件模板
echo ""
echo "Step 6: 创建codeml控制文件模板..."

cat > "$WORK_DIR/paml_input/codeml_branch_site.ctl" << 'CTL'
      seqfile = SEQFILE
     treefile = TREEFILE
      outfile = OUTFILE

        noisy = 0
      verbose = 0
      runmode = 0

      seqtype = 1
    CodonFreq = 2
        clock = 0
       atefln = 0

        model = 2
      NSsites = 2

        icode = 0
    fix_kappa = 0
        kappa = 2
    fix_omega = 0
        omega = 1

       getSE = 0
 RateAncestor = 0
   Small_Diff = .5e-6
    cleandata = 1
CTL

# Step 7: 运行codeml (示例 - 前100个基因)
echo ""
echo "Step 7: 运行codeml分析 (前100个基因)..."

mkdir -p "$WORK_DIR/paml_output"
cd "$WORK_DIR/paml_output"

count=0
for phy in ../paml_input/OG*.phy; do
    og=$(basename "$phy" .phy)

    if [ $count -ge 100 ]; then
        break
    fi

    if [ ! -f "${og}_result.txt" ]; then
        # 创建工作目录
        mkdir -p "$og"
        cd "$og"

        # 复制文件
        cp "$phy" seq.phy
        cp ../paml_input/tree_T01_T02_foreground.nwk tree.nwk

        # 创建控制文件
        cat > codeml.ctl << EOF
      seqfile = seq.phy
     treefile = tree.nwk
      outfile = result.txt

        noisy = 0
      verbose = 0
      runmode = 0

      seqtype = 1
    CodonFreq = 2
        model = 2
      NSsites = 2

        icode = 0
    fix_kappa = 0
        kappa = 2
    fix_omega = 0
        omega = 1

       getSE = 0
 RateAncestor = 0
    cleandata = 1
EOF

        # 运行codeml
        timeout 60 codeml codeml.ctl > /dev/null 2>&1 || true

        if [ -f "result.txt" ]; then
            cp result.txt "../${og}_result.txt"
        fi

        cd ..
        rm -rf "$og"
    fi

    count=$((count + 1))
    if [ $((count % 20)) -eq 0 ]; then
        echo "  已分析 $count 个基因"
    fi
done

echo "  codeml分析完成: $count 个基因"

# Step 8: 解析结果
echo ""
echo "Step 8: 解析正选择结果..."

cd "$WORK_DIR"
python3 << 'PYEOF'
import os
import re
import glob

results = []
for result_file in glob.glob("paml_output/*_result.txt"):
    og = os.path.basename(result_file).replace("_result.txt", "")

    try:
        with open(result_file) as f:
            content = f.read()

        # 提取lnL值
        lnl_match = re.search(r'lnL.*?:\s+([-\d.]+)', content)
        lnl = float(lnl_match.group(1)) if lnl_match else None

        # 提取omega值
        omega_match = re.search(r'omega.*?=\s+([\d.]+)', content)
        omega = float(omega_match.group(1)) if omega_match else None

        # 检查正选择位点
        beb_section = re.search(r'Bayes Empirical Bayes.*?(\d+\s+\w+.*?\*)', content, re.DOTALL)
        positive_sites = 0
        if beb_section:
            positive_sites = content.count('*')

        results.append({
            'OG': og,
            'lnL': lnl,
            'omega': omega,
            'positive_sites': positive_sites
        })
    except:
        pass

# 输出结果
print(f"  共解析 {len(results)} 个结果")

# 保存结果
with open("positive_selection_results.tsv", "w") as f:
    f.write("Orthogroup\tlnL\tomega\tpositive_sites\n")
    for r in results:
        f.write(f"{r['OG']}\t{r['lnL']}\t{r['omega']}\t{r['positive_sites']}\n")

# 统计正选择基因
positive = [r for r in results if r['omega'] and r['omega'] > 1]
print(f"  omega > 1 的基因: {len(positive)} 个")

if len(results) > 0:
    with_sites = [r for r in results if r['positive_sites'] > 0]
    print(f"  有正选择位点的基因: {len(with_sites)} 个")
PYEOF

echo ""
echo "=========================================="
echo "正选择分析完成"
echo "结束时间: $(date)"
echo "结果目录: $WORK_DIR"
echo "=========================================="
