#!/bin/bash

# InterProScan结构域预测脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_DIR="${PROJECT_DIR}/logs/interproscan"
THREADS=32

mkdir -p "$LOG_DIR"

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

# 检查InterProScan
check_interproscan() {
    if command -v interproscan.sh &> /dev/null; then
        INTERPROSCAN="interproscan.sh"
        log_info "使用InterProScan: $INTERPROSCAN"
        return 0
    elif [ -f "$HOME/interproscan/interproscan.sh" ]; then
        INTERPROSCAN="$HOME/interproscan/interproscan.sh"
        log_info "使用InterProScan: $INTERPROSCAN"
        return 0
    else
        log_error "InterProScan未找到"
        log_warn "请安装InterProScan:"
        echo "  方法1: conda install -c bioconda interproscan"
        echo "  方法2: 从官网下载: https://www.ebi.ac.uk/interpro/download/InterProScan/"
        return 1
    fi
}

# 运行InterProScan
run_interproscan() {
    local species=$1
    
    log_step "========== InterProScan: $species =========="
    
    local pep_file="${ANNOTATION_DIR}/${species}/functional/${species}.pep.fa"
    local output_tsv="${ANNOTATION_DIR}/${species}/functional/${species}_interproscan.tsv"
    local output_gff="${ANNOTATION_DIR}/${species}/functional/${species}_interproscan.gff3"
    
    if [ ! -f "$pep_file" ]; then
        log_error "蛋白质序列文件不存在: $pep_file"
        return 1
    fi
    
    if [ -f "$output_tsv" ] && [ -s "$output_tsv" ]; then
        log_warn "InterProScan结果已存在，跳过: $output_tsv"
        return 0
    fi
    
    log_info "输入文件: $pep_file"
    log_info "输出TSV: $output_tsv"
    log_info "输出GFF3: $output_gff"
    log_info "线程数: $THREADS"
    
    log_info "开始InterProScan预测（这可能需要数小时）..."
    
    "$INTERPROSCAN" \
        -i "$pep_file" \
        -o "$output_tsv" \
        --goterms \
        --pathways \
        -f tsv \
        --cpu "$THREADS" \
        >> "$LOG_FILE" 2>&1
    
    # 同时生成GFF3格式
    if [ -f "$output_tsv" ] && [ -s "$output_tsv" ]; then
        log_info "生成GFF3格式..."
        "$INTERPROSCAN" \
            -i "$pep_file" \
            -o "$output_gff" \
            --goterms \
            --pathways \
            -f gff3 \
            --cpu "$THREADS" \
            >> "$LOG_FILE" 2>&1
    fi
    
    if [ -f "$output_tsv" ] && [ -s "$output_tsv" ]; then
        local line_count=$(wc -l < "$output_tsv")
        local file_size=$(du -h "$output_tsv" | cut -f1)
        log_info "✅ InterProScan完成: $output_tsv"
        log_info "   结果行数: $line_count"
        log_info "   文件大小: $file_size"
        return 0
    else
        log_error "InterProScan失败"
        return 1
    fi
}

# 主函数
main() {
    LOG_FILE="${LOG_DIR}/interproscan_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "=========================================="
    log_info "InterProScan结构域预测"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    if ! check_interproscan; then
        log_error "InterProScan未安装，跳过此步骤"
        exit 1
    fi
    
    # 处理BH和CK
    run_interproscan "BH"
    echo ""
    run_interproscan "CK"
    
    log_info ""
    log_info "=========================================="
    log_info "InterProScan预测完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

