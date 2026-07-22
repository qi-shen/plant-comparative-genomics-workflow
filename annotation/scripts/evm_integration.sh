#!/bin/bash

# EVM证据整合脚本
# 整合所有预测结果：转录组、GeneMark-ES、GeMoMa、Augustus（如果完成）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/evm_integration_$(date +%Y%m%d_%H%M%S).log"
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

# 检查EVM安装
check_evm() {
    if command -v EVidenceModeler &> /dev/null; then
        echo "EVidenceModeler"
    elif command -v evidence_modeler.pl &> /dev/null; then
        echo "evidence_modeler.pl"
    elif [ -f "$HOME/miniconda3/bin/EvmUtils/evidence_modeler.pl" ]; then
        echo "$HOME/miniconda3/bin/EvmUtils/evidence_modeler.pl"
    else
        echo ""
    fi
}

# 准备EVM输入文件
prepare_evm_inputs() {
    local species=$1
    local work_dir="${ANNOTATION_DIR}/${species}/structure/evm"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    log_step "准备EVM输入文件: $species"
    
    local genome_file="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    local evidence_files=()
    
    # 1. 转录组证据
    local transcriptome_gff="${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3"
    if [ -f "$transcriptome_gff" ]; then
        log_info "✓ 转录组证据: $transcriptome_gff"
        evidence_files+=("TRANSCRIPT:$transcriptome_gff")
    else
        log_warn "转录组证据不存在: $transcriptome_gff"
    fi
    
    # 2. GeneMark-ES
    local genemark_gtf="${ANNOTATION_DIR}/${species}/structure/genemark.gtf"
    if [ -f "$genemark_gtf" ]; then
        log_info "✓ GeneMark-ES证据: $genemark_gtf"
        # 转换GTF为GFF3
        local genemark_gff="${work_dir}/${species}_genemark.gff3"
        if command -v gffread &> /dev/null; then
            gffread -E "$genemark_gtf" -o "$genemark_gff" 2>&1 | tee -a "$LOG_FILE" || {
                log_warn "GeneMark-ES GTF转GFF3失败，尝试直接使用"
                cp "$genemark_gtf" "$genemark_gff"
            }
        else
            cp "$genemark_gtf" "$genemark_gff"
        fi
        evidence_files+=("ABINITIO_PREDICTION:$genemark_gff")
    else
        log_warn "GeneMark-ES输出不存在: $genemark_gtf"
    fi
    
    # 3. GeMoMa
    local gemoma_gff="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
    if [ -f "$gemoma_gff" ]; then
        log_info "✓ GeMoMa证据: $gemoma_gff"
        evidence_files+=("PROTEIN:$gemoma_gff")
    else
        log_warn "GeMoMa输出不存在: $gemoma_gff"
    fi
    
    # 4. Augustus（如果完成）
    local augustus_gff="${ANNOTATION_DIR}/${species}/structure/${species}_augustus.gff3"
    if [ -f "$augustus_gff" ]; then
        local augustus_size=$(du -m "$augustus_gff" | cut -f1)
        # 检查是否完成（文件大小应该接近基因组大小）
        if [ "$augustus_size" -gt 100 ]; then
            log_info "✓ Augustus证据: $augustus_gff (${augustus_size}MB)"
            evidence_files+=("ABINITIO_PREDICTION:$augustus_gff")
        else
            log_warn "Augustus输出可能未完成: $augustus_gff (${augustus_size}MB)"
        fi
    else
        log_warn "Augustus输出不存在: $augustus_gff"
    fi
    
    if [ ${#evidence_files[@]} -eq 0 ]; then
        log_error "没有可用的证据文件"
        return 1
    fi
    
    log_info "找到 ${#evidence_files[@]} 个证据文件"
    
    # 创建EVM配置文件
    local evm_config="${work_dir}/evm.config"
    cat > "$evm_config" << EOF
# EVM配置文件
# 基因组文件
GENOME=$genome_file

# 证据文件
EOF
    
    for evidence in "${evidence_files[@]}"; do
        echo "$evidence" >> "$evm_config"
    done
    
    log_info "EVM配置文件: $evm_config"
    cat "$evm_config"
    
    echo "$evm_config"
}

# 运行EVM
run_evm() {
    local species=$1
    local evm_config=$2
    
    log_step "运行EVM整合: $species"
    
    local evm_cmd=$(check_evm)
    if [ -z "$evm_cmd" ]; then
        log_error "EVM未安装"
        log_info "安装命令: conda install -c bioconda evidencemodeler"
        return 1
    fi
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/evm"
    cd "$work_dir"
    
    local output_gff="${work_dir}/${species}_evm.gff3"
    
    log_info "使用EVM命令: $evm_cmd"
    log_info "开始时间: $(date)"
    
    # 运行EVM
    if [ "$evm_cmd" = "EVidenceModeler" ]; then
        EVidenceModeler --genome "$(grep GENOME "$evm_config" | cut -d= -f2)" \
                       --weights_file "$evm_config" \
                       --output_file "$output_gff" \
                       --threads "$THREADS" 2>&1 | tee -a "$LOG_FILE"
    else
        # 使用evidence_modeler.pl
        perl "$evm_cmd" --genome "$(grep GENOME "$evm_config" | cut -d= -f2)" \
                        --weights_file "$evm_config" \
                        --output_file "$output_gff" \
                        --threads "$THREADS" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    if [ $? -eq 0 ] && [ -f "$output_gff" ]; then
        log_info "✓ EVM整合完成"
        log_info "输出文件: $output_gff"
        log_info "文件大小: $(du -h $output_gff | cut -f1)"
        log_info "完成时间: $(date)"
        
        # 复制到主目录
        cp "$output_gff" "${ANNOTATION_DIR}/${species}/structure/${species}_final.gff3"
        log_info "最终注释文件: ${species}_final.gff3"
    else
        log_error "EVM整合失败"
        return 1
    fi
}

# 处理单个物种
process_species() {
    local species=$1
    
    log_step "========== EVM整合: $species =========="
    
    # 准备输入文件
    local evm_config=$(prepare_evm_inputs "$species")
    if [ -z "$evm_config" ]; then
        log_error "准备EVM输入失败: $species"
        return 1
    fi
    
    # 运行EVM
    run_evm "$species" "$evm_config"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "EVM证据整合"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查EVM
    local evm_cmd=$(check_evm)
    if [ -z "$evm_cmd" ]; then
        log_error "EVM未安装"
        log_info "请先安装: conda install -c bioconda evidencemodeler"
        exit 1
    fi
    
    log_info "EVM命令: $evm_cmd"
    
    # 处理BH和CK
    for species in T01 T02; do
        process_species "$species"
        echo ""
    done
    
    log_info ""
    log_info "=========================================="
    log_info "EVM整合完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

