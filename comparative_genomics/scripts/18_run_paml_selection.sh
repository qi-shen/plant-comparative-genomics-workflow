#!/bin/bash
# PAML正选择分析 - branch-site模型
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/06_selection"
OF_DIR="$BASE_DIR/comparative_genomics/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"

echo "=========================================="
echo "PAML正选择分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

mkdir -p "$WORK_DIR"/{paml_alignments,paml_results}

# 读取核心单拷贝基因列表
CORE_SC_FILE="$WORK_DIR/single_copy_candidates/core_single_copy.txt"
if [ ! -f "$CORE_SC_FILE" ]; then
    echo "错误: 核心单拷贝基因列表不存在"
    exit 1
fi

CORE_COUNT=$(wc -l < "$CORE_SC_FILE")
echo "核心单拷贝基因家族数: $CORE_COUNT"

# 定义CDS文件
declare -A CDS_FILES=(
    ["BH"]="$WORK_DIR/BH.cds.fa"
    ["CK"]="$WORK_DIR/CK.cds.fa"
    ["TAU"]="$WORK_DIR/TAU.cds.fa"
    ["TCH"]="$WORK_DIR/TCH.cds.fa"
    ["RSO"]="$WORK_DIR/RSO.cds.fa"
)

# 提取基因序列并比对（示例：前10个家族）
echo ""
echo "提取并比对前10个核心单拷贝基因家族（示例）..."

count=0
while read og_id && [ $count -lt 10 ]; do
    og_id=$(echo "$og_id" | tr -d '\r\n')
    if [ -z "$og_id" ]; then
        continue
    fi
    
    echo ""
    echo "处理 $og_id ($((count+1))/10)..."
    
    # 从OrthoFinder结果中提取该家族的序列
    og_seq_file="$OF_DIR/Orthogroup_Sequences/${og_id}.fa"
    
    if [ ! -f "$og_seq_file" ]; then
        echo "  跳过: 序列文件不存在"
        continue
    fi
    
    # 提取CDS序列（需要根据蛋白序列ID找到对应的CDS）
    # 这里简化处理，实际需要更复杂的ID映射
    
    count=$((count + 1))
done < "$CORE_SC_FILE"

echo ""
echo "=========================================="
echo "PAML分析准备完成"
echo "注意: 完整的PAML分析需要："
echo "  1. 提取每个家族的CDS序列"
echo "  2. 进行密码子对齐"
echo "  3. 准备标记前景枝的物种树"
echo "  4. 运行codeml (branch-site模型)"
echo "=========================================="

# 创建PAML控制文件模板
cat > "$WORK_DIR/paml_control_template.ctl" << 'CTL_TEMPLATE'
      seqfile = alignment.phy    * sequence data filename
     treefile = species_tree.nwk * tree structure file name
      outfile = mlc              * main result file name

        noisy = 9  * 0,1,2,3,9: how much rubbish on the screen
      verbose = 1  * 1: detailed output, 0: concise output
      runmode = 0  * 0: user tree;  1: semi-automatic;  2: automatic
                    * 3: StepwiseAddition; (4: random)

      seqtype = 1  * 1:codons; 2:AAs; 3:codons treated as encode
    CodonFreq = 2  * 0:1/61 each, 1:F1X4, 2:F3X4, 3:codon table

        ndata = 1
        icode = 0  * 0:universal code; 1:mammalian mt; 2-10:see below

    model = 2
    * models for codons:
    * 0:one, 1:b, 2:2 or more dN/dS ratios for branches

      NSsites = 2  * 0:one w; 1:neutral; 2:selection; 3:discrete; 4:freqs;
                    * 5:gamma; 6:2gamma; 7:beta; 8:beta&w; 9:beta&gamma;
                    * 10:beta&gamma+1; 11:beta&normal>1; 12:0&2normal>1;
                    * 13:3normal>0

        icode = 0  * 0:universal code; 1:mammalian mt; 2-10:see below
    fix_kappa = 0  * 1: kappa fixed, 0: kappa to be estimated
        kappa = 2  * initial or fixed kappa
    fix_omega = 0  * 1: omega or omega_1 fixed, 0: estimate
        omega = .4 * initial or fixed omega, for codons or codon-translated AAs

    fix_alpha = 1  * 0: estimate gamma shape parameter; 1: fix it at alpha
        alpha = 0. * initial or fixed alpha, 0 or 2.0
       Malpha = 0  * different alphas for genes
        ncatG = 10  * # of categories in dG of NSsites models

        clock = 0   * 0:no clock, 1:clock, 2:local clock
       getSE = 0    * 0: don't want them, 1: want S.E.s of estimates
 RateAncestor = 0   * (0,1,2): rates (alpha>0) or ancestral states (1 or 2)

   Small_Diff = .5e-6
*    cleandata = 1  * remove sites with ambiguity data (1:yes, 0:no)
*        fix_blength = -1  * 0: ignore, -1: random, 1: initial, 2: fixed
       method = 0   * 0: simultaneous; 1: one branch at a time

* Genetic codes: 0:universal, 1:mammalian mt., 2:yeast mt., 3:mold mt.,
* 4: invertebrate mt., 5: ciliate nuclear, 6: echinoderm mt., 
* 7: euplotid mt., 8: alternative yeast nu., 9: ascidian mt., 
* 10: blepharisma nu.
CTL_TEMPLATE

echo ""
echo "PAML控制文件模板已创建: paml_control_template.ctl"
echo "=========================================="

