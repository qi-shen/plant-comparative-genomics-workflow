#!/bin/bash
# 比较基因组流程 - 初始化脚本（脱敏：不含真实物种名）
# 用途：检查环境、关键目录，生成本机 .project_env

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  比较基因组流程初始化"
echo "=========================================="
echo ""

echo "[1/5] 检查 conda..."
if command -v conda &> /dev/null; then
    echo "  ✓ conda: $(conda info --base)"
else
    echo "  ⚠ conda 未在 PATH 中"
fi
echo ""

echo "[2/5] 设置路径变量..."
export PROJECT_ROOT
export RESULTS_DIR="$PROJECT_ROOT/old_reults/results"
export SCRIPTS_DIR="$PROJECT_ROOT/old_reults/scripts"
export ANNOTATION_DIR="$PROJECT_ROOT/old_reults/annotation"
export COMPARATIVE_DIR="$PROJECT_ROOT/comparative_genomics"
export LOGS_DIR="$PROJECT_ROOT/old_reults/logs"
export TOOLS_DIR="$PROJECT_ROOT/old_reults/tools"
export RNA_DIR="$PROJECT_ROOT/old_reults/rna_rawdata"
echo "  ✓ PROJECT_ROOT=$PROJECT_ROOT"
echo ""

echo "[3/5] 检查关键目录..."
for dir in "$RESULTS_DIR" "$SCRIPTS_DIR" "$ANNOTATION_DIR" "$COMPARATIVE_DIR" "$LOGS_DIR"; do
    if [ -d "$dir" ]; then
        echo "  ✓ $dir"
    else
        echo "  ⚠ 创建 $dir"
        mkdir -p "$dir"
    fi
done
echo ""

echo "[4/5] 检查目标样本基因组（中性路径）..."
T01_CANDIDATES=(
    "$RESULTS_DIR/targets/T01/T01.Chr.final.fa"
    "$RESULTS_DIR/targets/T01/T01.Chr.final.fa.gz"
    "$RESULTS_DIR/genomes/T01.Chr.final.fa"
)
T02_CANDIDATES=(
    "$RESULTS_DIR/targets/T02/T02.Chr.final.fa"
    "$RESULTS_DIR/targets/T02/T02.Chr.final.fa.gz"
    "$RESULTS_DIR/genomes/T02.Chr.final.fa"
)

T01_GENOME_FOUND=""
for f in "${T01_CANDIDATES[@]}"; do
    if [ -f "$f" ]; then T01_GENOME_FOUND="$f"; echo "  ✓ T01: $f"; break; fi
done
[ -z "$T01_GENOME_FOUND" ] && echo "  ⚠ 未找到 T01 基因组（可稍后在 .project_env 中填写）"

T02_GENOME_FOUND=""
for f in "${T02_CANDIDATES[@]}"; do
    if [ -f "$f" ]; then T02_GENOME_FOUND="$f"; echo "  ✓ T02: $f"; break; fi
done
[ -z "$T02_GENOME_FOUND" ] && echo "  ⚠ 未找到 T02 基因组（可稍后在 .project_env 中填写）"
echo ""

echo "[5/5] 生成 .project_env..."
ENV_FILE="$PROJECT_ROOT/.project_env"
cat > "$ENV_FILE" << EOF
# 本机环境配置（勿提交公开仓库）
export PROJECT_ROOT="$PROJECT_ROOT"
export RESULTS_DIR="$RESULTS_DIR"
export SCRIPTS_DIR="$SCRIPTS_DIR"
export ANNOTATION_DIR="$ANNOTATION_DIR"
export COMPARATIVE_DIR="$COMPARATIVE_DIR"
export LOGS_DIR="$LOGS_DIR"
export TOOLS_DIR="$TOOLS_DIR"
export RNA_DIR="$RNA_DIR"
export T01_GENOME="$T01_GENOME_FOUND"
export T02_GENOME="$T02_GENOME_FOUND"

# 兼容旧脚本变量名
export WF_PROJECT_ROOT="\$PROJECT_ROOT"
export WF_RESULTS_DIR="\$RESULTS_DIR"
export WF_SCRIPTS_DIR="\$SCRIPTS_DIR"
export WF_ANNOTATION_DIR="\$ANNOTATION_DIR"
export WF_COMPARATIVE_DIR="\$COMPARATIVE_DIR"
export WF_LOGS_DIR="\$LOGS_DIR"
export WF_TOOLS_DIR="\$TOOLS_DIR"
export WF_RNA_DIR="\$RNA_DIR"
export WF_T01_GENOME="\$T01_GENOME"
export WF_T02_GENOME="\$T02_GENOME"
EOF

echo "  ✓ 已写入 $ENV_FILE"
echo "  使用: source $ENV_FILE"
echo ""
echo "提示: 将 species_list.example.csv 复制为 species_list.csv 并填写本地路径；勿把真实种名推送到公开远程。"
echo "完成。"
