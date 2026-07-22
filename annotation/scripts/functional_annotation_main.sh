#!/bin/bash

# 功能注释主流程脚本
# 依次执行：序列提取、BLAST、InterProScan、eggNOG-mapper、结果整合

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
LOG_FILE="${PROJECT_DIR}/logs/functional_annotation_main_$(date +%Y%m%d_%H%M%S).log"

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

main() {
    log_info "=========================================="
    log_info "功能注释完整流程"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 步骤1: 提取蛋白质序列
    log_step "步骤1: 提取蛋白质和CDS序列"
    if bash scripts/extract_protein_sequences.sh >> "$LOG_FILE" 2>&1; then
        log_info "✅ 序列提取完成"
    else
        log_error "❌ 序列提取失败"
        exit 1
    fi
    
    echo ""
    
    # 步骤2: 准备BLAST数据库
    log_step "步骤2: 准备BLAST数据库"
    if bash scripts/prepare_blast_databases.sh >> "$LOG_FILE" 2>&1; then
        log_info "✅ 数据库准备检查完成"
    else
        log_warn "⚠️  数据库准备有问题，请检查"
    fi
    
    echo ""
    
    # 步骤3: BLAST比对
    log_step "步骤3: BLAST比对（SwissProt + Nr）"
    log_warn "注意: 如果数据库未准备，此步骤将跳过"
    if bash scripts/run_blast_parallel.sh >> "$LOG_FILE" 2>&1; then
        log_info "✅ BLAST比对完成"
    else
        log_warn "⚠️  BLAST比对失败或跳过（可能数据库未准备）"
    fi
    
    echo ""
    
    # 步骤4: InterProScan（可选）
    log_step "步骤4: InterProScan结构域预测"
    log_warn "注意: 需要InterProScan已安装"
    if bash scripts/run_interproscan.sh >> "$LOG_FILE" 2>&1; then
        log_info "✅ InterProScan完成"
    else
        log_warn "⚠️  InterProScan失败或跳过（可能未安装）"
    fi
    
    echo ""
    
    # 步骤5: eggNOG-mapper（可选，用于GO/KEGG）
    log_step "步骤5: eggNOG-mapper功能注释（可选）"
    log_warn "注意: eggNOG-mapper需要数据库（约20-30GB），当前已跳过"
    log_info "如需使用，请先下载数据库: bash scripts/download_eggnog_database.sh"
    log_info "⏭️  跳过eggNOG-mapper，继续使用BLAST结果进行注释"
    
    echo ""
    
    # 步骤6: 整合注释结果
    log_step "步骤6: 整合所有注释结果"
    if bash scripts/integrate_annotations.sh >> "$LOG_FILE" 2>&1; then
        log_info "✅ 注释整合完成"
    else
        log_warn "⚠️  注释整合失败或部分完成"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "功能注释流程完成"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    log_info ""
    log_info "【最终结果文件】"
    for species in T01 T02; do
        local final_file="${PROJECT_DIR}/annotation/${species}/functional/${species}_functional_annotation.txt"
        if [ -f "$final_file" ]; then
            local size=$(du -h "$final_file" | cut -f1)
            log_info "  $species: $final_file ($size)"
        else
            log_warn "  $species: 整合文件未生成"
        fi
    done
}

main "$@"

