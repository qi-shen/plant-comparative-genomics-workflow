#!/bin/bash
# EVM整合脚本 v3.0 - 修复转录组格式
# 使用EVidenceModeler v2.1.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 配置
PROJECT_DIR="${PROJECT_ROOT}"
EVM="${PROJECT_ROOT}"
THREADS=32
SEGMENT_SIZE=500000
OVERLAP_SIZE=50000

# 处理单个物种
process_species() {
    local SPECIES=$1
    local GENOME="${PROJECT_DIR}/annotation/${SPECIES}/${SPECIES}_genome.masked.fa"
    local WORK_DIR="${PROJECT_DIR}/annotation/${SPECIES}/structure/evm"
    local OUTPUT_DIR="${WORK_DIR}/evm_output_v3"
    
    log_step "========== EVM整合: ${SPECIES} =========="
    
    # 检查基因组文件
    if [ ! -f "$GENOME" ]; then
        log_error "基因组文件不存在: $GENOME"
        return 1
    fi
    
    cd "$WORK_DIR"
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    # 准备AUGUSTUS GFF3
    log_info "准备AUGUSTUS证据..."
    local AUGUSTUS_ORIG="${WORK_DIR}/augustus.gff3"
    local AUGUSTUS_FIXED="${WORK_DIR}/augustus_evm.gff3"
    
    grep -v "^#" "$AUGUSTUS_ORIG" | \
        grep -E "^[^	]+	[^	]+	(gene|transcript|exon|CDS)	" | \
        sed 's/\tAUGUSTUS\t/\taugustus\t/g' | \
        sed 's/\ttranscript\t/\tmRNA\t/g' > "$AUGUSTUS_FIXED"
    
    log_info "AUGUSTUS证据行数: $(wc -l < $AUGUSTUS_FIXED)"
    
    # 准备转录组GFF3（用Python脚本修复格式）
    log_info "准备转录组证据（添加exon ID）..."
    local TRANS_ORIG="${WORK_DIR}/transcriptome.gff3"
    local TRANS_FIXED="${WORK_DIR}/transcriptome_evm.gff3"
    
    python3 "${PROJECT_DIR}/scripts/fix_transcript_gff3.py" \
        "$TRANS_ORIG" "$TRANS_FIXED" "transcriptome"
    
    log_info "转录组证据行数: $(wc -l < $TRANS_FIXED)"
    
    # 验证修复后的格式
    log_info "验证转录组格式..."
    echo "修复后exon示例:"
    grep -m3 "exon" "$TRANS_FIXED" | head -3
    
    # 创建权重文件
    log_info "创建权重文件..."
    cat > "${WORK_DIR}/weights_evm.txt" << 'EOF'
ABINITIO_PREDICTION	augustus	5
TRANSCRIPT	transcriptome	10
EOF
    cat "${WORK_DIR}/weights_evm.txt"
    
    # 运行EVM
    log_step "运行EVM整合..."
    log_info "参数: genome=$GENOME, segmentSize=$SEGMENT_SIZE, CPU=$THREADS"
    
    cd "$OUTPUT_DIR"
    
    $EVM \
        --sample_id "${SPECIES}" \
        --genome "$GENOME" \
        --weights "${WORK_DIR}/weights_evm.txt" \
        --gene_predictions "$AUGUSTUS_FIXED" \
        --transcript_alignments "$TRANS_FIXED" \
        --segmentSize "$SEGMENT_SIZE" \
        --overlapSize "$OVERLAP_SIZE" \
        --CPU "$THREADS" \
        --exec_dir "$OUTPUT_DIR" \
        2>&1 | tee "${OUTPUT_DIR}/evm.log"
    
    # 检查输出
    local EVM_OUTPUT="${OUTPUT_DIR}/${SPECIES}.EVM.gff3"
    if [ -f "$EVM_OUTPUT" ]; then
        log_info "✅ EVM输出文件: $EVM_OUTPUT"
        local GENE_COUNT=$(grep -c "	gene	" "$EVM_OUTPUT" || echo 0)
        log_info "基因数量: $GENE_COUNT"
        
        # 复制到最终位置
        cp "$EVM_OUTPUT" "${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_evm.gff3"
        log_info "✅ 复制到: ${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_evm.gff3"
    else
        log_warn "标准输出文件不存在，查找其他可能的输出..."
        ls -la "$OUTPUT_DIR/"
        
        # 查找可能的输出
        local FOUND=$(find "$OUTPUT_DIR" -name "*.gff3" 2>/dev/null | head -1)
        if [ -n "$FOUND" ]; then
            log_info "找到: $FOUND"
        fi
    fi
    
    log_info "✅ ${SPECIES} EVM整合完成"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "EVM证据整合 v3.0 (修复转录组格式)"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    # 检查EVM
    if [ ! -x "$EVM" ]; then
        log_error "EVM不存在: $EVM"
        exit 1
    fi
    
    log_info "EVM: $($EVM --version 2>&1 | grep -o 'v[0-9.]*' || echo 'unknown')"
    
    # 处理BH
    process_species "T01" || log_error "BH处理失败"
    
    echo ""
    
    # 处理CK
    process_species "T02" || log_error "CK处理失败"
    
    log_info ""
    log_info "=========================================="
    log_info "EVM整合完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"
