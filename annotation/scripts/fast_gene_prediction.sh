#!/bin/bash

# 快速基因预测方案
# 使用转录组证据 + GeMoMa + GeneMark-ES（并行）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/fast_prediction_$(date +%Y%m%d_%H%M%S).log"
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

# 合并StringTie GTF文件
merge_stringtie_gtf() {
    local species=$1
    local transcriptome_dir="${ANNOTATION_DIR}/${species}/transcriptome"
    local merged_gtf="${transcriptome_dir}/${species}_merged.gtf"
    
    log_step "合并StringTie GTF文件: $species"
    
    if [ -f "$merged_gtf" ]; then
        log_info "合并GTF已存在，跳过"
        return 0
    fi
    
    # 查找所有GTF文件
    local gtf_files=($(ls ${transcriptome_dir}/*.gtf 2>/dev/null | grep -v merged))
    
    if [ ${#gtf_files[@]} -eq 0 ]; then
        log_error "未找到GTF文件"
        return 1
    fi
    
    log_info "找到 ${#gtf_files[@]} 个GTF文件"
    
    # 使用StringTie merge
    if command -v stringtie &> /dev/null; then
        # 创建GTF列表文件
        local gtf_list="${transcriptome_dir}/gtf_list.txt"
        printf "%s\n" "${gtf_files[@]}" > "$gtf_list"
        
        log_info "使用StringTie合并..."
        stringtie --merge \
                  -p "$THREADS" \
                  -G "${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa" \
                  -o "$merged_gtf" \
                  "$gtf_list" 2>&1 | tee -a "$LOG_FILE"
        
        if [ $? -eq 0 ] && [ -f "$merged_gtf" ]; then
            log_info "✓ StringTie合并完成"
        else
            log_warn "StringTie合并失败，尝试简单合并"
            cat "${gtf_files[@]}" > "$merged_gtf"
        fi
    else
        log_warn "StringTie未安装，使用简单合并"
        cat "${gtf_files[@]}" > "$merged_gtf"
    fi
    
    log_info "合并GTF文件: $merged_gtf"
    log_info "文件大小: $(du -h $merged_gtf | cut -f1)"
}

# 转换GTF为GFF3（用于EVM）
convert_gtf_to_gff3() {
    local species=$1
    local gtf_file="${ANNOTATION_DIR}/${species}/transcriptome/${species}_merged.gtf"
    local gff3_file="${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3"
    
    log_step "转换GTF为GFF3: $species"
    
    if [ ! -f "$gtf_file" ]; then
        log_error "GTF文件不存在: $gtf_file"
        return 1
    fi
    
    # 使用gffread转换
    if command -v gffread &> /dev/null; then
        gffread -E "$gtf_file" -o "$gff3_file" 2>&1 | tee -a "$LOG_FILE"
        log_info "✓ GTF转GFF3完成: $gff3_file"
    else
        log_warn "gffread未安装，跳过转换"
        return 1
    fi
}

# 运行GeneMark-ES（快速版本）
run_genemark_fast() {
    local species=$1
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    local work_dir="${ANNOTATION_DIR}/${species}/structure"
    
    log_step "运行GeneMark-ES: $species"
    
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        return 1
    fi
    
    if [ -f "${work_dir}/genemark.gtf" ]; then
        log_info "GeneMark-ES输出已存在，跳过"
        return 0
    fi
    
    if ! command -v gmes_petap.pl &> /dev/null; then
        log_warn "GeneMark-ES未安装，跳过"
        return 1
    fi
    
    cd "$work_dir"
    log_info "开始时间: $(date)"
    
    # 后台运行
    nohup gmes_petap.pl --sequence "$masked_genome" \
                        --ES \
                        --cores "$THREADS" \
                        --min_contig 5000 > genemark.log 2>&1 &
    
    local pid=$!
    log_info "GeneMark-ES已在后台启动，PID: $pid"
    log_info "预计时间: 3-7天"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "快速基因预测方案"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    log_info "方案: 转录组证据 + GeneMark-ES + GeMoMa（并行）"
    log_info "预计总时间: 3-5天（比Augustus快5-10倍）"
    
    cd "$PROJECT_DIR"
    
    for species in T01 T02; do
        log_info ""
        log_info "========== 处理物种: $species =========="
        
        # 1. 合并StringTie GTF
        merge_stringtie_gtf "$species"
        
        # 2. 转换GTF为GFF3
        convert_gtf_to_gff3 "$species"
        
        # 3. 启动GeneMark-ES（后台）
        run_genemark_fast "$species"
        
        log_info "✓ $species 快速预测已启动"
    done
    
    log_info ""
    log_info "=========================================="
    log_info "快速预测任务已启动"
    log_info "=========================================="
    log_info ""
    log_info "【下一步】"
    log_info "1. 等待GeneMark-ES完成（3-7天）"
    log_info "2. 运行GeMoMa同源预测（1-3天）"
    log_info "3. 使用EVM整合所有证据（1-2天）"
    log_info ""
    log_info "【监控命令】"
    log_info "  ps aux | grep genemark"
    log_info "  ls -lh annotation/*/structure/genemark.gtf"
    log_info ""
}

main "$@"

