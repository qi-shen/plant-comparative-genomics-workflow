#!/bin/bash

# 重新运行BH Augustus预测

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/bh_augustus_$(date +%Y%m%d_%H%M%S).log"
THREADS=32

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

# 主函数
main() {
    log_info "=========================================="
    log_info "重新运行BH Augustus基因预测"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v augustus &> /dev/null; then
        log_error "Augustus未安装"
        exit 1
    fi
    
    species="T01"
    
    log_step "========== Augustus预测: $species =========="
    
    # 检查掩蔽基因组
    local masked_genome1="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    local masked_genome2="${ANNOTATION_DIR}/${species}/repeat/${species}.Chr.final.fa.masked"
    
    local target_genome=""
    if [ -f "$masked_genome1" ]; then
        target_genome="$masked_genome1"
    elif [ -f "$masked_genome2" ]; then
        target_genome="$masked_genome2"
    else
        log_error "掩蔽基因组不存在"
        exit 1
    fi
    
    log_info "使用掩蔽基因组: $target_genome"
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 备份旧文件（如果存在）
    if [ -f "${species}_augustus.gff3" ]; then
        backup_file="${species}_augustus.gff3.backup_$(date +%Y%m%d_%H%M%S)"
        log_warn "备份旧输出文件: $backup_file"
        mv "${species}_augustus.gff3" "$backup_file"
    fi
    
    if [ -f "${species}_augustus.err" ]; then
        backup_err="${species}_augustus.err.backup_$(date +%Y%m%d_%H%M%S)"
        mv "${species}_augustus.err" "$backup_err"
    fi
    
    # 运行Augustus
    log_step "开始Augustus预测..."
    log_info "线程数: $THREADS (注意: Augustus是单线程程序)"
    log_info "开始时间: $(date)"
    log_info "这将需要较长时间（可能数天）"
    log_info "输出文件: ${work_dir}/${species}_augustus.gff3"
    log_info "日志文件: $LOG_FILE"
    
    # 使用通用植物参数（arabidopsis）
    augustus --species=arabidopsis \
             --gff3=on \
             --progress=true \
             "$target_genome" > "${species}_augustus.gff3" 2> "${species}_augustus.err"
    
    exit_code=$?
    
    if [ $exit_code -eq 0 ] && [ -s "${species}_augustus.gff3" ]; then
        log_info "✓ Augustus预测完成"
        log_info "输出文件: ${species}_augustus.gff3"
        log_info "文件大小: $(du -h ${species}_augustus.gff3 | cut -f1)"
        log_info "完成时间: $(date)"
        
        # 验证输出
        gene_count=$(grep -c "^[^#]" "${species}_augustus.gff3" 2>/dev/null || echo "0")
        log_info "基因注释数: $gene_count"
    else
        log_error "Augustus预测失败或输出文件为空"
        log_error "退出码: $exit_code"
        if [ -f "${species}_augustus.err" ]; then
            log_error "错误日志最后20行:"
            tail -20 "${species}_augustus.err" | tee -a "$LOG_FILE"
        fi
        exit 1
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "T01 Augustus预测完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

