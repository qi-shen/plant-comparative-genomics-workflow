#!/bin/bash

# 运行GeMoMa同源预测脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
RESULTS_DIR="${PROJECT_DIR}/results"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/gemoma_$(date +%Y%m%d).log"
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

# 处理单个物种
process_species() {
    local species=$1
    
    log_step "========== GeMoMa同源预测: $species =========="
    
    # 检查掩蔽基因组
    local masked_genome1="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    local masked_genome2="${ANNOTATION_DIR}/${species}/repeat/${species}.Chr.final.fa.masked"
    
    local target_genome=""
    if [ -f "$masked_genome1" ]; then
        target_genome="$masked_genome1"
    elif [ -f "$masked_genome2" ]; then
        target_genome="$masked_genome2"
    else
        log_error "掩蔽基因组不存在"
        return 1
    fi
    
    log_info "使用掩蔽基因组: $target_genome"
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/gemoma"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # 参考物种列表
    local ref_species=("C01" "C02" "C03")
    local ref_gffs=()
    local ref_peps=()
    
    ref_gffs+=("${RESULTS_DIR}/C01/hs.chrom.genome.gff")
    ref_peps+=("${RESULTS_DIR}/C01/C01.pep.fa")
    
    ref_gffs+=("${RESULTS_DIR}/C02/C02.gff3")
    ref_peps+=("${RESULTS_DIR}/C02/protein.fa")
    
    ref_gffs+=("${RESULTS_DIR}/C03/genes.gff3")
    ref_peps+=("${RESULTS_DIR}/C03/protein.fa")
    
    # 检查GeMoMa
    if ! command -v GeMoMa &> /dev/null; then
        log_error "GeMoMa未安装"
        return 1
    fi
    
    log_info "参考物种: ${ref_species[@]}"
    
    # 为每个参考物种运行GeMoMa
    local gemoma_predictions=()
    for i in "${!ref_gffs[@]}"; do
        local ref_gff="${ref_gffs[$i]}"
        local ref_pep="${ref_peps[$i]}"
        local ref_name="${ref_species[$i]}"
        local ref_id=$(echo "$ref_name" | tr -d ' ')
        
        if [ ! -f "$ref_gff" ] || [ ! -f "$ref_pep" ]; then
            log_warn "参考物种文件不存在: $ref_name，跳过"
            continue
        fi
        
        log_step "处理参考物种: $ref_name"
        log_info "  GFF: $ref_gff"
        log_info "  PEP: $ref_pep"
        
        local ref_dir="${work_dir}/${ref_id}"
        mkdir -p "$ref_dir"
        cd "$ref_dir"
        
        # GeMoMa步骤1: 提取CDS序列
        log_info "步骤1: 提取CDS序列..."
        GeMoMa GAF "$ref_gff" > "${ref_id}.gaf" 2>&1 || {
            log_warn "GAF提取失败，尝试直接使用GFF"
        }
        
        # GeMoMa步骤2: tblastn比对
        log_info "步骤2: tblastn比对..."
        tblastn -query "$ref_pep" \
                -db "$target_genome" \
                -outfmt "6 std sall" \
                -out "${ref_id}_tblastn.txt" \
                -num_threads "$THREADS" \
                -evalue 1e-5 || {
            log_error "tblastn失败"
            continue
        }
        
        # GeMoMa步骤3: GeMoMa预测
        log_info "步骤3: GeMoMa预测..."
        GeMoMa tblastn "${ref_id}_tblastn.txt" \
                "$ref_gff" \
                "$target_genome" \
                -outdir "${ref_id}_prediction" \
                -ID "${ref_id}" || {
            log_warn "GeMoMa预测失败，尝试简化命令"
            # 简化版本
            GeMoMa tblastn "${ref_id}_tblastn.txt" \
                    "$ref_gff" \
                    "$target_genome" \
                    -outdir "${ref_id}_prediction" || {
                log_error "GeMoMa预测失败"
                continue
            }
        }
        
        # 检查输出
        if [ -f "${ref_id}_prediction/predicted_annotation.gff" ]; then
            log_info "✓ GeMoMa预测完成: $ref_name"
            gemoma_predictions+=("${ref_dir}/${ref_id}_prediction/predicted_annotation.gff")
        else
            log_warn "GeMoMa输出文件不存在"
        fi
        
        cd "$work_dir"
    done
    
    # 合并所有GeMoMa预测结果
    if [ ${#gemoma_predictions[@]} -gt 0 ]; then
        log_step "合并GeMoMa预测结果..."
        local merged_gff="${work_dir}/../${species}_gemoma_merged.gff3"
        cat "${gemoma_predictions[@]}" > "$merged_gff" 2>/dev/null || {
            log_warn "合并失败，使用第一个预测结果"
            cp "${gemoma_predictions[0]}" "$merged_gff"
        }
        log_info "✓ 合并完成: $merged_gff"
    else
        log_warn "没有成功的GeMoMa预测结果"
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始GeMoMa同源预测"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v GeMoMa &> /dev/null; then
        log_error "GeMoMa未安装"
        exit 1
    fi
    
    if ! command -v tblastn &> /dev/null; then
        log_error "tblastn未安装（需要BLAST+）"
        exit 1
    fi
    
    # 为T01和T02创建tblastn数据库
    log_step "准备tblastn数据库..."
    for species in T01 T02; do
        local masked_genome1="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
        local masked_genome2="${ANNOTATION_DIR}/${species}/repeat/${species}.Chr.final.fa.masked"
        
        local target_genome=""
        if [ -f "$masked_genome1" ]; then
            target_genome="$masked_genome1"
        elif [ -f "$masked_genome2" ]; then
            target_genome="$masked_genome2"
        else
            log_warn "掩蔽基因组不存在: $species"
            continue
        fi
        
        # 检查数据库是否已存在
        if [ ! -f "${target_genome}.nhr" ]; then
            log_info "创建tblastn数据库: $species"
            makeblastdb -in "$target_genome" -dbtype nucl -out "${target_genome}" || {
                log_error "创建数据库失败: $species"
            }
        else
            log_info "数据库已存在: $species"
        fi
    done
    
    # T01
    process_species "T01"
    
    echo ""
    
    # T02
    process_species "T02"
    
    log_info ""
    log_info "=========================================="
    log_info "GeMoMa同源预测完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

