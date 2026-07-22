#!/bin/bash

# 合并StringTie GTF文件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/merge_stringtie_$(date +%Y%m%d_%H%M%S).log"
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

# 合并StringTie GTF
merge_gtf() {
    local species=$1
    local transcriptome_dir="${ANNOTATION_DIR}/${species}/transcriptome"
    local merged_gtf="${transcriptome_dir}/${species}_merged.gtf"
    local gff3_file="${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3"
    
    log_step "========== 合并StringTie GTF: $species =========="
    
    if [ -f "$merged_gtf" ]; then
        log_info "合并GTF已存在，跳过合并步骤"
    else
        # 查找所有GTF文件
        local gtf_files=($(ls ${transcriptome_dir}/*.gtf 2>/dev/null | grep -v merged))
        
        if [ ${#gtf_files[@]} -eq 0 ]; then
            log_error "未找到GTF文件"
            return 1
        fi
        
        log_info "找到 ${#gtf_files[@]} 个GTF文件:"
        for gtf in "${gtf_files[@]}"; do
            log_info "  - $(basename $gtf)"
        done
        
        # 使用StringTie merge
        if command -v stringtie &> /dev/null; then
            log_info "使用StringTie合并..."
            stringtie --merge \
                      -p "$THREADS" \
                      -o "$merged_gtf" \
                      "${gtf_files[@]}" 2>&1 | tee -a "$LOG_FILE"
            
            if [ $? -eq 0 ] && [ -f "$merged_gtf" ]; then
                log_info "✓ StringTie合并完成"
                log_info "文件大小: $(du -h $merged_gtf | cut -f1)"
            else
                log_warn "StringTie合并失败，尝试简单合并"
                cat "${gtf_files[@]}" > "$merged_gtf"
                log_info "✓ 简单合并完成"
            fi
        else
            log_warn "StringTie未安装，使用简单合并"
            cat "${gtf_files[@]}" > "$merged_gtf"
            log_info "✓ 简单合并完成"
        fi
    fi
    
    # 转换GTF为GFF3
    log_step "转换GTF为GFF3: $species"
    mkdir -p "${ANNOTATION_DIR}/${species}/structure"
    
    if [ -f "$gff3_file" ]; then
        log_info "GFF3文件已存在，跳过转换"
    else
        if command -v gffread &> /dev/null; then
            log_info "使用gffread转换..."
            gffread -E "$merged_gtf" -o "$gff3_file" 2>&1 | tee -a "$LOG_FILE"
            if [ $? -eq 0 ] && [ -f "$gff3_file" ]; then
                log_info "✓ GTF转GFF3完成"
                log_info "文件: $gff3_file"
                log_info "文件大小: $(du -h $gff3_file | cut -f1)"
            else
                log_warn "gffread转换失败，直接复制GTF"
                cp "$merged_gtf" "$gff3_file"
            fi
        else
            log_warn "gffread未安装，直接复制GTF为GFF3"
            cp "$merged_gtf" "$gff3_file"
        fi
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "合并StringTie GTF文件"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v stringtie &> /dev/null && ! command -v gffread &> /dev/null; then
        log_error "StringTie或gffread未安装"
        exit 1
    fi
    
    # 处理T01和T02
    for species in T01 T02; do
        merge_gtf "$species"
        echo ""
    done
    
    log_info ""
    log_info "=========================================="
    log_info "StringTie GTF合并完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

