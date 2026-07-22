#!/bin/bash

# 使用转录组数据更新和修正基因结构注释
# 使用StringTie和PASA（如果可用）或替代方法

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
SPECIES=${1:-"BH"}  # 默认BH，可指定CK

# 文件路径
GENOME="${PROJECT_DIR}/annotation/${SPECIES}/${SPECIES}_genome.masked.fa"
GFF3_INPUT="${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_final.gff3"
GTF_TRANSCRIPTOME="${PROJECT_DIR}/annotation/${SPECIES}/transcriptome/${SPECIES}_merged.gtf"
OUTPUT_DIR="${PROJECT_DIR}/annotation/${SPECIES}/structure_update"
LOG_FILE="${PROJECT_DIR}/logs/update_annotation_${SPECIES}_$(date +%Y%m%d_%H%M%S).log"
THREADS=32

mkdir -p "$OUTPUT_DIR" "${PROJECT_DIR}/logs"

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

# 检查输入文件
check_inputs() {
    log_step "检查输入文件..."
    
    if [ ! -f "$GENOME" ]; then
        log_error "基因组文件不存在: $GENOME"
        return 1
    fi
    
    if [ ! -f "$GTF_TRANSCRIPTOME" ]; then
        log_error "转录组GTF文件不存在: $GTF_TRANSCRIPTOME"
        return 1
    fi
    
    log_info "✓ 输入文件检查完成"
    return 0
}

# 方法1: 使用gffcompare比较和更新
update_with_gffcompare() {
    log_step "使用gffcompare比较注释和转录组..."
    
    GFFCOMPARE_OUTPUT="${OUTPUT_DIR}/gffcompare"
    mkdir -p "$GFFCOMPARE_OUTPUT"
    
    # 转换GFF3为GTF（如果需要）
    GTF_INPUT="${OUTPUT_DIR}/${SPECIES}_input.gtf"
    if [ -f "$GFF3_INPUT" ]; then
        log_info "转换GFF3为GTF格式..."
        if command -v gffread &> /dev/null; then
            gffread -E "$GFF3_INPUT" -o "$GTF_INPUT" 2>&1 | tee -a "$LOG_FILE"
        else
            log_warn "gffread未找到，跳过转换"
            return 1
        fi
    else
        log_warn "输入GFF3不存在，跳过更新"
        return 1
    fi
    
    # 运行gffcompare
    log_info "运行gffcompare..."
    gffcompare -r "$GTF_INPUT" \
               -o "${GFFCOMPARE_OUTPUT}/${SPECIES}_comparison" \
               "$GTF_TRANSCRIPTOME" \
               2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ gffcompare完成"
        log_info "  结果保存在: $GFFCOMPARE_OUTPUT"
        return 0
    else
        log_error "✗ gffcompare失败"
        return 1
    fi
}

# 方法2: 使用StringTie --merge更新
update_with_stringtie() {
    log_step "使用StringTie合并转录组和现有注释..."
    
    STRINGTIE_OUTPUT="${OUTPUT_DIR}/stringtie_updated"
    mkdir -p "$STRINGTIE_OUTPUT"
    
    # 转换GFF3为GTF
    GTF_INPUT="${OUTPUT_DIR}/${SPECIES}_input.gtf"
    if [ -f "$GFF3_INPUT" ]; then
        if command -v gffread &> /dev/null; then
            gffread -E "$GFF3_INPUT" -o "$GTF_INPUT" 2>&1 | tee -a "$LOG_FILE"
        else
            log_warn "gffread未找到，跳过"
            return 1
        fi
    else
        log_warn "输入GFF3不存在"
        return 1
    fi
    
    # 创建GTF列表文件
    GTF_LIST="${STRINGTIE_OUTPUT}/gtf_list.txt"
    echo "$GTF_INPUT" > "$GTF_LIST"
    echo "$GTF_TRANSCRIPTOME" >> "$GTF_LIST"
    
    # 使用StringTie合并
    log_info "运行StringTie合并..."
    stringtie --merge \
              -p "$THREADS" \
              -o "${STRINGTIE_OUTPUT}/${SPECIES}_merged_updated.gtf" \
              -G "$GTF_INPUT" \
              "$GTF_LIST" \
              2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ StringTie合并完成"
        log_info "  结果保存在: ${STRINGTIE_OUTPUT}/${SPECIES}_merged_updated.gtf"
        return 0
    else
        log_error "✗ StringTie合并失败"
        return 1
    fi
}

