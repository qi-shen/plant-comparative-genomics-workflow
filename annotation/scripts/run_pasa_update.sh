#!/bin/bash

# PASA更新基因结构注释脚本
# 使用转录组数据改进基因模型

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
SPECIES=${1:-"T01"}  # 默认BH，可指定CK

# PASA路径
PASA_HOME="${PROJECT_ROOT}"
PASA_CMD="${PASA_HOME}/Launch_PASA_pipeline.pl"

# 文件路径
GENOME="${PROJECT_DIR}/annotation/${SPECIES}/${SPECIES}_genome.masked.fa"
GFF3_INPUT="${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_final.gff3"
GTF_TRANSCRIPTOME="${PROJECT_DIR}/annotation/${SPECIES}/transcriptome/${SPECIES}_merged.gtf"
PASA_CONF_DIR="${PROJECT_DIR}/annotation/${SPECIES}/pasa_update"
CONFIG_FILE="${PASA_CONF_DIR}/pasa.CONFIG"
GFF3_TRANSCRIPTOME="${PASA_CONF_DIR}/${SPECIES}_transcriptome.gff3"
OUTPUT_DIR="${PASA_CONF_DIR}"
LOG_FILE="${PROJECT_DIR}/logs/pasa_update_${SPECIES}_$(date +%Y%m%d_%H%M%S).log"
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

# 检查PASA是否安装
check_pasa() {
    log_step "检查PASA安装..."
    
    if [ ! -f "$PASA_CMD" ]; then
        log_error "PASA未找到: $PASA_CMD"
        log_info "请先运行: bash scripts/setup_pasa.sh ${SPECIES}"
        exit 1
    fi
    
    log_info "✓ PASA已找到: $PASA_CMD"
}

# 检查输入文件
check_inputs() {
    log_step "检查输入文件..."
    
    if [ ! -f "$GENOME" ]; then
        log_error "基因组文件不存在: $GENOME"
        return 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warn "PASA配置文件不存在，正在创建..."
        bash "${PROJECT_DIR}/scripts/setup_pasa.sh" "$SPECIES"
    fi
    
    if [ ! -f "$GFF3_TRANSCRIPTOME" ]; then
        log_warn "转录组GFF3文件不存在，正在转换..."
        if command -v gffread &> /dev/null; then
            gffread -E "$GTF_TRANSCRIPTOME" -o "$GFF3_TRANSCRIPTOME" 2>&1 | tee -a "$LOG_FILE"
        else
            log_error "gffread未找到，无法转换GTF"
            return 1
        fi
    fi
    
    log_info "✓ 输入文件检查完成"
    return 0
}

# 运行PASA对齐和组装
run_pasa_align_assembly() {
    log_step "运行PASA对齐和组装..."
    
    cd "$OUTPUT_DIR"
    
    log_info "运行PASA对齐转录组到基因组..."
    log_info "这可能需要较长时间（数小时）..."
    
    # 运行PASA对齐和组装
    conda run -n pasa $PASA_CMD \
        -c "$CONFIG_FILE" \
        -C -R \
        -g "$GENOME" \
        -t "$GFF3_TRANSCRIPTOME" \
        --ALIGNERS gmap,blat \
        --CPU "$THREADS" \
        2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ PASA对齐和组装完成"
        return 0
    else
        log_error "✗ PASA对齐和组装失败"
        return 1
    fi
}

# 运行PASA更新现有注释
run_pasa_update() {
    log_step "运行PASA更新现有注释..."
    
    if [ ! -f "$GFF3_INPUT" ]; then
        log_warn "输入GFF3不存在，跳过更新步骤"
        return 0
    fi
    
    cd "$OUTPUT_DIR"
    
    log_info "使用PASA更新现有注释..."
    log_info "这将使用转录组数据改进现有基因模型..."
    
    # 运行PASA更新
    conda run -n pasa $PASA_CMD \
        -c "$CONFIG_FILE" \
        -g "$GENOME" \
        -t "$GFF3_TRANSCRIPTOME" \
        -u "$GFF3_INPUT" \
        --ALIGNERS gmap,blat \
        --CPU "$THREADS" \
        2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ PASA更新完成"
        return 0
    else
        log_error "✗ PASA更新失败"
        return 1
    fi
}

# 提取更新的注释
extract_updated_annotation() {
    log_step "提取更新的注释..."
    
    cd "$OUTPUT_DIR"
    
    # PASA的输出文件
    PASA_ASSEMBLIES="${OUTPUT_DIR}/pasa_assemblies.gff3"
    UPDATED_GFF3="${OUTPUT_DIR}/${SPECIES}_pasa_updated.gff3"
    
    # 查找PASA输出文件
    if [ -f "$PASA_ASSEMBLIES" ]; then
        cp "$PASA_ASSEMBLIES" "$UPDATED_GFF3"
        log_info "✓ 更新的注释已保存: $UPDATED_GFF3"
    else
        # 查找其他可能的输出文件
        PASA_OUTPUT=$(find "$OUTPUT_DIR" -name "*assemblies*.gff3" | head -1)
        if [ -n "$PASA_OUTPUT" ]; then
            cp "$PASA_OUTPUT" "$UPDATED_GFF3"
            log_info "✓ 更新的注释已保存: $UPDATED_GFF3"
        else
            log_warn "未找到PASA输出文件，可能需要手动查找"
            log_info "PASA输出通常在: $OUTPUT_DIR"
        fi
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始PASA更新基因结构注释"
    log_info "样本: ${SPECIES}"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查PASA
    check_pasa
    
    # 检查输入
    if ! check_inputs; then
        log_error "输入文件检查失败，退出"
        exit 1
    fi
    
    # 运行PASA对齐和组装
    if run_pasa_align_assembly; then
        # 运行PASA更新（如果有现有注释）
        if [ -f "$GFF3_INPUT" ]; then
            run_pasa_update
        fi
        
        # 提取更新的注释
        extract_updated_annotation
        
        log_info ""
        log_info "=========================================="
        log_info "PASA更新完成"
        log_info "结果保存在: $OUTPUT_DIR"
        log_info "=========================================="
        log_info ""
        log_info "下一步:"
        log_info "1. 检查更新的注释文件"
        log_info "2. 提取蛋白质序列并重新运行BUSCO评估"
        log_info "3. 比较改进前后的结果"
    else
        log_error "PASA对齐失败，请检查日志: $LOG_FILE"
        exit 1
    fi
}

main "$@"
