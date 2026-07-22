#!/bin/bash

# 运行GeneMark-ES基因预测

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/genemark_$(date +%Y%m%d_%H%M%S).log"
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

# 处理单个物种
process_species() {
    local species=$1
    
    log_step "========== GeneMark-ES预测: $species =========="
    
    # 检查掩蔽基因组
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        return 1
    fi
    
    log_info "使用掩蔽基因组: $masked_genome"
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 检查是否已有输出
    if [ -f "genemark.gtf" ]; then
        log_warn "GeneMark-ES输出已存在，跳过"
        return 0
    fi
    
    # 检查工具
    if ! command -v gmes_petap.pl &> /dev/null; then
        log_error "GeneMark-ES未安装"
        return 1
    fi
    
    # 运行GeneMark-ES
    log_step "开始GeneMark-ES预测..."
    log_info "线程数: $THREADS"
    log_info "开始时间: $(date)"
    log_info "这将需要较长时间"
    
    gmes_petap.pl --sequence "$masked_genome" \
                  --ES \
                  --cores "$THREADS" \
                  --min_contig 5000 > genemark.log 2>&1
    
    if [ $? -eq 0 ] && [ -f "genemark.gtf" ]; then
        log_info "✓ GeneMark-ES预测完成"
        log_info "输出文件: genemark.gtf"
        log_info "文件大小: $(du -h genemark.gtf | cut -f1)"
        log_info "完成时间: $(date)"
        
        # 复制输出文件
        cp genemark.gtf "${species}_genemark.gtf"
    else
        log_error "GeneMark-ES预测失败"
        if [ -f "genemark.log" ]; then
            log_error "日志最后20行:"
            tail -20 genemark.log | tee -a "$LOG_FILE"
        fi
        return 1
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始GeneMark-ES基因预测"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v gmes_petap.pl &> /dev/null; then
        log_error "GeneMark-ES未安装"
        log_info "安装命令: conda install -c bioconda genemark-es"
        exit 1
    fi
    
    # 处理T01和T02
    for species in T01 T02; do
        process_species "$species"
        echo ""
    done
    
    log_info ""
    log_info "=========================================="
    log_info "GeneMark-ES预测完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

