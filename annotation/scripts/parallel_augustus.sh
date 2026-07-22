#!/bin/bash

# 分段并行运行Augustus的脚本（可选加速方案）
# 注意：此脚本用于处理剩余序列，需要等待当前Augustus完成Chr07

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/parallel_augustus_$(date +%Y%m%d).log"
THREADS=8  # 并行进程数

mkdir -p "$ANNOTATION_DIR" "${PROJECT_DIR}/logs"

# 激活conda base环境
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate base
    export PATH="$HOME/miniconda3/bin:$PATH"
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

# 提取单个序列并运行Augustus
process_sequence() {
    local species=$1
    local seq_name=$2
    local genome_file=$3
    local output_dir=$4
    
    log_info "处理序列: $seq_name"
    
    # 提取序列
    local seq_file="${output_dir}/${seq_name}.fa"
    seqkit grep -n "^${seq_name}" "$genome_file" > "$seq_file" 2>/dev/null || {
        log_error "提取序列失败: $seq_name"
        return 1
    }
    
    # 运行Augustus
    local output_gff="${output_dir}/${seq_name}_augustus.gff3"
    log_info "运行Augustus: $seq_name"
    
    augustus --species=arabidopsis \
             --gff3=on \
             "$seq_file" > "$output_gff" 2> "${output_dir}/${seq_name}.err" &
    
    local pid=$!
    log_info "进程PID: $pid (序列: $seq_name)"
    echo "$pid" >> "${output_dir}/pids.txt"
}

# 主函数
main() {
    local species=${1:-T01}
    
    log_info "=========================================="
    log_info "分段并行Augustus预测: $species"
    log_info "时间: $(date)"
    log_info "并行进程数: $THREADS"
    log_info "=========================================="
    
    log_warn "⚠️  注意: 此脚本用于处理剩余序列"
    log_warn "请确保当前Augustus已完成Chr07"
    log_warn "建议先检查当前Augustus状态"
    
    read -p "是否继续? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        log_info "已取消"
        exit 0
    fi
    
    # 检查掩蔽基因组
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        exit 1
    fi
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/parallel"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 剩余序列列表（Chr08-Chr12，以及Chr07的剩余部分）
    local remaining_seqs=("Chr08" "Chr09" "Chr10" "Chr11" "Chr12")
    
    log_step "开始并行处理剩余序列..."
    
    # 启动并行进程
    local pids=()
    for seq in "${remaining_seqs[@]}"; do
        # 检查是否已有输出
        if [ -f "${work_dir}/${seq}_augustus.gff3" ]; then
            log_warn "序列 $seq 已有输出，跳过"
            continue
        fi
        
        # 控制并行数
        while [ $(jobs -r | wc -l) -ge $THREADS ]; do
            sleep 5
        done
        
        process_sequence "$species" "$seq" "$masked_genome" "$work_dir" &
        pids+=($!)
    done
    
    log_info "等待所有进程完成..."
    for pid in "${pids[@]}"; do
        wait "$pid"
        log_info "进程 $pid 完成"
    done
    
    log_step "合并结果..."
    local merged_gff="${ANNOTATION_DIR}/${species}/structure/${species}_augustus_parallel.gff3"
    cat "${work_dir}"/*_augustus.gff3 > "$merged_gff" 2>/dev/null || {
        log_error "合并失败"
        return 1
    }
    
    log_info "✓ 并行处理完成"
    log_info "输出文件: $merged_gff"
    log_info "需要与原始Augustus输出合并"
}

main "$@"

