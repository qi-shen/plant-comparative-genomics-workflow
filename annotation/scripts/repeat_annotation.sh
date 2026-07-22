#!/bin/bash

# T01/CK重复序列注释脚本
# RepeatModeler和RepeatMasker

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
RESULTS_DIR="${PROJECT_DIR}/results"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/repeat_annotation_$(date +%Y%m%d).log"
THREADS=8

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

# 检查工具
check_tools() {
    if ! command -v RepeatModeler &> /dev/null; then
        log_error "RepeatModeler未安装"
        exit 1
    fi
    
    if ! command -v RepeatMasker &> /dev/null; then
        log_error "RepeatMasker未安装"
        exit 1
    fi
}

# 处理单个物种
process_species() {
    local species=$1
    local genome_file=$2
    
    log_step "========== 处理物种: $species =========="
    
    local work_dir="${ANNOTATION_DIR}/${species}/repeat"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 1. RepeatModeler - 从头预测重复序列
    log_step "RepeatModeler预测重复序列..."
    BuildDatabase -name "${species}_genome" -engine ncbi "$genome_file" 2>&1 | tee -a "$LOG_FILE"
    
    RepeatModeler -database "${species}_genome" \
                  -LTRStruct \
                  -threads "$THREADS" 2>&1 | tee -a "$LOG_FILE"
    
    # 2. RepeatMasker - 注释重复序列
    log_step "RepeatMasker注释重复序列..."
    local library_file="${work_dir}/${species}_genome-families.fa"
    
    if [ -f "$library_file" ]; then
        RepeatMasker -pa "$THREADS" \
                     -lib "$library_file" \
                     -dir "$work_dir" \
                     -gff \
                     "$genome_file" 2>&1 | tee -a "$LOG_FILE"
    else
        log_error "重复序列库文件不存在: $library_file"
        return 1
    fi
    
    # 3. 生成软掩蔽基因组
    log_step "生成软掩蔽基因组..."
    local masked_genome="${work_dir}/$(basename $genome_file).masked"
    if [ -f "$masked_genome" ]; then
        cp "$masked_genome" "${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
        log_info "✓ 软掩蔽基因组已生成"
    fi
    
    log_info "✓ 重复序列注释完成: $species"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始重复序列注释"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    check_tools
    
    # T01
    local bh_genome="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T01.Chr.final.fa"
    if [ -f "$bh_genome" ]; then
        process_species "T01" "$bh_genome"
    fi
    
    echo ""
    
    # T02
    local ck_genome="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T02.Chr.final.fa"
    if [ -f "$ck_genome" ]; then
        process_species "T02" "$ck_genome"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "重复序列注释完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

