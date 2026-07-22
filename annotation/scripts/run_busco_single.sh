#!/bin/bash

# 运行单个样本的BUSCO评估

set -e

if [ $# -lt 1 ]; then
    echo "用法: $0 <species> [threads]"
    echo "示例: $0 T01 32"
    exit 1
fi

SPECIES=$1
THREADS=${2:-32}

PROJECT_DIR="${PROJECT_ROOT}"
BUSCO_DIR="${PROJECT_DIR}/annotation/evaluation/busco"
LOG_FILE="${PROJECT_DIR}/logs/busco_${SPECIES}_$(date +%Y%m%d_%H%M%S).log"
LINEAGE="embryophyta_odb10"
LINEAGE_PATH="${PROJECT_DIR}/busco_downloads/lineages/${LINEAGE}"

mkdir -p "$BUSCO_DIR" "${PROJECT_DIR}/logs"

# 定义蛋白质文件
declare -A species_peps
species_peps["T01"]="${PROJECT_DIR}/annotation/T01/structure/T01_genes.pep.fa"
species_peps["T02"]="${PROJECT_DIR}/annotation/T02/structure/T02_genes.pep.fa"

pep_file="${species_peps[$SPECIES]}"
output_dir="${BUSCO_DIR}/${SPECIES}"

if [ ! -f "$pep_file" ]; then
    echo "错误: 蛋白质文件不存在: $pep_file"
    exit 1
fi

if [ ! -d "$LINEAGE_PATH" ]; then
    echo "错误: BUSCO数据库不存在: $LINEAGE_PATH"
    exit 1
fi

echo "=========================================="
echo "启动 ${SPECIES} 样本的BUSCO评估"
echo "时间: $(date)"
echo "线程数: $THREADS"
echo "=========================================="
echo ""

mkdir -p "$output_dir"
cd "$output_dir"

abs_pep_file=$(readlink -f "$pep_file")

echo "蛋白质文件: $abs_pep_file"
echo "输出目录: $output_dir"
echo "开始运行..."
echo ""

# 运行BUSCO评估（后台运行）
nohup conda run -n busco busco \
    -i "$abs_pep_file" \
    -l "$LINEAGE_PATH" \
    -o "${SPECIES}" \
    -m proteins \
    -c "$THREADS" \
    --offline \
    > "$LOG_FILE" 2>&1 &

BUSCO_PID=$!
echo "BUSCO进程已启动 (PID: $BUSCO_PID)"
echo "日志文件: $LOG_FILE"
echo ""
echo "使用以下命令监控进度:"
echo "  tail -f $LOG_FILE"
echo "  ps aux | grep $BUSCO_PID"
echo ""
echo "或使用进度检查脚本:"
echo "  bash scripts/check_busco_progress.sh"

