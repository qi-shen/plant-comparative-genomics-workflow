#!/bin/bash

# 比较基因组分析 - 数据质控脚本
# 创建日期: 2024年12月4日
# 用途: 对所有比较物种进行数据质控

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_DIR="${PROJECT_ROOT}"
RESULTS_DIR="${PROJECT_DIR}/results"
QC_DIR="${PROJECT_DIR}/qc_results"
LOG_FILE="${PROJECT_DIR}/logs/qc_$(date +%Y%m%d).log"

mkdir -p "$QC_DIR" "${PROJECT_DIR}/logs"

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查工具
check_tools() {
    local has_seqkit=0
    local has_busco=0
    
    if command -v seqkit &> /dev/null; then
        has_seqkit=1
    else
        log_warn "seqkit未安装，将使用基本命令进行统计"
        log_warn "建议安装: conda install -c bioconda seqkit (可获得更详细统计)"
    fi
    
    if command -v busco &> /dev/null; then
        has_busco=1
    else
        log_warn "BUSCO未安装，将跳过BUSCO评估"
        log_warn "安装命令: conda install -c bioconda busco"
    fi
    
    echo "$has_seqkit $has_busco"
}

# 统计基因组基本信息
stat_genome() {
    local genome_file=$1
    local species=$2
    local has_seqkit=$3
    
    if [ ! -f "$genome_file" ]; then
        log_error "基因组文件不存在: $genome_file"
        return 1
    fi
    
    log_info "统计基因组: $species"
    
    if [ "${has_seqkit:-0}" -eq 1 ]; then
        # 使用seqkit统计
        seqkit stats "$genome_file" -T > "${QC_DIR}/${species}_genome_stats.txt" 2>&1
        log_info "✓ 统计完成: $species (使用seqkit)"
    else
        # 使用基本命令统计
        local total_length=$(grep -v "^>" "$genome_file" | tr -d '\n' | wc -c)
        local num_seqs=$(grep -c "^>" "$genome_file")
        local num_chr=$(grep "^>" "$genome_file" | grep -i "chr" | wc -l || echo "0")
        
        {
            echo "文件: $genome_file"
            echo "序列数量: $num_seqs"
            echo "染色体数量: $num_chr"
            echo "总长度: $total_length bp"
            echo "$(echo "scale=2; $total_length/1000000" | bc) Mb"
        } > "${QC_DIR}/${species}_genome_stats.txt"
        
        log_info "✓ 统计完成: $species (使用基本命令)"
    fi
}

# 统计注释文件
stat_annotation() {
    local gff_file=$1
    local species=$2
    
    if [ ! -f "$gff_file" ]; then
        log_warn "GFF文件不存在: $gff_file"
        return 1
    fi
    
    log_info "统计注释: $species"
    
    # 统计基因、mRNA、CDS、exon数量
    local num_genes=$(grep -c "gene" "$gff_file" 2>/dev/null || echo "0")
    local num_mrna=$(grep -c "mRNA\|transcript" "$gff_file" 2>/dev/null || echo "0")
    local num_cds=$(grep -c "CDS" "$gff_file" 2>/dev/null || echo "0")
    local num_exon=$(grep -c "exon" "$gff_file" 2>/dev/null || echo "0")
    
    {
        echo "文件: $gff_file"
        echo "基因数量: $num_genes"
        echo "mRNA/转录本数量: $num_mrna"
        echo "CDS数量: $num_cds"
        echo "exon数量: $num_exon"
    } > "${QC_DIR}/${species}_annotation_stats.txt"
    
    log_info "✓ 注释统计完成: $species"
}

# 检查序列文件
check_sequences() {
    local cds_file=$1
    local pep_file=$2
    local species=$3
    
    log_info "检查序列: $species"
    
    local cds_count=0
    local pep_count=0
    
    if [ -f "$cds_file" ]; then
        cds_count=$(grep -c "^>" "$cds_file" 2>/dev/null || echo "0")
    fi
    
    if [ -f "$pep_file" ]; then
        pep_count=$(grep -c "^>" "$pep_file" 2>/dev/null || echo "0")
    fi
    
    {
        echo "CDS文件: $cds_file"
        echo "CDS序列数: $cds_count"
        echo "PEP文件: $pep_file"
        echo "PEP序列数: $pep_count"
    } > "${QC_DIR}/${species}_sequence_check.txt"
    
    log_info "✓ 序列检查完成: $species"
}

