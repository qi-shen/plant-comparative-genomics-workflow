#!/bin/bash

# GeMoMa同源预测完整脚本
# 使用三个参考物种进行同源预测

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
LOG_FILE="${PROJECT_DIR}/logs/gemoma_$(date +%Y%m%d_%H%M%S).log"
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
    
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        return 1
    fi
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/gemoma"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    log_info "使用掩蔽基因组: $masked_genome"
    log_info "工作目录: $work_dir"
    
    # 参考物种配置
    declare -A ref_gffs
    declare -A ref_peps
    declare -A ref_genomes
    
    ref_gffs["hongsha"]="${RESULTS_DIR}/C01/hs.chrom.genome.gff"
    ref_peps["hongsha"]="${RESULTS_DIR}/C01/C01.pep.fa"
    
    ref_gffs["ganmeng"]="${RESULTS_DIR}/C02/tau.gff3"
    ref_peps["ganmeng"]="${RESULTS_DIR}/C02/protein.fa"
    
    ref_gffs["C03"]="${RESULTS_DIR}/C03/genes.gff3"
    ref_peps["C03"]="${RESULTS_DIR}/C03/protein.fa"
    
    local gemoma_predictions=()
    
    for ref_id in hongsha ganmeng C03; do
        local ref_gff="${ref_gffs[$ref_id]}"
        local ref_pep="${ref_peps[$ref_id]}"
        
        if [ ! -f "$ref_gff" ] || [ ! -f "$ref_pep" ]; then
            log_warn "参考物种文件不存在: $ref_id，跳过"
            continue
        fi
        
        log_step "处理参考物种: $ref_id"
        log_info "  GFF: $ref_gff"
        log_info "  PEP: $ref_pep"
        
        local ref_dir="${work_dir}/${ref_id}"
        mkdir -p "$ref_dir"
        cd "$ref_dir"
        
        # 步骤1: tblastn比对
        local tblastn_output="${ref_id}_tblastn.txt"
        if [ -f "$tblastn_output" ] && [ -s "$tblastn_output" ]; then
            log_info "  tblastn输出已存在，跳过比对"
        else
            log_info "  运行tblastn比对..."
            tblastn -query "$ref_pep" \
                    -db "$masked_genome" \
                    -outfmt "6 std sallseqid" \
                    -out "$tblastn_output" \
                    -num_threads "$THREADS" \
                    -evalue 1e-5 \
                    -max_target_seqs 10 2>&1 | tee -a "$LOG_FILE"
            
            if [ $? -ne 0 ] || [ ! -s "$tblastn_output" ]; then
                log_error "  tblastn失败: $ref_id"
                cd "$work_dir"
                continue
            fi
            log_info "  ✅ tblastn完成: $(wc -l < $tblastn_output) 条比对"
        fi
        
        # 步骤2: GeMoMa预测
        local gemoma_output="${ref_dir}/${ref_id}_gemoma.gff"
        if [ -f "$gemoma_output" ] && [ -s "$gemoma_output" ]; then
            log_info "  GeMoMa输出已存在，跳过预测"
        else
            log_info "  运行GeMoMa预测..."
            
            # 创建输出目录
            local output_dir="${ref_dir}/output"
            mkdir -p "$output_dir"
            cd "$ref_dir"
            
            # 使用正确的GeMoMa命令格式
            # s: search results (tblastn输出)
            # t: target genome
            # a: assignment (GFF文件)
            # c: CDS parts (蛋白质序列文件)
            GeMoMa GeMoMa \
                s="$tblastn_output" \
                t="$masked_genome" \
                a="$ref_gff" \
                c="$ref_pep" \
                outdir="$output_dir" 2>&1 | tee -a "$LOG_FILE" || {
                    
                    log_error "  GeMoMa预测失败: $ref_id"
                    cd "$work_dir"
                    continue
                }
            
            # 查找输出文件
            if [ -f "${output_dir}/predicted_annotation.gff" ]; then
                cp "${output_dir}/predicted_annotation.gff" "$gemoma_output"
                log_info "  ✅ GeMoMa预测完成"
            elif [ -f "${output_dir}/final_annotation.gff" ]; then
                cp "${output_dir}/final_annotation.gff" "$gemoma_output"
                log_info "  ✅ GeMoMa预测完成"
            elif [ -f "${output_dir}/${ref_id}_predicted.gff" ]; then
                cp "${output_dir}/${ref_id}_predicted.gff" "$gemoma_output"
                log_info "  ✅ GeMoMa预测完成"
            else
                log_warn "  GeMoMa输出文件不存在，检查输出目录..."
                ls -la "${output_dir}/" 2>/dev/null | tee -a "$LOG_FILE"
                # 尝试查找任何GFF文件
                local found_gff=$(find "${output_dir}" -name "*.gff" -o -name "*.gff3" | head -1)
                if [ -n "$found_gff" ] && [ -f "$found_gff" ]; then
                    cp "$found_gff" "$gemoma_output"
                    log_info "  ✅ 找到并复制GFF文件: $found_gff"
                else
                    log_error "  GeMoMa预测失败: 未找到输出文件"
                    cd "$work_dir"
                    continue
                fi
            fi
        fi
        
        if [ -f "$gemoma_output" ] && [ -s "$gemoma_output" ]; then
            gemoma_predictions+=("$gemoma_output")
            log_info "  ✅ 预测文件: $gemoma_output ($(du -h $gemoma_output | cut -f1))"
        fi
        
        cd "$work_dir"
    done
    
    # 合并所有GeMoMa预测结果
    if [ ${#gemoma_predictions[@]} -gt 0 ]; then
        log_step "合并GeMoMa预测结果..."
        local merged_gff="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
        
        # 合并所有预测结果
        cat "${gemoma_predictions[@]}" > "$merged_gff"
        
        if [ -f "$merged_gff" ] && [ -s "$merged_gff" ]; then
            log_info "✅ 合并完成: $merged_gff"
            log_info "   文件大小: $(du -h $merged_gff | cut -f1)"
            log_info "   行数: $(wc -l < $merged_gff)"
        else
            log_error "合并失败"
        fi
    else
        log_warn "没有成功的GeMoMa预测结果"
    fi
    
    log_info "✅ GeMoMa预测完成: $species"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "GeMoMa同源预测"
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
        log_error "tblastn未安装"
        exit 1
    fi
    
    # 处理BH和CK
    process_species "T01"
    
    echo ""
    
    process_species "T02"
    
    log_info ""
    log_info "=========================================="
    log_info "GeMoMa同源预测完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

