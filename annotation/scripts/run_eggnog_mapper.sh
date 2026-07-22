#!/bin/bash

# eggNOG-mapper功能注释脚本（用于KEGG和GO注释）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_DIR="${PROJECT_DIR}/logs/eggnog"
THREADS=32

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

# 检查eggNOG-mapper
check_eggnog() {
    if command -v emapper.py &> /dev/null; then
        EGGNOG="emapper.py"
        log_info "使用eggNOG-mapper: $EGGNOG"
        return 0
    elif [ -f "${PROJECT_ROOT}" ]; then
        EGGNOG="${PROJECT_ROOT}"
        log_info "使用eggNOG-mapper: $EGGNOG"
        return 0
    else
        log_error "eggNOG-mapper未找到"
        log_warn "请安装eggNOG-mapper:"
        echo "  conda install -c bioconda eggnog-mapper"
        return 1
    fi
}

# 运行eggNOG-mapper
run_eggnog() {
    local species=$1
    
    log_step "========== eggNOG-mapper: $species =========="
    
    local pep_file="${ANNOTATION_DIR}/${species}/functional/${species}.pep.fa"
    local output_dir="${ANNOTATION_DIR}/${species}/functional/eggnog"
    local output_file="${ANNOTATION_DIR}/${species}/functional/${species}_eggnog_annotation.txt"
    
    mkdir -p "$output_dir"
    
    if [ ! -f "$pep_file" ]; then
        log_error "蛋白质序列文件不存在: $pep_file"
        return 1
    fi
    
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        log_warn "eggNOG-mapper结果已存在，跳过: $output_file"
        return 0
    fi
    
    log_info "输入文件: $pep_file"
    log_info "输出目录: $output_dir"
    log_info "线程数: $THREADS"
    
    log_info "开始eggNOG-mapper注释（这可能需要数小时）..."
    
    # 检查本地数据库
    local eggnog_data_dir=""
    if [ -d "${PROJECT_ROOT}" ]; then
        eggnog_data_dir="${PROJECT_ROOT}"
        log_info "使用本地数据库目录: $eggnog_data_dir"
    elif [ -n "$EGGNOG_DATA_DIR" ]; then
        eggnog_data_dir="$EGGNOG_DATA_DIR"
        log_info "使用环境变量指定的数据库目录: $eggnog_data_dir"
    else
        log_warn "未找到本地数据库目录，将尝试使用默认路径或在线模式"
    fi
    
    cd "$output_dir"
    
    # 构建命令
    local cmd=(
        "$EGGNOG"
        -i "$pep_file"
        -o "${species}_eggnog"
        --cpu "$THREADS"
        -m diamond
        --tax_scope viridiplantae
    )
    
    # 如果找到数据库目录，添加--data_dir参数
    if [ -n "$eggnog_data_dir" ]; then
        cmd+=(--data_dir "$eggnog_data_dir")
    fi
    
    log_info "执行命令: ${cmd[*]}"
    "${cmd[@]}" >> "$LOG_FILE" 2>&1
    
    if [ -f "${output_dir}/${species}_eggnog.emapper.annotations" ]; then
        cp "${output_dir}/${species}_eggnog.emapper.annotations" "$output_file"
        local line_count=$(wc -l < "$output_file")
        local file_size=$(du -h "$output_file" | cut -f1)
        log_info "✅ eggNOG-mapper完成: $output_file"
        log_info "   结果行数: $line_count"
        log_info "   文件大小: $file_size"
        return 0
    else
        log_error "eggNOG-mapper失败"
        return 1
    fi
}

# 提取GO和KEGG注释
extract_go_kegg() {
    local species=$1
    
    log_step "从eggNOG结果提取GO和KEGG注释: $species"
    
    local eggnog_file="${ANNOTATION_DIR}/${species}/functional/${species}_eggnog_annotation.txt"
    local go_file="${ANNOTATION_DIR}/${species}/functional/${species}_go_annotation.txt"
    local kegg_file="${ANNOTATION_DIR}/${species}/functional/${species}_kegg_annotation.txt"
    
    if [ ! -f "$eggnog_file" ] || [ ! -s "$eggnog_file" ]; then
        log_warn "eggNOG结果文件不存在，跳过GO/KEGG提取"
        return 1
    fi
    
    # 提取GO注释（第13列是GO terms）
    log_info "提取GO注释..."
    awk -F'\t' 'BEGIN {OFS="\t"} NR>1 && $13!="" {
        split($13, gos, ",")
        for (i in gos) {
            gsub(/ /, "", gos[i])
            if (gos[i] != "") print $1, gos[i]
        }
    }' "$eggnog_file" > "$go_file"
    
    # 提取KEGG注释（第12列是KEGG terms）
    log_info "提取KEGG注释..."
    awk -F'\t' 'BEGIN {OFS="\t"} NR>1 && $12!="" {
        split($12, keggs, ",")
        for (i in keggs) {
            gsub(/ /, "", keggs[i])
            if (keggs[i] != "") print $1, keggs[i]
        }
    }' "$eggnog_file" > "$kegg_file"
    
    if [ -f "$go_file" ] && [ -s "$go_file" ]; then
        local go_count=$(wc -l < "$go_file")
        log_info "✅ GO注释提取完成: $go_file ($go_count 条记录)"
    fi
    
    if [ -f "$kegg_file" ] && [ -s "$kegg_file" ]; then
        local kegg_count=$(wc -l < "$kegg_file")
        log_info "✅ KEGG注释提取完成: $kegg_file ($kegg_count 条记录)"
    fi
}

# 主函数
main() {
    LOG_FILE="${LOG_DIR}/eggnog_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "=========================================="
    log_info "eggNOG-mapper功能注释"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    if ! check_eggnog; then
        log_error "eggNOG-mapper未安装，跳过此步骤"
        exit 1
    fi
    
    # 处理T01和T02
    for species in T01 T02; do
        run_eggnog "$species"
        echo ""
        extract_go_kegg "$species"
        echo ""
    done
    
    log_info ""
    log_info "=========================================="
    log_info "eggNOG-mapper注释完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

