#!/bin/bash

# 并行BLAST比对脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
DATABASE_DIR="${PROJECT_DIR}/databases"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_DIR="${PROJECT_DIR}/logs/blast"
THREADS=64  # BLAST使用的线程数

mkdir -p "$LOG_DIR"

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

# 检查BLAST工具
check_blast() {
    if command -v blastp &> /dev/null; then
        BLASTP="blastp"
    elif [ -f "${PROJECT_ROOT}" ]; then
        BLASTP="${PROJECT_ROOT}"
    else
        log_error "blastp未找到"
        return 1
    fi
    
    log_info "使用blastp: $BLASTP"
}

# 运行BLAST比对
run_blast() {
    local species=$1
    local db_name=$2
    local db_path="${DATABASE_DIR}/${db_name}"
    
    log_step "========== BLAST比对: $species vs $db_name =========="
    
    local pep_file="${ANNOTATION_DIR}/${species}/functional/${species}.pep.fa"
    local output_file="${ANNOTATION_DIR}/${species}/functional/${species}_blast_${db_name}.tab"
    
    if [ ! -f "$pep_file" ]; then
        log_error "蛋白质序列文件不存在: $pep_file"
        return 1
    fi
    
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        log_warn "BLAST结果已存在，跳过: $output_file"
        return 0
    fi
    
    # 检查数据库
    if [ ! -f "${db_path}.phr" ] && [ ! -f "${db_path}.00.phr" ]; then
        log_error "数据库不存在: $db_path"
        log_warn "请先运行 scripts/prepare_blast_databases.sh 准备数据库"
        return 1
    fi
    
    log_info "查询文件: $pep_file"
    log_info "数据库: $db_path"
    log_info "输出文件: $output_file"
    log_info "线程数: $THREADS"
    
    log_info "开始BLAST比对（这可能需要数小时）..."
    
    "$BLASTP" \
        -query "$pep_file" \
        -db "$db_path" \
        -out "$output_file" \
        -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" \
        -num_threads "$THREADS" \
        -evalue 1e-5 \
        -max_target_seqs 5 \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
        local hit_count=$(wc -l < "$output_file")
        local file_size=$(du -h "$output_file" | cut -f1)
        log_info "✅ BLAST比对完成: $output_file"
        log_info "   比对结果数: $hit_count"
        log_info "   文件大小: $file_size"
        return 0
    else
        log_error "BLAST比对失败"
        return 1
    fi
}

# 解析BLAST结果，生成注释文件
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
        log_warn "注释文件已存在，跳过: $annotation_file"
        return 0
    fi
    
    log_info "解析BLAST结果..."
    
    # 提取最佳比对结果（每个基因只保留evalue最小的）
    awk 'BEGIN {FS="\t"; OFS="\t"} {
        gene = $1
        if (!best[gene] || $11 < evalue[gene]) {
            best[gene] = $2
            evalue[gene] = $11
            bitscore[gene] = $12
            pident[gene] = $3
            qcov[gene] = ($4 / qlen[gene]) * 100
            stitle[gene] = $13
            qlen[gene] = $7 - $6 + 1
        }
    } END {
        for (gene in best) {
            print gene, best[gene], evalue[gene], bitscore[gene], pident[gene], qcov[gene], stitle[gene]
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
    LOG_FILE="${LOG_DIR}/blast_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "=========================================="
    log_info "并行BLAST比对"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    check_blast
    
    # 定义要运行的数据库
    databases=()
    
    if [ -f "${DATABASE_DIR}/swissprot.phr" ] || [ -f "${DATABASE_DIR}/swissprot.00.phr" ]; then
        databases+=("swissprot")
    fi
    
    if [ -f "${DATABASE_DIR}/nr.phr" ] || [ -f "${DATABASE_DIR}/nr.00.phr" ]; then
        databases+=("nr")
    fi
    
    if [ ${#databases[@]} -eq 0 ]; then
        log_error "没有可用的BLAST数据库"
        log_warn "请先运行 scripts/prepare_blast_databases.sh 准备数据库"
        exit 1
    fi
    
    log_info "可用数据库: ${databases[@]}"
    
    # 对每个物种和每个数据库运行BLAST（并行运行不同物种）
    for db in "${databases[@]}"; do
        # 后台并行运行BH和CK
        for species in T01 T02; do
            run_blast "$species" "$db" &
        done
        
        # 等待所有物种的BLAST比对完成
        wait
        
        # 解析结果
        for species in T01 T02; do
            parse_blast_results "$species" "$db"
            echo ""
        done
    done
    
    log_info ""
    log_info "=========================================="
    log_info "BLAST比对完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

