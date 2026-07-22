#!/bin/bash

# 仅解析BLAST结果（不重新运行BLAST）

set -e

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/parse_blast_results_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${PROJECT_DIR}/logs"

log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo "[STEP] $1" | tee -a "$LOG_FILE"
}

# 解析BLAST结果
parse_blast_results() {
    local species=$1
    local db_name=$2
    
    log_step "解析BLAST结果: $species vs $db_name"
    
    local blast_file="${ANNOTATION_DIR}/${species}/functional/${species}_blast_${db_name}.tab"
    local annotation_file="${ANNOTATION_DIR}/${species}/functional/${species}_blast_${db_name}_annotation.txt"
    
    if [ ! -f "$blast_file" ] || [ ! -s "$blast_file" ]; then
        log_error "BLAST结果文件不存在或为空: $blast_file"
        return 1
    fi
    
    if [ -f "$annotation_file" ] && [ -s "$annotation_file" ]; then
        log_info "注释文件已存在，跳过: $annotation_file"
        return 0
    fi
    
    log_info "解析BLAST结果..."
    
    # 提取最佳比对结果（每个基因只保留evalue最小的）
    awk -F'\t' 'BEGIN {OFS="\t"} {
        gene = $1
        if (!(gene in evalue) || $11 < evalue[gene]) {
            best_id[gene] = $2
            evalue[gene] = $11
            bitscore[gene] = $12
            pident[gene] = $3
            qlen[gene] = $7 - $6 + 1
            qcov[gene] = ($4 / qlen[gene]) * 100
            desc[gene] = $13
        }
    } END {
        for (gene in best_id) {
            print gene, best_id[gene], evalue[gene], bitscore[gene], pident[gene], qcov[gene], desc[gene]
        }
    }' "$blast_file" | sort > "$annotation_file"
    
    if [ -f "$annotation_file" ] && [ -s "$annotation_file" ]; then
        local annot_count=$(wc -l < "$annotation_file")
        log_info "✅ 注释文件生成: $annotation_file ($annot_count 个基因)"
        return 0
    else
        log_error "注释文件生成失败"
        return 1
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "解析BLAST结果"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 解析T01和T02的SwissProt结果
    parse_blast_results "T01" "swissprot"
    echo ""
    parse_blast_results "T02" "swissprot"
    
    log_info ""
    log_info "=========================================="
    log_info "BLAST结果解析完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"
