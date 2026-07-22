#!/bin/bash

# 整合所有功能注释结果

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/integrate_annotations_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${PROJECT_DIR}/logs"

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

# 整合单个物种的注释
integrate_species() {
    local species=$1
    
    log_step "========== 整合注释: $species =========="
    
    local func_dir="${ANNOTATION_DIR}/${species}/functional"
    local output_file="${func_dir}/${species}_functional_annotation.txt"
    
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        log_warn "整合注释文件已存在，跳过: $output_file"
        return 0
    fi
    
    log_info "整合所有注释结果..."
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    # 1. 收集BLAST注释
    local blast_swissprot="${func_dir}/${species}_blast_swissprot_annotation.txt"
    local blast_nr="${func_dir}/${species}_blast_nr_annotation.txt"
    
    # 2. 收集GO和KEGG注释（从eggNOG或InterProScan）
    local go_file="${func_dir}/${species}_go_annotation.txt"
    local kegg_file="${func_dir}/${species}_kegg_annotation.txt"
    
    # 3. 创建基因列表（从蛋白质序列文件）
    local pep_file="${func_dir}/${species}.pep.fa"
    if [ ! -f "$pep_file" ]; then
        log_error "蛋白质序列文件不存在: $pep_file"
        return 1
    fi
    
    # 提取所有基因ID
    grep "^>" "$pep_file" | sed 's/^>//' | cut -d' ' -f1 | sort > "${temp_dir}/genes.txt"
    
    # 4. 创建注释数据库（使用关联数组）
    log_info "构建注释数据库..."
    
    # 读取BLAST SwissProt注释（从原始BLAST结果或注释文件）
    if [ -f "$blast_swissprot" ] && [ -s "$blast_swissprot" ]; then
        # 如果是注释文件（已解析），直接使用
        awk -F'\t' '{print $1"\t"$2"\t"$7}' "$blast_swissprot" > "${temp_dir}/blast_swissprot.txt" 2>/dev/null || \
        # 如果是原始BLAST结果，提取最佳比对
        awk -F'\t' 'BEGIN {OFS="\t"} {gene = $1; if (!(gene in evalue) || $11 < evalue[gene]) {best_id[gene] = $2; evalue[gene] = $11; desc[gene] = $13}} END {for (g in best_id) print g, best_id[g], desc[g]}' "$blast_swissprot" > "${temp_dir}/blast_swissprot.txt"
    fi
    
    # 读取BLAST Nr注释
    if [ -f "$blast_nr" ] && [ -s "$blast_nr" ]; then
        awk -F'\t' '{print $1"\t"$2"\t"$7}' "$blast_nr" > "${temp_dir}/blast_nr.txt" 2>/dev/null || \
        awk -F'\t' 'BEGIN {OFS="\t"} {gene = $1; if (!(gene in evalue) || $11 < evalue[gene]) {best_id[gene] = $2; evalue[gene] = $11; desc[gene] = $13}} END {for (g in best_id) print g, best_id[g], desc[g]}' "$blast_nr" > "${temp_dir}/blast_nr.txt"
    fi
    
    # 读取GO注释（如果存在，从eggNOG或其他来源）
    if [ -f "$go_file" ] && [ -s "$go_file" ]; then
        awk -F'\t' '{gos[$1] = (gos[$1] == "" ? $2 : gos[$1] "," $2)} END {for (g in gos) print g"\t"gos[g]}' "$go_file" > "${temp_dir}/go.txt"
    fi
    
    # 读取KEGG注释（如果存在，从eggNOG或其他来源）
    if [ -f "$kegg_file" ] && [ -s "$kegg_file" ]; then
        awk -F'\t' '{keggs[$1] = (keggs[$1] == "" ? $2 : keggs[$1] "," $2)} END {for (g in keggs) print g"\t"keggs[g]}' "$kegg_file" > "${temp_dir}/kegg.txt"
    fi
    
    # 5. 整合所有注释
    log_info "生成综合注释表..."
    
    # 创建输出文件头
    echo -e "Gene_ID\tSwissProt_ID\tSwissProt_Description\tNr_ID\tNr_Description\tGO_Terms\tKEGG_Terms" > "$output_file"
    
    # 使用awk整合所有注释
    awk -F'\t' '
    BEGIN {
        OFS="\t"
        # 读取SwissProt注释
        while ((getline < "'"${temp_dir}/blast_swissprot.txt"'") > 0) {
            swissprot_id[$1] = $2
            swissprot_desc[$1] = $3
        }
        close("'"${temp_dir}/blast_swissprot.txt"'")
        
        # 读取Nr注释
        while ((getline < "'"${temp_dir}/blast_nr.txt"'") > 0) {
            nr_id[$1] = $2
            nr_desc[$1] = $3
        }
        close("'"${temp_dir}/blast_nr.txt"'")
        
        # 读取GO注释
        while ((getline < "'"${temp_dir}/go.txt"'") > 0) {
            go[$1] = $2
        }
        close("'"${temp_dir}/go.txt"'")
        
        # 读取KEGG注释
        while ((getline < "'"${temp_dir}/kegg.txt"'") > 0) {
            kegg[$1] = $2
        }
        close("'"${temp_dir}/kegg.txt"'")
    }
    {
        gene = $1
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", 
            gene,
            (gene in swissprot_id ? swissprot_id[gene] : "."),
            (gene in swissprot_desc ? swissprot_desc[gene] : "."),
            (gene in nr_id ? nr_id[gene] : "."),
            (gene in nr_desc ? nr_desc[gene] : "."),
            (gene in go ? go[gene] : "."),
            (gene in kegg ? kegg[gene] : ".")
    }
    ' "${temp_dir}/genes.txt" >> "$output_file"
    
    # 清理临时目录
    rm -rf "$temp_dir"
    
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        local line_count=$(wc -l < "$output_file")
        local file_size=$(du -h "$output_file" | cut -f1)
        log_info "✅ 整合注释完成: $output_file"
        log_info "   基因数: $((line_count - 1))"
        log_info "   文件大小: $file_size"
        return 0
    else
        log_error "整合注释失败"
        return 1
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "整合功能注释结果"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 整合BH和CK
    integrate_species "BH"
    echo ""
    integrate_species "CK"
    
    log_info ""
    log_info "=========================================="
    log_info "注释整合完成"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    # 显示结果
    log_info ""
    log_info "【整合结果】"
    for species in BH CK; do
        local output_file="${ANNOTATION_DIR}/${species}/functional/${species}_functional_annotation.txt"
        if [ -f "$output_file" ]; then
            local size=$(du -h "$output_file" | cut -f1)
            local genes=$(($(wc -l < "$output_file") - 1))
            log_info "  $species: $output_file ($size, $genes 个基因)"
        fi
    done
}

main "$@"

