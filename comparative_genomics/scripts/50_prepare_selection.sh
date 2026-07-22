#!/bin/bash
# 准备正选择分析数据
# 日期: 2024-12-30

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

BASE_DIR="${PROJECT_ROOT}"
WORK_DIR="$BASE_DIR/comparative_genomics/06_selection"
OF_DIR="$BASE_DIR/comparative_genomics/02_orthofinder_results/Results_Dec29/WorkingDirectory/OrthoFinder/Results_Dec29_1"

echo "=========================================="
echo "准备正选择分析数据"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

mkdir -p "$WORK_DIR"/{single_copy_genes,alignments,trimmed,paml_input}

# 查找单拷贝同源基因
SC_DIR="$OF_DIR/Single_Copy_Orthologue_Sequences"
if [ ! -d "$SC_DIR" ]; then
    echo "错误: 单拷贝基因目录不存在"
    exit 1
fi

SC_COUNT=$(ls "$SC_DIR"/*.fa 2>/dev/null | wc -l)
echo "找到 $SC_COUNT 个单拷贝同源基因家族"

# 复制单拷贝基因序列
echo ""
echo "复制单拷贝基因序列..."
cp "$SC_DIR"/*.fa "$WORK_DIR/single_copy_genes/"
echo "已复制 $SC_COUNT 个文件"

# 准备CDS序列（用于PAML分析）
echo ""
echo "准备CDS序列..."

# 定义CDS文件路径
declare -A CDS_FILES=(
    ["T01"]="$BASE_DIR/new_anno/T01.final.cds.fa"
    ["T02"]="$BASE_DIR/new_anno/T02.final.cds.fa"
    ["C02"]="$BASE_DIR/old_reults/results/C02/cds.fa"
    ["C03"]="$BASE_DIR/old_reults/results/comp/C03/cds.fa"
    ["C01"]="$BASE_DIR/old_reults/results/C01/C01.cds.fa"
)

# 创建CDS索引（用于快速提取）
for sp in T01 T02 C02 C03 C01; do
    cds_file="${CDS_FILES[$sp]}"
    if [ -f "$cds_file" ]; then
        # 添加物种前缀并创建索引
        awk -v sp="$sp" '/^>/{gsub(/^>/, ">" sp "_"); print; next} {print}' "$cds_file" > "$WORK_DIR/${sp}.cds.fa"
        echo "  $sp: $(grep -c '^>' "$WORK_DIR/${sp}.cds.fa") 条CDS序列"
    fi
done

# 复制物种树
if [ -f "$OF_DIR/Species_Tree/SpeciesTree_rooted.txt" ]; then
    cp "$OF_DIR/Species_Tree/SpeciesTree_rooted.txt" "$WORK_DIR/species_tree.nwk"
    echo ""
    echo "物种树已复制"
fi

# 创建PAML分析模板脚本
cat > "$WORK_DIR/run_paml_analysis.sh" << 'PAML_SCRIPT'
#!/bin/bash
# PAML正选择分析脚本模板
# 前景枝: T01 或 T02
# 背景枝: C02, C03, C01

# 使用codeml进行branch-site模型分析
# 需要准备：
# 1. 对齐的CDS序列（phylip格式）
# 2. 物种树（标记前景枝）
# 3. codeml控制文件

echo "PAML分析准备完成"
echo "需要为每个单拷贝基因家族准备："
echo "  1. CDS序列对齐"
echo "  2. 标记前景枝的物种树"
echo "  3. codeml控制文件"
PAML_SCRIPT

chmod +x "$WORK_DIR/run_paml_analysis.sh"

echo ""
echo "=========================================="
echo "正选择分析数据准备完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR"
echo "=========================================="
echo ""
echo "下一步："
echo "  1. 对单拷贝基因进行CDS序列对齐"
echo "  2. 准备PAML codeml控制文件"
echo "  3. 运行branch-site模型分析"

