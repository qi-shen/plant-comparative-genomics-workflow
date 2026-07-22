#!/bin/bash

# 运行RepeatMasker脚本（RepeatModeler已完成）

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
LOG_FILE="${PROJECT_DIR}/logs/repeatmasker_$(date +%Y%m%d).log"
THREADS=32  # 使用更多线程加速

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

# 处理单个物种
process_species() {
    local species=$1
    local genome_file=$2
    
    log_step "========== 处理物种: $species =========="
    
    local work_dir="${ANNOTATION_DIR}/${species}/repeat"
    local library_file="${work_dir}/${species}_genome-families.fa"
    
    if [ ! -f "$library_file" ]; then
        log_error "重复序列库文件不存在: $library_file"
        return 1
    fi
    
    log_info "使用重复序列库: $library_file"
    log_info "基因组文件: $genome_file"
    
    cd "$work_dir"
    
    # RepeatMasker - 注释重复序列
    log_step "RepeatMasker注释重复序列..."
    log_info "线程数: $THREADS"
    log_info "开始时间: $(date)"
    
    # 检查RepeatMasker参数（使用-par或-pa）
    if RepeatMasker -help 2>&1 | grep -q "\-par"; then
        PARAM="-par $THREADS"
    elif RepeatMasker -help 2>&1 | grep -q "\-pa"; then
        PARAM="-pa $THREADS"
    else
        PARAM="-pa $THREADS"  # 默认
    fi
    
    log_info "使用参数: $PARAM"
    
    # 运行RepeatMasker（使用引号处理路径）
    RepeatMasker $PARAM \
                 -lib "$library_file" \
                 -dir "$work_dir" \
                 -gff \
                 -xsmall \
                 "$genome_file" 2>&1 | tee -a "$LOG_FILE"
    
    # 检查输出文件（处理带空格的文件名）
    local genome_basename=$(basename "$genome_file")
    local masked_genome="${work_dir}/${genome_basename}.masked"
    local gff_file="${work_dir}/${genome_basename}.out.gff"
    
    if [ -f "$masked_genome" ]; then
        log_info "✓ 软掩蔽基因组已生成: $masked_genome"
        # 复制到主目录
        cp "$masked_genome" "${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa" 2>/dev/null || true
    fi
    
    if [ -f "$gff_file" ]; then
        log_info "✓ GFF注释文件已生成: $gff_file"
        # 复制到主目录
        cp "$gff_file" "${ANNOTATION_DIR}/${species}/${species}_repeat.gff" 2>/dev/null || true
    fi
    
    log_info "完成时间: $(date)"
    log_info "✓ 重复序列注释完成: $species"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始RepeatMasker重复序列注释"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v RepeatMasker &> /dev/null; then
        log_error "RepeatMasker未安装"
        exit 1
    fi
    
    # T01 - 使用不带空格的路径
    local bh_genome="${RESULTS_DIR}/genomes/T01.Chr.final.fa"
    if [ -f "$bh_genome" ] || [ -L "$bh_genome" ]; then
        process_species "T01" "$bh_genome"
    else
        log_error "BH基因组文件不存在: $bh_genome"
    fi
    
    echo ""
    
    # T02 - 使用不带空格的路径
    local ck_genome="${RESULTS_DIR}/genomes/T02.Chr.final.fa"
    if [ -f "$ck_genome" ] || [ -L "$ck_genome" ]; then
        process_species "T02" "$ck_genome"
    else
        log_error "CK基因组文件不存在: $ck_genome"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "RepeatMasker重复序列注释完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

