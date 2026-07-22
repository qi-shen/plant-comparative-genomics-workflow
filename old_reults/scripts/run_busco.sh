#!/bin/bash

# BUSCO评估脚本
# 对所有比较物种和BH/CK进行BUSCO评估

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
RESULTS_DIR="${PROJECT_DIR}/results"
BUSCO_DIR="${PROJECT_DIR}/qc_results/BUSCO"
LOG_FILE="${PROJECT_DIR}/logs/busco_$(date +%Y%m%d).log"
THREADS=8

mkdir -p "$BUSCO_DIR" "${PROJECT_DIR}/logs"

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

# 运行BUSCO评估
run_busco() {
    local genome_file=$1
    local species_name=$2
    local output_dir="${BUSCO_DIR}/${species_name}"
    
    if [ ! -f "$genome_file" ]; then
        log_error "基因组文件不存在: $genome_file"
        return 1
    fi
    
    log_step "运行BUSCO评估: $species_name"
    log_info "基因组文件: $genome_file"
    
    mkdir -p "$output_dir"
    
    cd "$output_dir"
    
    export PATH="$HOME/miniconda3/bin:$PATH"
    
    # 使用绝对路径
    local abs_genome_file=$(readlink -f "$genome_file")
    
    busco -i "$abs_genome_file" \
          -l embryophyta_odb10 \
          -o "${species_name}" \
          -m genome \
          -c "$THREADS" \
          2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ BUSCO评估完成: $species_name"
    else
        log_error "✗ BUSCO评估失败: $species_name"
        return 1
    fi
}

# 生成汇总报告
generate_summary() {
    local summary_file="${BUSCO_DIR}/BUSCO_summary.txt"
    
    log_info "生成BUSCO汇总报告..."
    
    {
        echo "=========================================="
        echo "BUSCO评估汇总报告"
        echo "生成时间: $(date)"
        echo "数据库: embryophyta_odb10"
        echo "=========================================="
        echo ""
        
        for species_dir in "${BUSCO_DIR}"/*/; do
            if [ -d "$species_dir" ]; then
                species=$(basename "$species_dir")
                short_summary=$(find "$species_dir" -name "short_summary.*.txt" | head -1)
                if [ -f "$short_summary" ]; then
                    echo "【$species】"
                    grep -E "Complete|Single|Duplicated|Fragmented|Missing|Total" "$short_summary" | head -10
                    echo ""
                fi
            fi
        done
    } > "$summary_file"
    
    log_info "✓ 汇总报告已生成: $summary_file"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始BUSCO评估"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查BUSCO是否安装
    if ! command -v busco &> /dev/null; then
        log_error "BUSCO未安装，请先运行 install_busco.sh"
        exit 1
    fi
    
    # 定义物种列表
    declare -A species_genomes
    
    # 比较物种
    species_genomes["C01"]="${RESULTS_DIR}/C01/hs.chrom.genome.final.fa"
    species_genomes["C02"]="${RESULTS_DIR}/C02/tau_genome.fasta"
    species_genomes["C03"]="${RESULTS_DIR}/C03/Tchinensis.fasta"
    species_genomes["C04"]="${RESULTS_DIR}/C04/Haplome_1/AmaPa_v01_hap1.fasta"
    species_genomes["C05"]="${RESULTS_DIR}/C05/0321072RM_v1.fasta"
    species_genomes["C06"]="${RESULTS_DIR}/C06/bxgz.hap1.fa"
    species_genomes["C07"]="${RESULTS_DIR}/C07/Gpan_WG.chromosome.fasta"
    species_genomes["C08"]="${RESULTS_DIR}/C08/AYY_all_genome.fasta"
    species_genomes["C09"]="${RESULTS_DIR}/C09/genome_v2.fasta"
    species_genomes["C10"]="${RESULTS_DIR}/C10/GWHCBIU00000000.genome.fasta"
    species_genomes["O01"]="${RESULTS_DIR}/O01/O01.TAIR10.dna.toplevel.fa"
    species_genomes["O02"]="${RESULTS_DIR}/O02/PN40024.T21.fa"
    species_genomes["C11"]="${RESULTS_DIR}/C11/hap1.fa"
    
    # BH和CK（如果已解压）
    if [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/BH.Chr.final.fa" ]; then
        species_genomes["BH"]="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/BH.Chr.final.fa"
    elif [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/BH.Chr.final.fa.gz" ]; then
        log_warn "BH基因组未解压，跳过"
    fi
    
    if [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/CK.Chr.final.fa" ]; then
        species_genomes["CK"]="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/CK.Chr.final.fa"
    elif [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/CK.Chr.final.fa.gz" ]; then
        log_warn "CK基因组未解压，跳过"
    fi
    
    # 运行BUSCO评估
    local count=0
    local total=${#species_genomes[@]}
    
    for species in "${!species_genomes[@]}"; do
        count=$((count + 1))
        genome="${species_genomes[$species]}"
        
        if [ -f "$genome" ]; then
            log_step "[$count/$total] 评估物种: $species"
            run_busco "$genome" "$species"
            echo ""
        else
            log_warn "跳过 $species (文件不存在: $genome)"
        fi
    done
    
    # 生成汇总报告
    generate_summary
    
    log_info ""
    log_info "=========================================="
    log_info "BUSCO评估完成"
    log_info "时间: $(date)"
    log_info "结果保存在: $BUSCO_DIR"
    log_info "=========================================="
}

main "$@"

