#!/bin/bash

# 比较基因组分析 - 数据解压和序列提取脚本
# 创建日期: 2024年12月4日
# 用途: 解压.gz文件并提取CDS/PEP序列

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_DIR="/path/to/project_root"
RESULTS_DIR="${PROJECT_DIR}/results"

# 日志文件
LOG_FILE="${PROJECT_DIR}/logs/decompress_extract.log"
mkdir -p "${PROJECT_DIR}/logs"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查gffread是否安装
check_gffread() {
    if ! command -v gffread &> /dev/null; then
        log_warn "gffread未安装，将跳过序列提取步骤"
        log_warn "请安装: conda install -c bioconda gffread"
        return 1
    fi
    return 0
}

# 解压函数
decompress_file() {
    local file=$1
    local target_dir=$2
    
    if [ -f "$file" ]; then
        log_info "解压: $file"
        cd "$target_dir"
        gunzip -f "$(basename "$file")" 2>&1 | tee -a "$LOG_FILE"
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            log_info "✓ 解压成功: $(basename "$file")"
        else
            log_error "✗ 解压失败: $file"
            return 1
        fi
    else
        log_warn "文件不存在: $file"
        return 1
    fi
}

# 提取CDS和PEP序列
extract_sequences() {
    local genome=$1
    local gff=$2
    local output_dir=$3
    local prefix=$4
    
    if [ ! -f "$genome" ]; then
        log_error "基因组文件不存在: $genome"
        return 1
    fi
    
    if [ ! -f "$gff" ]; then
        log_error "GFF文件不存在: $gff"
        return 1
    fi
    
    log_info "提取序列: $prefix"
    log_info "  基因组: $genome"
    log_info "  注释: $gff"
    
    cd "$output_dir"
    
    # 提取CDS
    if gffread -x "${prefix}.cds.fa" -g "$genome" "$gff" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "✓ CDS提取成功: ${prefix}.cds.fa"
    else
        log_error "✗ CDS提取失败"
        return 1
    fi
    
    # 提取蛋白质
    if gffread -y "${prefix}.pep.fa" -g "$genome" "$gff" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "✓ PEP提取成功: ${prefix}.pep.fa"
    else
        log_error "✗ PEP提取失败"
        return 1
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始数据解压和序列提取"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查gffread
    HAS_GFFREAD=$(check_gffread && echo "yes" || echo "no")
    
    # ========== 第一部分：解压.gz文件 ==========
    log_info ""
    log_info "========== 第一部分：解压.gz文件 =========="
    
    # 1. C08 - 解压基因组
    log_info ""
    log_info "【1/6】C08 - 解压基因组"
    FALLOPIA_DIR="${RESULTS_DIR}/C08"
    if [ -f "${FALLOPIA_DIR}/AYY_all_genome.fasta.gz" ]; then
        decompress_file "${FALLOPIA_DIR}/AYY_all_genome.fasta.gz" "$FALLOPIA_DIR"
    else
        log_warn "C08基因组.gz文件不存在，可能已解压"
    fi
    
    # 2. C10 - 解压所有.gz文件
    log_info ""
    log_info "【2/6】C10 - 解压所有.gz文件"
    PORTULACA_DIR="${RESULTS_DIR}/C10"
    cd "$PORTULACA_DIR"
    for gz_file in *.gz; do
        if [ -f "$gz_file" ]; then
            log_info "解压: $gz_file"
            gunzip -f "$gz_file" 2>&1 | tee -a "$LOG_FILE"
            log_info "✓ 解压成功: $gz_file"
        fi
    done
    
    # 3. O01 - 解压所有.gz文件
    log_info ""
    log_info "【3/6】O01 - 解压所有.gz文件"
    ARABIDOPSIS_DIR="${RESULTS_DIR}/O01"
    cd "$ARABIDOPSIS_DIR"
    for gz_file in *.gz; do
        if [ -f "$gz_file" ]; then
            log_info "解压: $gz_file"
            gunzip -f "$gz_file" 2>&1 | tee -a "$LOG_FILE"
            log_info "✓ 解压成功: $gz_file"
        fi
    done
    
    # 4. C07 - 解压基因组
    log_info ""
    log_info "【4/6】C07 - 解压基因组"
    GYPSOPHILA_DIR="${RESULTS_DIR}/C07"
    if [ -f "${GYPSOPHILA_DIR}/Gpan_WG.chromosome.fasta.gz" ]; then
        decompress_file "${GYPSOPHILA_DIR}/Gpan_WG.chromosome.fasta.gz" "$GYPSOPHILA_DIR"
    else
        log_warn "C07基因组.gz文件不存在，可能已解压"
    fi
    
    # 5. C11 - 解压hap1相关文件
    log_info ""
    log_info "【5/6】C11 - 解压hap1相关文件"
    SELENICEREUS_DIR="${RESULTS_DIR}/C11"
    cd "$SELENICEREUS_DIR"
    for gz_file in hap1.*.gz; do
        if [ -f "$gz_file" ]; then
            log_info "解压: $gz_file"
            gunzip -f "$gz_file" 2>&1 | tee -a "$LOG_FILE"
            log_info "✓ 解压成功: $gz_file"
        fi
    done
    
    # 6. C06 - 解压hap1基因组
    log_info ""
    log_info "【6/6】C06 - 解压hap1基因组"
    DIANTHUS_DIR="${RESULTS_DIR}/C06"
    if [ -f "${DIANTHUS_DIR}/bxgz.hap1.fa.gz" ]; then
        decompress_file "${DIANTHUS_DIR}/bxgz.hap1.fa.gz" "$DIANTHUS_DIR"
    else
        log_warn "C06hap1基因组.gz文件不存在，可能已解压"
    fi
    
    # ========== 第二部分：提取序列 ==========
    if [ "$HAS_GFFREAD" = "yes" ]; then
        log_info ""
        log_info "========== 第二部分：提取CDS/PEP序列 =========="
        
        # 7. O01 - 提取CDS/PEP
        log_info ""
        log_info "【7/9】O01 - 提取CDS/PEP序列"
        ARABIDOPSIS_GENOME="${ARABIDOPSIS_DIR}/O01.TAIR10.dna.toplevel.fa"
        ARABIDOPSIS_GFF="${ARABIDOPSIS_DIR}/O01.TAIR10.61.gff3"
        if [ -f "$ARABIDOPSIS_GENOME" ] && [ -f "$ARABIDOPSIS_GFF" ]; then
            extract_sequences "$ARABIDOPSIS_GENOME" "$ARABIDOPSIS_GFF" "$ARABIDOPSIS_DIR" "O01"
        else
            log_warn "O01基因组或GFF文件不存在，跳过"
        fi
        
        # 8. O02 - 提取CDS/PEP
        log_info ""
        log_info "【8/9】O02 - 提取CDS/PEP序列"
        VITIS_DIR="${RESULTS_DIR}/O02"
        VITIS_GENOME="${VITIS_DIR}/PN40024.T21.fa"
        VITIS_GFF="${VITIS_DIR}/PN40024.gff"
        if [ -f "$VITIS_GENOME" ] && [ -f "$VITIS_GFF" ]; then
            extract_sequences "$VITIS_GENOME" "$VITIS_GFF" "$VITIS_DIR" "O02"
        else
            log_warn "O02基因组或GFF文件不存在，跳过"
        fi
        
        # 9. C06 - 提取CDS/PEP
        log_info ""
        log_info "【9/9】C06 - 提取CDS/PEP序列"
        DIANTHUS_GENOME="${DIANTHUS_DIR}/bxgz.hap1.fa"
        DIANTHUS_GFF="${DIANTHUS_DIR}/bxgz.hap1.evm_out.gff3"
        if [ -f "$DIANTHUS_GENOME" ] && [ -f "$DIANTHUS_GFF" ]; then
            extract_sequences "$DIANTHUS_GENOME" "$DIANTHUS_GFF" "$DIANTHUS_DIR" "C06_hap1"
        else
            log_warn "C06基因组或GFF文件不存在，跳过"
        fi
    else
        log_warn "跳过序列提取步骤（gffread未安装）"
    fi
    
    # ========== 总结 ==========
    log_info ""
    log_info "=========================================="
    log_info "数据解压和序列提取完成"
    log_info "时间: $(date)"
    log_info "=========================================="
    log_info "详细日志已保存到: $LOG_FILE"
}

# 运行主函数
main "$@"