# 方法3: 使用PASA（如果可用）
update_with_pasa() {
    log_step "尝试使用PASA更新..."
    
    # 检查PASA是否可用
    PASA_CMD=""
    if command -v PASA.pl &> /dev/null; then
        PASA_CMD="PASA.pl"
    elif [ -f "$HOME/miniconda3/envs/maker/bin/PASA.pl" ]; then
        PASA_CMD="$HOME/miniconda3/envs/maker/bin/PASA.pl"
    elif [ -f "$HOME/miniconda3/envs/annotation/bin/PASA.pl" ]; then
        PASA_CMD="$HOME/miniconda3/envs/annotation/bin/PASA.pl"
    else
        log_warn "PASA未找到，跳过PASA更新"
        return 1
    fi
    
    log_info "找到PASA: $PASA_CMD"
    log_info "PASA更新需要MySQL数据库，请参考PASA文档配置"
    log_warn "PASA更新需要额外配置，建议使用其他方法"
    
    return 1
}

# 方法4: 使用TACO合并转录本
update_with_taco() {
    log_step "使用TACO合并转录本..."
    
    if ! command -v taco_run &> /dev/null; then
        log_warn "TACO未安装，跳过"
        return 1
    fi
    
    TACO_OUTPUT="${OUTPUT_DIR}/taco_updated"
    mkdir -p "$TACO_OUTPUT"
    
    # 转换GFF3为GTF
    GTF_INPUT="${OUTPUT_DIR}/${SPECIES}_input.gtf"
    if [ -f "$GFF3_INPUT" ] && command -v gffread &> /dev/null; then
        gffread -E "$GFF3_INPUT" -o "$GTF_INPUT" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 运行TACO
    log_info "运行TACO..."
    taco_run \
        -p "$THREADS" \
        -o "$TACO_OUTPUT" \
        "$GTF_INPUT" "$GTF_TRANSCRIPTOME" \
        2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ TACO完成"
        return 0
    else
        log_error "✗ TACO失败"
        return 1
    fi
}

# 提取改进的基因列表
extract_improved_genes() {
    log_step "提取改进的基因列表..."
    
    # 从gffcompare结果中提取
    if [ -f "${OUTPUT_DIR}/gffcompare/${SPECIES}_comparison.tracking" ]; then
        IMPROVED_GENES="${OUTPUT_DIR}/improved_genes.txt"
        
        # 提取有转录组支持但注释不完整的基因
        awk '$4=="=" || $4=="c" {print $2}' \
            "${OUTPUT_DIR}/gffcompare/${SPECIES}_comparison.tracking" \
            > "$IMPROVED_GENES" 2>/dev/null || true
        
        if [ -f "$IMPROVED_GENES" ]; then
            IMPROVED_COUNT=$(wc -l < "$IMPROVED_GENES")
            log_info "✓ 找到 $IMPROVED_COUNT 个可改进的基因"
            log_info "  列表保存在: $IMPROVED_GENES"
        fi
    fi
}

# 生成更新后的GFF3
generate_updated_gff3() {
    log_step "生成更新后的GFF3文件..."
    
    UPDATED_GFF3="${OUTPUT_DIR}/${SPECIES}_updated.gff3"
    
    # 优先使用StringTie合并结果
    if [ -f "${OUTPUT_DIR}/stringtie_updated/${SPECIES}_merged_updated.gtf" ]; then
        log_info "使用StringTie合并结果..."
        if command -v gffread &> /dev/null; then
            gffread -E "${OUTPUT_DIR}/stringtie_updated/${SPECIES}_merged_updated.gtf" \
                    -o "$UPDATED_GFF3" \
                    2>&1 | tee -a "$LOG_FILE"
            log_info "✓ 更新的GFF3已保存: $UPDATED_GFF3"
            return 0
        fi
    fi
    
    # 如果没有其他结果，复制原始文件
    if [ -f "$GFF3_INPUT" ]; then
        cp "$GFF3_INPUT" "$UPDATED_GFF3"
        log_warn "使用原始GFF3（未找到更新结果）"
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "使用转录组数据更新基因结构注释"
    log_info "样本: ${SPECIES}"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查输入
    if ! check_inputs; then
        log_error "输入文件检查失败，退出"
        exit 1
    fi
    
    # 尝试多种更新方法
    SUCCESS=0
    
    # 方法1: gffcompare
    if update_with_gffcompare; then
        SUCCESS=1
        extract_improved_genes
    fi
    
    # 方法2: StringTie合并
    if update_with_stringtie; then
        SUCCESS=1
    fi
    
    # 方法3: PASA（如果可用）
    update_with_pasa || true
    
    # 方法4: TACO（如果可用）
    update_with_taco || true
    
    # 生成最终结果
    if [ $SUCCESS -eq 1 ]; then
        generate_updated_gff3
        
        log_info ""
        log_info "=========================================="
        log_info "更新完成"
        log_info "结果保存在: $OUTPUT_DIR"
        log_info "=========================================="
    else
        log_error "所有更新方法都失败，请检查日志"
        exit 1
    fi
}

main "$@"

