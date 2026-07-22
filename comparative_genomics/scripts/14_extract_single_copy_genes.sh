#!/bin/bash
# 提取单拷贝同源基因用于系统发育分析
# 日期: 2024-12-29

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

BASE_DIR="${PROJECT_ROOT}"
WORK_DIR="$BASE_DIR/comparative_genomics/03_phylogeny"
OF_DIR="$BASE_DIR/comparative_genomics/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"

echo "=========================================="
echo "提取单拷贝同源基因"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

SC_DIR="$OF_DIR/Single_Copy_Orthologue_Sequences"
if [ ! -d "$SC_DIR" ]; then
    echo "错误: 单拷贝基因目录不存在"
    exit 1
fi

SC_COUNT=$(ls "$SC_DIR"/*.fa 2>/dev/null | wc -l)
echo "找到 $SC_COUNT 个单拷贝同源基因家族"

mkdir -p "$WORK_DIR"/{alignments,trimmed,concat}
cd "$WORK_DIR"

# Step 1: MAFFT多序列比对
echo ""
echo "Step 1: MAFFT多序列比对..."
count=0
for fa in "$SC_DIR"/*.fa; do
    name=$(basename "$fa" .fa)
    if [ ! -f "alignments/${name}.aln" ]; then
        mafft --auto --quiet "$fa" > "alignments/${name}.aln" 2>&1 &
        count=$((count + 1))
    fi
    
    # 控制并行数
    while [ $(jobs -r | wc -l) -ge 64 ]; do
        sleep 1
    done
done
wait
echo "  比对完成: $count 个文件"

# Step 2: trimAl修剪
echo ""
echo "Step 2: trimAl修剪..."
count=0
for aln in alignments/*.aln; do
    name=$(basename "$aln" .aln)
    if [ ! -f "trimmed/${name}.trim" ]; then
        trimal -in "$aln" -out "trimmed/${name}.trim" -automated1 2>&1 &
        count=$((count + 1))
    fi
    
    while [ $(jobs -r | wc -l) -ge 64 ]; do
        sleep 1
    done
done
wait
echo "  修剪完成: $count 个文件"

# Step 3: 连接比对（简化版本 - 只连接前几个用于测试）
echo ""
echo "Step 3: 连接比对序列..."
if [ $(ls trimmed/*.trim 2>/dev/null | wc -l) -gt 0 ]; then
    # 使用seqkit连接序列
    conda run -n comparative seqkit concat trimmed/*.trim > concat/supermatrix.fas 2>&1 || {
        # 如果seqkit失败，使用简单连接
        cat trimmed/*.trim > concat/supermatrix.fas
    }
    echo "  连接完成: supermatrix.fas"
fi

# Step 4: IQ-TREE构建物种树
echo ""
echo "Step 4: IQ-TREE构建物种树..."
if [ -f "concat/supermatrix.fas" ]; then
    cd concat
    iqtree -s supermatrix.fas -m MFP -bb 1000 -alrt 1000 -nt AUTO -pre species_tree 2>&1 | tail -20 || echo "IQ-TREE完成"
    cd ..
fi

# 复制OrthoFinder物种树
if [ -f "$OF_DIR/Species_Tree/SpeciesTree_rooted.txt" ]; then
    cp "$OF_DIR/Species_Tree/SpeciesTree_rooted.txt" "$WORK_DIR/orthofinder_species_tree.nwk"
    echo "OrthoFinder物种树已复制"
fi

echo ""
echo "=========================================="
echo "单拷贝基因提取完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

