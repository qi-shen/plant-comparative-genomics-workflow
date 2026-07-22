#!/bin/bash

# T01/CK转录组处理脚本
# fastp质控、HISAT2比对、StringTie组装

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
RESULTS_DIR="${PROJECT_DIR}/results"
RNA_DATA_DIR="${PROJECT_DIR}/rna_rawdata"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/transcriptome_$(date +%Y%m%d).log"
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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查必要工具
check_tools() {
    local missing=0
    
    if ! command -v fastp &> /dev/null; then
        log_error "fastp未安装"
        missing=1
    fi
    
    if ! command -v hisat2 &> /dev/null; then
        log_error "hisat2未安装"
        missing=1
    fi
    
    if ! command -v stringtie &> /dev/null; then
        log_error "stringtie未安装"
        missing=1
    fi
    
    if ! command -v samtools &> /dev/null; then
        log_error "samtools未安装"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log_error "请先安装缺失的工具"
        exit 1
    fi
}

# 处理单个样本
process_sample() {
    local species=$1
    local tissue=$2
    local r1_file=$3
    local r2_file=$4
    local output_dir=$5
    
    log_step "处理样本: ${species}-${tissue}"
    
    mkdir -p "$output_dir"
    cd "$output_dir"
    
    # 1. fastp质控
    log_info "fastp质控..."
    fastp -i "$r1_file" \
          -I "$r2_file" \
          -o "${species}_${tissue}_clean_R1.fq.gz" \
          -O "${species}_${tissue}_clean_R2.fq.gz" \
          -h "${species}_${tissue}_fastp.html" \
          -j "${species}_${tissue}_fastp.json" \
          -w "$THREADS" 2>&1 | tee -a "$LOG_FILE"
    
    # 2. HISAT2比对
    log_info "HISAT2比对..."
    local index_file="${ANNOTATION_DIR}/${species}/hisat2_index/${species}_genome"
    
    hisat2 -x "$index_file" \
           -1 "${species}_${tissue}_clean_R1.fq.gz" \
           -2 "${species}_${tissue}_clean_R2.fq.gz" \
           -S "${species}_${tissue}.sam" \
           -p "$THREADS" \
           --summary-file "${species}_${tissue}_hisat2_summary.txt" 2>&1 | tee -a "$LOG_FILE"
    
    # 3. SAM转BAM并排序
    log_info "SAM转BAM并排序..."
    samtools view -bS "${species}_${tissue}.sam" | \
        samtools sort -o "${species}_${tissue}_sorted.bam" -@ "$THREADS"
    samtools index "${species}_${tissue}_sorted.bam"
    
    # 4. StringTie组装转录本
    log_info "StringTie组装转录本..."
    stringtie "${species}_${tissue}_sorted.bam" \
              -o "${species}_${tissue}.gtf" \
              -p "$THREADS" \
              -G "${ANNOTATION_DIR}/${species}/reference.gff" 2>&1 | tee -a "$LOG_FILE" || \
    stringtie "${species}_${tissue}_sorted.bam" \
              -o "${species}_${tissue}.gtf" \
              -p "$THREADS" 2>&1 | tee -a "$LOG_FILE"
    
    # 清理SAM文件
    rm -f "${species}_${tissue}.sam"
    
    log_info "✓ 完成: ${species}-${tissue}"
}

# 构建HISAT2索引
build_index() {
    local species=$1
    local genome_file=$2
    
    log_step "构建HISAT2索引: $species"
    
    local index_dir="${ANNOTATION_DIR}/${species}/hisat2_index"
    mkdir -p "$index_dir"
    
    local index_prefix="${index_dir}/${species}_genome"
    
    hisat2-build -p "$THREADS" "$genome_file" "$index_prefix" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "✓ 索引构建完成: $index_prefix"
}

# 合并所有样本的转录本
merge_transcripts() {
    local species=$1
    local transcriptome_dir="${ANNOTATION_DIR}/${species}/transcriptome"
    
    log_step "合并转录本: $species"
    
    # 收集所有GTF文件
    local gtf_list=()
    for gtf in "$transcriptome_dir"/*.gtf; do
        if [ -f "$gtf" ]; then
            gtf_list+=("$gtf")
        fi
    done
    
    if [ ${#gtf_list[@]} -eq 0 ]; then
        log_warn "未找到GTF文件，跳过合并"
        return
    fi
    
    log_info "找到 ${#gtf_list[@]} 个GTF文件"
    
    # StringTie合并
    stringtie --merge \
              -o "${ANNOTATION_DIR}/${species}/${species}_merged.gtf" \
              -p "$THREADS" \
              "${gtf_list[@]}" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "✓ 合并完成: ${species}_merged.gtf"
}

# 处理单个物种
process_species() {
    local species=$1
    local genome_file=$2
    
    log_step "========== 处理物种: $species =========="
    
    # 创建目录
    local transcriptome_dir="${ANNOTATION_DIR}/${species}/transcriptome"
    mkdir -p "$transcriptome_dir"
    
    # 构建索引
    build_index "$species" "$genome_file"
    
    # 处理每个样本
    local tissues=("L" "R" "S")
    for tissue in "${tissues[@]}"; do
        local r1_file="${RNA_DATA_DIR}/${species}-${tissue}/*_1.fq.gz"
        local r2_file="${RNA_DATA_DIR}/${species}-${tissue}/*_2.fq.gz"
        
        # 查找实际文件
        local r1=$(ls $r1_file 2>/dev/null | head -1)
        local r2=$(ls $r2_file 2>/dev/null | head -1)
        
        if [ -f "$r1" ] && [ -f "$r2" ]; then
            process_sample "$species" "$tissue" "$r1" "$r2" "$transcriptome_dir"
        else
            log_warn "未找到 ${species}-${tissue} 的数据文件"
        fi
    done
    
    # 合并转录本
    merge_transcripts "$species"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始转录组处理"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    check_tools
    
    # BH基因组
    local bh_genome="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T01.Chr.final.fa"
    if [ -f "$bh_genome" ]; then
        process_species "T01" "$bh_genome"
    else
        log_error "BH基因组文件不存在: $bh_genome"
    fi
    
    echo ""
    
    # CK基因组
    local ck_genome="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T02.Chr.final.fa"
    if [ -f "$ck_genome" ]; then
        process_species "T02" "$ck_genome"
    else
        log_error "CK基因组文件不存在: $ck_genome"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "转录组处理完成"
    log_info "时间: $(date)"
    log_info "结果保存在: $ANNOTATION_DIR"
    log_info "=========================================="
}

main "$@"

