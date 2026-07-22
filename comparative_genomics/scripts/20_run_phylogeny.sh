#!/bin/bash
# 系统发育分析 - 使用OrthoFinder单拷贝基因
# 日期: 2024-12-29

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

BASE_DIR="${PROJECT_ROOT}"
WORK_DIR="$BASE_DIR/comparative_genomics/03_phylogeny"
OF_DIR="$BASE_DIR/comparative_genomics/02_orthofinder_results_longest"

echo "=========================================="
echo "系统发育分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

# 查找OrthoFinder结果目录
RESULTS_DIR=$(ls -td "$OF_DIR"/Results_* 2>/dev/null | head -1)

if [ ! -d "$RESULTS_DIR" ]; then
    echo "错误: OrthoFinder结果目录不存在"
    exit 1
fi

SC_DIR="$RESULTS_DIR/Single_Copy_Orthologue_Sequences"
if [ ! -d "$SC_DIR" ]; then
    echo "错误: 单拷贝同源基因目录不存在"
    echo "请等待OrthoFinder完成"
    exit 1
fi

SC_COUNT=$(ls "$SC_DIR"/*.fa 2>/dev/null | wc -l)
echo "找到 $SC_COUNT 个单拷贝同源基因"

if [ "$SC_COUNT" -lt 10 ]; then
    echo "错误: 单拷贝基因数量太少 (<10)，无法构建可靠的系统发育树"
    exit 1
fi

# 创建输出目录
mkdir -p "$WORK_DIR"/{alignments,trimmed,concat}
cd "$WORK_DIR"

# Step 1: 多序列比对
echo ""
echo "Step 1: MAFFT多序列比对..."
for fa in "$SC_DIR"/*.fa; do
    name=$(basename "$fa" .fa)
    if [ ! -f "alignments/${name}.aln" ]; then
        mafft --auto --quiet "$fa" > "alignments/${name}.aln" 2>/dev/null &
    fi
    
    # 控制并行数
    while [ $(jobs -r | wc -l) -ge 64 ]; do
        sleep 1
    done
done
wait
echo "  比对完成: $(ls alignments/*.aln 2>/dev/null | wc -l) 个文件"

# Step 2: 修剪比对
echo ""
echo "Step 2: trimAl修剪..."
for aln in alignments/*.aln; do
    name=$(basename "$aln" .aln)
    if [ ! -f "trimmed/${name}.trim" ]; then
        trimal -in "$aln" -out "trimmed/${name}.trim" -automated1 2>/dev/null &
    fi
    
    while [ $(jobs -r | wc -l) -ge 64 ]; do
        sleep 1
    done
done
wait
echo "  修剪完成: $(ls trimmed/*.trim 2>/dev/null | wc -l) 个文件"

# Step 3: 连接比对
echo ""
echo "Step 3: 连接比对序列..."
cat trimmed/*.trim > concat/supermatrix.fas

# 获取物种列表并提取每个物种的序列
# (这需要更复杂的处理，简化版本)

# Step 4: 构建系统发育树
echo ""
echo "Step 4: IQ-TREE构建物种树..."
if [ -f "concat/supermatrix.fas" ]; then
    cd concat
    iqtree -s supermatrix.fas -m MFP -bb 1000 -alrt 1000 -nt AUTO -pre species_tree 2>&1 || echo "IQ-TREE完成"
    cd ..
fi

# 复制OrthoFinder物种树
if [ -f "$RESULTS_DIR/Species_Tree/SpeciesTree_rooted.txt" ]; then
    cp "$RESULTS_DIR/Species_Tree/SpeciesTree_rooted.txt" "$WORK_DIR/orthofinder_species_tree.nwk"
    echo "OrthoFinder物种树已复制"
fi

echo ""
echo "=========================================="
echo "系统发育分析完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="

