#!/bin/bash

# Exonerate超并行优化脚本
# 将蛋白质序列分割成小块，大规模并行处理

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
LOG_DIR="${PROJECT_DIR}/logs/exonerate_ultra"
MAX_PARALLEL_JOBS=20  # 增加到20个并行任务，充分利用128核CPU
CHUNK_SIZE=500  # 每个chunk包含500条蛋白质序列

mkdir -p "$ANNOTATION_DIR" "$LOG_DIR"

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

# 分割蛋白质序列文件
split_fasta() {
    local input_fasta=$1
    local output_dir=$2
    local chunk_size=$3
    
    mkdir -p "$output_dir"
    
    # 使用awk分割FASTA文件
    awk -v size="$chunk_size" -v outdir="$output_dir" '
    BEGIN {
        n = 0
        file_num = 1
        outfile = sprintf("%s/chunk_%04d.fa", outdir, file_num)
    }
    /^>/ {
        if (n >= size) {
            close(outfile)
            file_num++
            outfile = sprintf("%s/chunk_%04d.fa", outdir, file_num)
            n = 0
        }
        n++
    }
    { print > outfile }
    END { close(outfile) }
    ' "$input_fasta"
    
    local chunk_count=$(ls -1 "$output_dir"/chunk_*.fa 2>/dev/null | wc -l)
    echo "$chunk_count"
}

# 处理单个chunk
process_chunk() {
    local species=$1
    local ref_id=$2
    local chunk_file=$3
    local chunk_id=$4
    local masked_genome=$5
    local output_dir=$6
    local log_file=$7
    
    local chunk_output="${output_dir}/chunk_${chunk_id}.gff"
    
    if [ -f "$chunk_output" ] && [ -s "$chunk_output" ]; then
        return 0
    fi
    
    exonerate \
        --model protein2genome \
        --query "$chunk_file" \
        --target "$masked_genome" \
        --percent 70 \
        --maxintron 15000 \
        --showalignment FALSE \
        --showvulgar FALSE \
        --ryo "GFF\n" \
        --bestn 1 \
        > "${chunk_output}.tmp" 2>> "$log_file"
    
    if [ $? -eq 0 ]; then
        grep -v "^#" "${chunk_output}.tmp" | \
        grep -v "^Command line" | \
        grep -v "^Hostname" | \
        awk '$3 == "gene" || $3 == "exon" || $3 == "cds"' > "$chunk_output"
        rm -f "${chunk_output}.tmp"
        
        if [ -s "$chunk_output" ]; then
            return 0
        fi
    fi
    
    return 1
}

# 处理单个参考物种（分块并行）
process_reference() {
    local species=$1
    local ref_id=$2
    local ref_pep=$3
    local masked_genome=$4
    local work_dir=$5
    local log_file=$6
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 开始处理" | tee -a "$log_file"
    
    local ref_dir="${work_dir}/${ref_id}"
    mkdir -p "$ref_dir"
    cd "$ref_dir"
    
    # 检查最终输出是否存在
    local final_output="${ref_id}_exonerate.gff"
    if [ -f "$final_output" ] && [ -s "$final_output" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 输出已存在，跳过" | tee -a "$log_file"
        return 0
    fi
    
    # 分割蛋白质序列
    local chunk_dir="${ref_dir}/chunks"
    local output_dir="${ref_dir}/outputs"
    mkdir -p "$chunk_dir" "$output_dir"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 分割序列文件..." | tee -a "$log_file"
    local chunk_count=$(split_fasta "$ref_pep" "$chunk_dir" "$CHUNK_SIZE")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 分割为 $chunk_count 个块" | tee -a "$log_file"
    
    # 并行处理所有chunks
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 开始并行处理..." | tee -a "$log_file"
    local pids=()
    local chunk_num=0
    
    for chunk_file in "$chunk_dir"/chunk_*.fa; do
        if [ ! -f "$chunk_file" ]; then
            continue
        fi
        
        chunk_num=$((chunk_num + 1))
        local chunk_id=$(basename "$chunk_file" .fa | sed 's/chunk_//')
        
        # 控制并行数
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
            sleep 1
        done
        
        process_chunk "$species" "$ref_id" "$chunk_file" "$chunk_id" "$masked_genome" "$output_dir" "$log_file" &
        pids+=($!)
        
        # 每10个任务打印一次进度
        if [ $((chunk_num % 10)) -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 已启动 $chunk_num/$chunk_count 个任务" | tee -a "$log_file"
        fi
    done
    
    # 等待所有chunk完成
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 等待所有chunk完成..." | tee -a "$log_file"
    local success=0
    local failed=0
    
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 完成: 成功 $success, 失败 $failed" | tee -a "$log_file"
    
    # 合并所有chunk结果
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 合并结果..." | tee -a "$log_file"
    cat "$output_dir"/chunk_*.gff > "$final_output" 2>/dev/null || true
    
    if [ -f "$final_output" ] && [ -s "$final_output" ]; then
        local size=$(du -h "$final_output" | cut -f1)
        local gene_count=$(grep -c "gene" "$final_output" 2>/dev/null || echo "0")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] ✅ 完成: $size ($gene_count 个基因)" | tee -a "$log_file"
        
        # 清理临时文件
        rm -rf "$chunk_dir" "$output_dir"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$species-$ref_id] 合并失败" | tee -a "$log_file"
        return 1
    fi
}

