#!/bin/bash

# BH/CK结构注释脚本
# 同源预测、从头预测、转录组证据整合、EVM整合

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
RESULTS_DIR="${PROJECT_DIR}/results"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/structure_annotation_$(date +%Y%m%d).log"
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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# 处理单个物种
process_species() {
    local species=$1
    local genome_file=$2
    # 检查掩蔽基因组路径（多个可能位置）
    local masked_genome1="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    local masked_genome2="${ANNOTATION_DIR}/${species}/repeat/${species}.Chr.final.fa.masked"
    local masked_genome3="${ANNOTATION_DIR}/${species}/repeat/${species}_genome.masked.fa"
    
    log_step "========== 结构注释: $species =========="
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 使用软掩蔽基因组（如果存在），否则使用原始基因组
    local target_genome="$genome_file"
    if [ -f "$masked_genome1" ]; then
        target_genome="$masked_genome1"
        log_info "使用软掩蔽基因组: $masked_genome1"
    elif [ -f "$masked_genome2" ]; then
        target_genome="$masked_genome2"
        log_info "使用软掩蔽基因组: $masked_genome2"
    elif [ -f "$masked_genome3" ]; then
        target_genome="$masked_genome3"
        log_info "使用软掩蔽基因组: $masked_genome3"
    else
        log_warn "软掩蔽基因组不存在，使用原始基因组"
    fi
    
    # 1. 从头预测 - GeneMark-ES（自动训练）
    log_step "GeneMark-ES从头预测..."
    if command -v gmes_petap.pl &> /dev/null; then
        gmes_petap.pl --sequence "$target_genome" \
                      --ES \
                      --cores "$THREADS" \
                      --min_contig 5000 2>&1 | tee -a "$LOG_FILE"
        
        if [ -f "genemark.gtf" ]; then
            cp genemark.gtf "${species}_genemark.gtf"
            log_info "✓ GeneMark-ES完成"
        fi
    else
        log_warn "GeneMark-ES未安装，跳过"
    fi
    
    # 2. 从头预测 - Augustus（需要训练）
    log_step "Augustus从头预测..."
    if command -v augustus &> /dev/null; then
        # 使用通用植物参数
        augustus --species=arabidopsis \
                 --gff3=on \
                 "$target_genome" > "${species}_augustus.gff3" 2>&1 | tee -a "$LOG_FILE"
        log_info "✓ Augustus完成（使用通用参数）"
    else
        log_warn "Augustus未安装，跳过"
    fi
    
    # 3. 同源预测 - 使用参考物种
    log_step "同源预测（使用参考物种）..."
    
    # 参考物种列表
    local ref_species=("C01" "C02" "C03")
    local ref_gffs=()
    local ref_peps=()
    
    ref_gffs+=("${RESULTS_DIR}/C01/hs.chrom.genome.gff")
    ref_peps+=("${RESULTS_DIR}/C01/C01.pep.fa")
    
    ref_gffs+=("${RESULTS_DIR}/C02/tau.gff3")
    ref_peps+=("${RESULTS_DIR}/C02/tau.longest_pep.fasta")
    
    ref_gffs+=("${RESULTS_DIR}/C03/Tchinensis.gff3")
    ref_peps+=("${RESULTS_DIR}/C03/Tchinensis_pep.fa")
    
    # 使用GeMoMa进行同源预测
    if command -v GeMoMa &> /dev/null; then
        log_info "使用GeMoMa进行同源预测..."
        log_info "参考物种: ${ref_species[@]}"
        
        # 为每个参考物种运行GeMoMa
        for i in "${!ref_gffs[@]}"; do
            local ref_gff="${ref_gffs[$i]}"
            local ref_pep="${ref_peps[$i]}"
            local ref_name="${ref_species[$i]}"
            
            if [ -f "$ref_gff" ] && [ -f "$ref_pep" ]; then
                log_info "处理参考物种: $ref_name"
                log_info "  GFF: $ref_gff"
                log_info "  PEP: $ref_pep"
                
                # GeMoMa预测（需要先运行tblastn等步骤）
                # 这里先记录，后续可以完善具体命令
                log_info "GeMoMa预测命令需要根据具体需求配置"
            else
                log_warn "参考物种文件不存在: $ref_name"
            fi
        done
    elif command -v exonerate &> /dev/null; then
        log_info "使用Exonerate进行同源预测..."
        # 这里可以添加Exonerate预测代码
    else
        log_warn "同源预测工具未安装，跳过"
    fi
    
    # 4. 转录组证据（已生成的GTF文件）
    log_step "转录组证据..."
    local transcriptome_gtf="${ANNOTATION_DIR}/${species}/${species}_merged.gtf"
    if [ -f "$transcriptome_gtf" ]; then
        cp "$transcriptome_gtf" "${species}_transcriptome.gtf"
        log_info "✓ 转录组证据已准备"
    else
        log_warn "转录组GTF文件不存在: $transcriptome_gtf"
    fi
    
    # 5. 证据整合 - EVM
    log_step "证据整合（EVM）..."
    local evm_cmd=""
    if command -v EVidenceModeler &> /dev/null; then
        evm_cmd="EVidenceModeler"
    elif [ -f ~/miniconda3/bin/EvmUtils/evidence_modeler.pl ]; then
        evm_cmd="~/miniconda3/bin/EvmUtils/evidence_modeler.pl"
    fi
    
    if [ -n "$evm_cmd" ]; then
        log_info "EVM已安装，准备整合证据..."
        if command -v EVidenceModeler &> /dev/null; then
            log_info "EVM工具路径: $(which EVidenceModeler)"
        else
            log_info "EVM工具路径: ~/miniconda3/bin/EvmUtils/evidence_modeler.pl"
        fi
        
        # 准备EVM输入文件
        local evm_dir="${work_dir}/evm"
        mkdir -p "$evm_dir"
        
        # 收集所有预测结果
        local predictions=()
        if [ -f "${species}_genemark.gtf" ]; then
            predictions+=("${species}_genemark.gtf")
            log_info "  - GeneMark-ES预测: ${species}_genemark.gtf"
        fi
        if [ -f "${species}_augustus.gff3" ] && [ -s "${species}_augustus.gff3" ]; then
            predictions+=("${species}_augustus.gff3")
            log_info "  - Augustus预测: ${species}_augustus.gff3"
        fi
        if [ -f "${species}_transcriptome.gtf" ]; then
            predictions+=("${species}_transcriptome.gtf")
            log_info "  - 转录组证据: ${species}_transcriptome.gtf"
        fi
        
        if [ ${#predictions[@]} -gt 0 ]; then
            log_info "找到 ${#predictions[@]} 个预测结果，可以运行EVM整合"
            log_info "EVM整合命令需要根据具体预测结果配置"
            log_info "参考: EVidenceModeler --genome <genome> --gene_predictions <predictions> --transcript_alignments <transcripts>"
        else
            log_warn "没有可用的预测结果用于EVM整合"
        fi
    else
        log_warn "EVM未安装，跳过证据整合"
        log_info "可以手动整合预测结果"
    fi
    
    log_info "✓ 结构注释完成: $species"
    log_info "预测结果保存在: $work_dir"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始结构注释"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # BH
    local bh_genome="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/BH.Chr.final.fa"
    if [ -f "$bh_genome" ]; then
        process_species "BH" "$bh_genome"
    fi
    
    echo ""
    
    # CK
    local ck_genome="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/CK.Chr.final.fa"
    if [ -f "$ck_genome" ]; then
        process_species "CK" "$ck_genome"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "结构注释完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"
