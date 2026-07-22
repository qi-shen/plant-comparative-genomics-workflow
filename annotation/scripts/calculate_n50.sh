#!/bin/bash

# 计算N50值脚本
# 对所有基因组计算N50、N90等统计值

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
RESULTS_DIR="${PROJECT_DIR}/results"
QC_DIR="${PROJECT_DIR}/qc_results"
LOG_FILE="${PROJECT_DIR}/logs/n50_$(date +%Y%m%d).log"

mkdir -p "$QC_DIR" "${PROJECT_DIR}/logs"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# 计算N50等统计值
calculate_n50() {
    local genome_file=$1
    local species=$2
    local output_file="${QC_DIR}/${species}_N50.txt"
    
    if [ ! -f "$genome_file" ]; then
        log_info "基因组文件不存在: $genome_file"
        return 1
    fi
    
    log_step "计算N50: $species"
    
    # 提取序列长度并排序（从大到小）
    local lengths_file=$(mktemp)
    awk '/^>/ {if (seq) print length(seq); seq=""} !/^>/ {seq=seq$0} END {if (seq) print length(seq)}' "$genome_file" | sort -rn > "$lengths_file"
    
    # 计算总长度
    local total_length=$(awk '{sum+=$1} END {print sum}' "$lengths_file")
    local num_seqs=$(wc -l < "$lengths_file")
    
    # 计算N50
    local n50=0
    local cumulative=0
    local n50_threshold=$((total_length / 2))
    
    while read length; do
        cumulative=$((cumulative + length))
        if [ $cumulative -ge $n50_threshold ]; then
            n50=$length
            break
        fi
    done < "$lengths_file"
    
    # 计算N90
    local n90=0
    cumulative=0
    local n90_threshold=$((total_length * 90 / 100))
    
    while read length; do
        cumulative=$((cumulative + length))
        if [ $cumulative -ge $n90_threshold ]; then
            n90=$length
            break
        fi
    done < "$lengths_file"
    
    # 计算最长、最短、平均
    local longest=$(head -1 "$lengths_file")
    local shortest=$(tail -1 "$lengths_file")
    local average=$(awk '{sum+=$1} END {if (NR>0) print int(sum/NR); else print 0}' "$lengths_file")
    
    # 输出结果
    {
        echo "物种: $species"
        echo "基因组文件: $genome_file"
        echo "序列数量: $num_seqs"
        echo "总长度: $total_length bp"
        echo "$(echo "scale=2; $total_length/1000000" | bc) Mb"
        echo "最长序列: $longest bp"
        echo "最短序列: $shortest bp"
        echo "平均长度: $average bp"
        echo "N50: $n50 bp"
        echo "N90: $n90 bp"
    } > "$output_file"
    
    log_info "✓ 完成: $species (N50=$n50, N90=$n90)"
    
    rm -f "$lengths_file"
}

# 生成汇总表
generate_summary() {
    local summary_file="${QC_DIR}/N50_statistics.txt"
    
    log_info "生成N50汇总表..."
    
    {
        echo "=========================================="
        echo "N50统计汇总表"
        echo "生成时间: $(date)"
        echo "=========================================="
        echo ""
        printf "%-15s %12s %10s %12s %12s %12s %12s\n" "物种" "序列数" "总长度(Mb)" "最长(bp)" "N50(bp)" "N90(bp)" "平均(bp)"
        echo "------------------------------------------------------------------------------------------------"
        
        for n50_file in "${QC_DIR}"/*_N50.txt; do
            if [ -f "$n50_file" ]; then
                species=$(basename "$n50_file" _N50.txt)
                num_seqs=$(grep "序列数量" "$n50_file" | awk '{print $2}')
                total_mb=$(grep "Mb" "$n50_file" | awk '{print $1}')
                longest=$(grep "最长序列" "$n50_file" | awk '{print $2}')
                n50=$(grep "^N50" "$n50_file" | awk '{print $2}')
                n90=$(grep "^N90" "$n50_file" | awk '{print $2}')
                average=$(grep "平均长度" "$n50_file" | awk '{print $2}')
                
                printf "%-15s %12s %12s %12s %12s %12s %12s\n" "$species" "$num_seqs" "$total_mb" "$longest" "$n50" "$n90" "$average"
            fi
        done
        echo ""
        echo "=========================================="
    } > "$summary_file"
    
    log_info "✓ 汇总表已生成: $summary_file"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始计算N50值"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 定义物种列表
    declare -A species_genomes
    
    # 比较物种
    species_genomes["C01"]="${RESULTS_DIR}/C01/hs.chrom.genome.final.fa"
    species_genomes["C02"]="${RESULTS_DIR}/C02/C02_genome.fasta"
    species_genomes["C03"]="${RESULTS_DIR}/C03/genome.fa"
    species_genomes["C04"]="${RESULTS_DIR}/C04/hap1/C04_hap1.fasta"
    species_genomes["C05"]="${RESULTS_DIR}/C05/C05.fasta"
    species_genomes["C06"]="${RESULTS_DIR}/C06/bxgz.hap1.fa"
    species_genomes["C07"]="${RESULTS_DIR}/C07/genome.fa"
    species_genomes["C08"]="${RESULTS_DIR}/C08/C08_genome.fasta"
    species_genomes["C09"]="${RESULTS_DIR}/C09/genome_v2.fasta"
    species_genomes["C10"]="${RESULTS_DIR}/C10/C10.genome.fasta"
    species_genomes["O01"]="${RESULTS_DIR}/O01/O01.TAIR10.dna.toplevel.fa"
    species_genomes["O02"]="${RESULTS_DIR}/O02/PN40024.T21.fa"
    species_genomes["C11"]="${RESULTS_DIR}/C11/hap1.fa"
    
    # T01和T02
    if [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T01.Chr.final.fa.gz" ]; then
        # 临时解压用于计算
        log_info "临时解压T01基因组..."
        gunzip -c "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T01.Chr.final.fa.gz" > /tmp/T01_temp.fa
        species_genomes["T01"]="/tmp/T01_temp.fa"
    elif [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T01.Chr.final.fa" ]; then
        species_genomes["T01"]="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T01.Chr.final.fa"
    fi
    
    if [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T02.Chr.final.fa.gz" ]; then
        log_info "临时解压T02基因组..."
        gunzip -c "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T02.Chr.final.fa.gz" > /tmp/T02_temp.fa
        species_genomes["T02"]="/tmp/T02_temp.fa"
    elif [ -f "${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T02.Chr.final.fa" ]; then
        species_genomes["T02"]="${RESULTS_DIR}/targets 测序组装物种 T01_T02/基因组/T02.Chr.final.fa"
    fi
    
    # 计算所有物种
    local count=0
    local total=${#species_genomes[@]}
    
    for species in "${!species_genomes[@]}"; do
        count=$((count + 1))
        genome="${species_genomes[$species]}"
        
        if [ -f "$genome" ]; then
            log_step "[$count/$total] 处理: $species"
            calculate_n50 "$genome" "$species"
            echo ""
        else
            log_info "跳过 $species (文件不存在)"
        fi
    done
    
    # 清理临时文件
    rm -f /tmp/T01_temp.fa /tmp/T02_temp.fa
    
    # 生成汇总表
    generate_summary
    
    log_info ""
    log_info "=========================================="
    log_info "N50计算完成"
    log_info "时间: $(date)"
    log_info "结果保存在: $QC_DIR"
    log_info "=========================================="
}

main "$@"