# 处理单个物种
process_species() {
    local species=$1
    
    log_step "========== Exonerate超并行预测: $species =========="
    
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        return 1
    fi
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/exonerate_ultra"
    mkdir -p "$work_dir"
    
    log_info "工作目录: $work_dir"
    
    # 参考物种配置
    declare -A ref_peps
    ref_peps["hongsha"]="${RESULTS_DIR}/C01/C01.pep.fa"
    ref_peps["ganmeng"]="${RESULTS_DIR}/C02/protein.fa"
    ref_peps["C03"]="${RESULTS_DIR}/C03/protein.fa"
    
    # 串行处理每个参考物种（但内部chunk高度并行）
    local predictions=()
    
    for ref_id in hongsha ganmeng C03; do
        local ref_pep="${ref_peps[$ref_id]}"
        
        if [ ! -f "$ref_pep" ]; then
            log_warn "参考物种文件不存在: $ref_id，跳过"
            continue
        fi
        
        local ref_log="${LOG_DIR}/${species}_${ref_id}.log"
        
        if process_reference "$species" "$ref_id" "$ref_pep" "$masked_genome" "$work_dir" "$ref_log"; then
            predictions+=("${work_dir}/${ref_id}/${ref_id}_exonerate.gff")
        fi
    done
    
    # 合并所有参考物种结果
    if [ ${#predictions[@]} -gt 0 ]; then
        log_step "合并所有参考物种结果..."
        local merged_gff="${ANNOTATION_DIR}/${species}/structure/${species}_exonerate_merged.gff3"
        
        echo "##gff-version 3" > "$merged_gff"
        cat "${predictions[@]}" >> "$merged_gff"
        
        local size=$(du -h "$merged_gff" | cut -f1)
        local gene_count=$(grep -c "gene" "$merged_gff" 2>/dev/null || echo "0")
        log_info "✅ [$species] 合并完成: $size ($gene_count 个基因)"
    fi
    
    log_info "✅ [$species] Exonerate预测完成"
}

# 主函数
main() {
    LOG_FILE="${LOG_DIR}/main_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "=========================================="
    log_info "Exonerate超并行预测"
    log_info "时间: $(date)"
    log_info "最大并行任务数: $MAX_PARALLEL_JOBS"
    log_info "Chunk大小: $CHUNK_SIZE 条序列"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v exonerate &> /dev/null; then
        log_error "Exonerate未安装"
        exit 1
    fi
    
    # 处理T01和T02（串行，但内部高度并行）
    process_species "T01"
    process_species "T02"
    
    log_info ""
    log_info "=========================================="
    log_info "Exonerate超并行预测完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"

