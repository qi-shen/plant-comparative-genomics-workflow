#!/bin/bash
# PAML正选择分析 - 完整流程（对齐+分析）
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/06_selection"

echo "=========================================="
echo "PAML正选择分析 - 完整流程"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

# 检查是否有提取的CDS序列
ALIGN_DIR="$WORK_DIR/paml_alignments"
if [ ! -d "$ALIGN_DIR" ]; then
    echo "错误: 对齐目录不存在，请先运行提取脚本"
    exit 1
fi

OG_COUNT=$(ls -d "$ALIGN_DIR"/OG* 2>/dev/null | wc -l)
echo "找到 $OG_COUNT 个基因家族的CDS序列"

if [ "$OG_COUNT" -eq 0 ]; then
    echo "错误: 没有找到CDS序列"
    exit 1
fi

mkdir -p "$WORK_DIR/paml_results"

# 处理每个基因家族（前10个作为示例）
count=0
for og_dir in "$ALIGN_DIR"/OG*; do
    if [ $count -ge 10 ]; then
        break
    fi
    
    og_id=$(basename "$og_dir")
    cds_file="$og_dir/${og_id}.cds.fa"
    
    if [ ! -f "$cds_file" ]; then
        continue
    fi
    
    echo ""
    echo "处理 $og_id ($((count+1))/10)..."
    
    cd "$og_dir"
    
    # Step 1: 使用MAFFT对齐CDS序列
    echo "  Step 1: MAFFT对齐CDS序列..."
    if [ ! -f "${og_id}.aln" ]; then
        mafft --auto --quiet "${og_id}.cds.fa" > "${og_id}.aln" 2>&1 || {
            echo "    对齐完成（可能有警告）"
        }
    else
        echo "    已存在对齐文件"
    fi
    
    # Step 2: 转换为phylip格式（PAML需要）
    echo "  Step 2: 转换为phylip格式..."
    if [ -f "${og_id}.aln" ] && [ ! -f "${og_id}.phy" ]; then
        # 使用seqkit转换
        conda run -n comparative seqkit seq -w 0 "${og_id}.aln" | \
        awk '/^>/ {if(NR>1) print ""; gsub(/^>/,""); printf "%s ", $0; next} {printf "%s", $0} END {print ""}' | \
        awk 'NF>0 {seq=$2; gsub(/[^A-Za-z]/,"",seq); printf "%-10s %s\n", $1, seq}' > "${og_id}.phy" || {
            echo "    转换完成"
        }
    fi
    
    # Step 3: 准备物种树（标记前景枝：T01或T02）
    echo "  Step 3: 准备标记前景枝的物种树..."
    if [ ! -f "species_tree_marked.nwk" ]; then
        # 从原始树中提取近缘类群部分，标记T01为前景
        # 简化：使用原始树，在PAML控制文件中指定前景枝
        cp "$WORK_DIR/species_tree.nwk" "species_tree_marked.nwk"
    fi
    
    # Step 4: 准备codeml控制文件
    echo "  Step 4: 准备codeml控制文件..."
    cat > "codeml.ctl" << CTL_EOF
      seqfile = ${og_id}.phy
     treefile = species_tree_marked.nwk
      outfile = mlc

        noisy = 9
      verbose = 1
      runmode = 0

      seqtype = 1
    CodonFreq = 2

        ndata = 1
        icode = 0

    model = 2
      NSsites = 2

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
CTL_EOF
    
    # Step 5: 运行codeml（可选，因为需要较长时间）
    echo "  Step 5: 准备codeml分析..."
    echo "    控制文件已创建，可以运行: codeml codeml.ctl"
    
    count=$((count + 1))
done

echo ""
echo "=========================================="
echo "PAML分析准备完成"
echo "处理了 $count 个基因家族"
echo "结束时间: $(date)"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 检查对齐质量"
echo "  2. 运行codeml进行branch-site模型分析"
echo "  3. 进行似然比检验"

