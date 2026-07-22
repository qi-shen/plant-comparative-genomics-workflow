#!/bin/bash

# 从GFF3和基因组文件提取CDS和蛋白质序列

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/extract_protein_sequences_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${PROJECT_DIR}/logs"

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

# 提取单个物种的序列
extract_sequences() {
    local species=$1
    
    log_step "========== 提取序列: $species =========="
    
    local gff_file="${ANNOTATION_DIR}/${species}/structure/${species}_final.gff3"
    local genome_file="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    local output_dir="${ANNOTATION_DIR}/${species}/functional"
    
    mkdir -p "$output_dir"
    cd "$output_dir"
    
    # 检查输入文件
    if [ ! -f "$gff_file" ]; then
        log_error "GFF文件不存在: $gff_file"
        return 1
    fi
    
    if [ ! -f "$genome_file" ]; then
        log_error "基因组文件不存在: $genome_file"
        return 1
    fi
    
    log_info "GFF文件: $gff_file"
    log_info "基因组文件: $genome_file"
    log_info "输出目录: $output_dir"
    
    # 检查gffread
    if ! command -v gffread &> /dev/null; then
        if [ -f "/home/shenq/Biosofts/gffread/gffread" ]; then
            GFFREAD="/home/shenq/Biosofts/gffread/gffread"
        else
            log_error "gffread未找到"
            return 1
        fi
    else
        GFFREAD="gffread"
    fi
    
    log_info "使用gffread: $GFFREAD"
    
    # 提取CDS序列
    local cds_file="${output_dir}/${species}.cds.fa"
    if [ -f "$cds_file" ] && [ -s "$cds_file" ]; then
        log_warn "CDS文件已存在，跳过: $cds_file"
    else
        log_info "提取CDS序列..."
        "$GFFREAD" -x "$cds_file" -g "$genome_file" "$gff_file" >> "$LOG_FILE" 2>&1
        
        if [ -f "$cds_file" ] && [ -s "$cds_file" ]; then
            local cds_count=$(grep -c "^>" "$cds_file")
            local cds_size=$(du -h "$cds_file" | cut -f1)
            log_info "✅ CDS提取完成: $cds_file ($cds_count 条序列, $cds_size)"
        else
            log_error "CDS提取失败"
            return 1
        fi
    fi
    
    # 提取蛋白质序列
    local pep_file="${output_dir}/${species}.pep.fa"
    if [ -f "$pep_file" ] && [ -s "$pep_file" ]; then
        log_warn "蛋白质文件已存在，跳过: $pep_file"
    else
        log_info "提取蛋白质序列..."
        "$GFFREAD" -y "$pep_file" -g "$genome_file" "$gff_file" >> "$LOG_FILE" 2>&1
        
        if [ -f "$pep_file" ] && [ -s "$pep_file" ]; then
            local pep_count=$(grep -c "^>" "$pep_file")
            local pep_size=$(du -h "$pep_file" | cut -f1)
            log_info "✅ 蛋白质提取完成: $pep_file ($pep_count 条序列, $pep_size)"
        else
            log_error "蛋白质提取失败"
            return 1
        fi
    fi
    
    log_info "✅ $species 序列提取完成"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "提取蛋白质和CDS序列"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 提取BH和CK的序列
    extract_sequences "BH"
    echo ""
    extract_sequences "CK"
    
    log_info ""
    log_info "=========================================="
    log_info "序列提取完成"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    # 显示结果
    log_info ""
    log_info "【提取结果】"
    for species in BH CK; do
        local cds_file="${ANNOTATION_DIR}/${species}/functional/${species}.cds.fa"
        local pep_file="${ANNOTATION_DIR}/${species}/functional/${species}.pep.fa"
        
        if [ -f "$cds_file" ]; then
            local cds_size=$(du -h "$cds_file" | cut -f1)
            local cds_count=$(grep -c "^>" "$cds_file")
            log_info "  $species CDS: $cds_file ($cds_size, $cds_count 条序列)"
        fi
        
        if [ -f "$pep_file" ]; then
            local pep_size=$(du -h "$pep_file" | cut -f1)
            local pep_count=$(grep -c "^>" "$pep_file")
            log_info "  $species PEP: $pep_file ($pep_size, $pep_count 条序列)"
        fi
    done
}

main "$@"