# 处理单个物种
process_species() {
    local species_dir=$1
    local species_name=$2
    local genome_file=$3
    local gff_file=$4
    local cds_file=$5
    local pep_file=$6
    local has_seqkit=$7
    
    log_step "[处理物种] $species_name"
    
    # 统计基因组
    if [ -n "$genome_file" ] && [ -f "$species_dir/$genome_file" ]; then
        stat_genome "$species_dir/$genome_file" "$species_name" "$has_seqkit"
    else
        log_warn "基因组文件未找到: $species_dir/$genome_file"
    fi
    
    # 统计注释
    if [ -n "$gff_file" ] && [ -f "$species_dir/$gff_file" ]; then
        stat_annotation "$species_dir/$gff_file" "$species_name"
    else
        log_warn "GFF文件未找到: $species_dir/$gff_file"
    fi
    
    # 检查序列
    check_sequences "$species_dir/$cds_file" "$species_dir/$pep_file" "$species_name"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始数据质控分析"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    read has_seqkit has_busco <<< $(check_tools)
    
    # 定义物种数据
    declare -A species_data
    # 格式: 物种名:基因组文件:GFF文件:CDS文件:PEP文件
    
    # C01
    species_data["C01"]="C01:hs.chrom.genome.final.fa:hs.chrom.genome.gff:C01.cds.fa:C01.pep.fa"
    
    # C02
    species_data["C02"]="C02:C02_genome.fasta:C02.gff3:cds.fa:protein.fa"
    
    # C03
    species_data["C03"]="C03:genome.fa:genes.gff3:cds.fa:protein.fa"
    
    # C05
    species_data["C05"]="C05:C05.fasta:C05.gff3:C05-cds.fasta:C05-prot.fasta"
    
    # C07
    species_data["C07"]="C07:genome.fa:genes.gff3:cds.fa:protein.fa"
    
    # C04
    species_data["C04"]="C04/hap1:C04_hap1.fasta:C04_hap1.gff.gff3:C04_hap1.cds.fa.fasta:C04_hap1.proteins.fa.fasta"
    
    # C08
    species_data["C08"]="C08:C08_genome.fasta:C08.gff3:C08.cds.fa:C08.pep.fa"
    
    # C09
    species_data["C09"]="C09:genome_v2.fasta:genome.gff3:cds.fasta:protein.fasta"
    
    # C10
    species_data["C10"]="C10:C10.genome.fasta:C10.gff:C10.CDS.fasta:C10.Protein.faa"
    
    # O01
    species_data["O01"]="O01:O01.TAIR10.dna.toplevel.fa:O01.TAIR10.61.gff3:O01.cds.fa:O01.pep.fa"
    
    # O02
    species_data["O02"]="O02:PN40024.T21.fa:PN40024.gff:O02.cds.fa:O02.pep.fa"
    
    # C06
    species_data["C06"]="C06:bxgz.hap1.fa:bxgz.hap1.evm_out.gff3:C06_hap1.cds.fa:C06_hap1.pep.fa"
    
    # C11
    species_data["C11"]="C11:hap1.fa:hap1.gff3:hap1.CDS.fa:C11_prot.fa"
    
    # 处理所有物种
    local count=0
    local total=${#species_data[@]}
    
    for species_name in "${!species_data[@]}"; do
        count=$((count + 1))
        log_step "[$count/$total] 处理物种: $species_name"
        
        IFS=':' read -r dir genome gff cds pep <<< "${species_data[$species_name]}"
        process_species "${RESULTS_DIR}/$dir" "$species_name" "$genome" "$gff" "$cds" "$pep" "$has_seqkit"
        
        echo ""
    done
    
    # 生成汇总报告
    log_info ""
    log_info "生成汇总报告..."
    generate_summary_report
    
    log_info ""
    log_info "=========================================="
    log_info "数据质控分析完成"
    log_info "时间: $(date)"
    log_info "结果保存在: $QC_DIR"
    log_info "=========================================="
}

# 生成汇总报告
generate_summary_report() {
    local report_file="${QC_DIR}/QC_summary_report.txt"
    
    {
        echo "=========================================="
        echo "数据质控汇总报告"
        echo "生成时间: $(date)"
        echo "=========================================="
        echo ""
        echo "一、基因组统计"
        echo "----------------------------------------"
        
        for stat_file in "${QC_DIR}"/*_genome_stats.txt; do
            if [ -f "$stat_file" ]; then
                species=$(basename "$stat_file" _genome_stats.txt)
                echo ""
                echo "【$species】"
                cat "$stat_file"
            fi
        done
        
        echo ""
        echo "二、注释统计"
        echo "----------------------------------------"
        
        for stat_file in "${QC_DIR}"/*_annotation_stats.txt; do
            if [ -f "$stat_file" ]; then
                species=$(basename "$stat_file" _annotation_stats.txt)
                echo ""
                echo "【$species】"
                cat "$stat_file"
            fi
        done
        
        echo ""
        echo "三、序列文件检查"
        echo "----------------------------------------"
        
        for check_file in "${QC_DIR}"/*_sequence_check.txt; do
            if [ -f "$check_file" ]; then
                species=$(basename "$check_file" _sequence_check.txt)
                echo ""
                echo "【$species】"
                cat "$check_file"
            fi
        done
        
        echo ""
        echo "=========================================="
    } > "$report_file"
    
    log_info "✓ 汇总报告已生成: $report_file"
}

# 运行主函数
main "$@"

