#!/bin/bash

# GeMoMa同源预测并行优化脚本
# 充分利用服务器资源，并行处理多个参考物种和多个目标物种

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
LOG_DIR="${PROJECT_DIR}/logs/gemoma_parallel"
THREADS=64  # 增加线程数，利用更多CPU核心
MAX_PARALLEL_JOBS=6  # 最多同时运行6个GeMoMa任务（每个任务需要较多内存）

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

# 处理单个参考物种的GeMoMa预测（用于并行）
process_reference() {
    local species=$1
    local ref_id=$2
    local ref_gff=$3
    local ref_pep=$4
    local masked_genome=$5
    local work_dir=$6
    local log_file=$7
    
    (
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 开始处理参考物种: $ref_id" | tee -a "$log_file"
        
        local ref_dir="${work_dir}/${ref_id}"
        mkdir -p "$ref_dir"
        cd "$ref_dir"
        
        # 步骤1: tblastn比对（如果还没有）
        local tblastn_output="${ref_id}_tblastn.txt"
        if [ -f "$tblastn_output" ] && [ -s "$tblastn_output" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] tblastn输出已存在，跳过比对" | tee -a "$log_file"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 运行tblastn比对..." | tee -a "$log_file"
            tblastn -query "$ref_pep" \
                    -db "$masked_genome" \
                    -outfmt "6 std sallseqid" \
                    -out "$tblastn_output" \
                    -num_threads "$THREADS" \
                    -evalue 1e-5 \
                    -max_target_seqs 10 >> "$log_file" 2>&1
            
            if [ $? -ne 0 ] || [ ! -s "$tblastn_output" ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$species-$ref_id] tblastn失败" | tee -a "$log_file"
                return 1
            fi
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] ✅ tblastn完成: $(wc -l < $tblastn_output) 条比对" | tee -a "$log_file"
        fi
        
        # 步骤2: GeMoMa预测
        local gemoma_output="${ref_dir}/${ref_id}_gemoma.gff"
        if [ -f "$gemoma_output" ] && [ -s "$gemoma_output" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] GeMoMa输出已存在，跳过预测" | tee -a "$log_file"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 运行GeMoMa预测..." | tee -a "$log_file"
            
            local output_dir="${ref_dir}/output"
            mkdir -p "$output_dir"
            
            # 使用正确的GeMoMa命令格式
            GeMoMa GeMoMa \
                s="$tblastn_output" \
                t="$masked_genome" \
                a="$ref_gff" \
                c="$ref_pep" \
                outdir="$output_dir" >> "$log_file" 2>&1 || {
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$species-$ref_id] GeMoMa预测失败" | tee -a "$log_file"
                return 1
            }
            
            # 查找输出文件
            local found_gff=""
            if [ -f "${output_dir}/predicted_annotation.gff" ]; then
                found_gff="${output_dir}/predicted_annotation.gff"
            elif [ -f "${output_dir}/final_annotation.gff" ]; then
                found_gff="${output_dir}/final_annotation.gff"
            else
                found_gff=$(find "${output_dir}" -name "*.gff" -o -name "*.gff3" | head -1)
            fi
            
            if [ -n "$found_gff" ] && [ -f "$found_gff" ]; then
                cp "$found_gff" "$gemoma_output"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] ✅ GeMoMa预测完成: $(du -h $gemoma_output | cut -f1)" | tee -a "$log_file"
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$species-$ref_id] GeMoMa输出文件不存在" | tee -a "$log_file"
                return 1
            fi
        fi
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] ✅ 处理完成" | tee -a "$log_file"
    ) >> "$log_file" 2>&1
}

# 处理单个物种的所有参考物种（并行化）
process_species() {
    local species=$1
    local species_log_file="${LOG_DIR}/${species}_$(date +%Y%m%d_%H%M%S).log"
    touch "$species_log_file"
    
    log_step "========== GeMoMa同源预测: $species =========="
    
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        return 1
    fi
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/gemoma"
    mkdir -p "$work_dir"
    
    log_info "使用掩蔽基因组: $masked_genome"
    log_info "工作目录: $work_dir"
    
    # 参考物种配置
    declare -A ref_gffs
    declare -A ref_peps
    
    ref_gffs["hongsha"]="${RESULTS_DIR}/C01/hs.chrom.genome.gff"
    ref_peps["hongsha"]="${RESULTS_DIR}/C01/C01.pep.fa"
    
    ref_gffs["ganmeng"]="${RESULTS_DIR}/C02/tau.gff3"
    ref_peps["ganmeng"]="${RESULTS_DIR}/C02/protein.fa"
    
    ref_gffs["C03"]="${RESULTS_DIR}/C03/genes.gff3"
    ref_peps["C03"]="${RESULTS_DIR}/C03/protein.fa"
    
    # 并行处理所有参考物种
    local pids=()
    local ref_ids=()
    
    for ref_id in hongsha ganmeng C03; do
        local ref_gff="${ref_gffs[$ref_id]}"
        local ref_pep="${ref_peps[$ref_id]}"
        
        if [ ! -f "$ref_gff" ] || [ ! -f "$ref_pep" ]; then
            log_warn "参考物种文件不存在: $ref_id，跳过"
            continue
        fi
        
        # 控制并行数
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
            sleep 5
        done
        
        local ref_log_file="${LOG_DIR}/${species}_${ref_id}_$(date +%Y%m%d_%H%M%S).log"
        process_reference "$species" "$ref_id" "$ref_gff" "$ref_pep" "$masked_genome" "$work_dir" "$ref_log_file" &
        pids+=($!)
        ref_ids+=("$ref_id")
        
        log_info "启动 [$species-$ref_id] 预测任务 (PID: $!)"
        sleep 2  # 稍微延迟，避免同时启动过多任务
    done
    
    # 等待所有任务完成
    log_info "等待所有 [$species] 参考物种预测完成..."
    local success_count=0
    local fail_count=0
    
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local ref_id=${ref_ids[$i]}
        
        if wait "$pid"; then
            log_info "[$species-$ref_id] ✅ 成功完成"
            success_count=$((success_count + 1))
        else
            log_error "[$species-$ref_id] ❌ 失败"
            fail_count=$((fail_count + 1))
        fi
    done
    
    log_info "[$species] 完成统计: 成功 $success_count, 失败 $fail_count"
    
    # 合并所有GeMoMa预测结果
    log_step "[$species] 合并GeMoMa预测结果..."
    local merged_gff="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
    local gemoma_predictions=()
    
    for ref_id in hongsha ganmeng C03; do
        local gemoma_gff="${work_dir}/${ref_id}/${ref_id}_gemoma.gff"
        if [ -f "$gemoma_gff" ] && [ -s "$gemoma_gff" ]; then
            gemoma_predictions+=("$gemoma_gff")
        fi
    done
    
    if [ ${#gemoma_predictions[@]} -gt 0 ]; then
        cat "${gemoma_predictions[@]}" > "$merged_gff"
        
        if [ -f "$merged_gff" ] && [ -s "$merged_gff" ]; then
            log_info "[$species] ✅ 合并完成: $merged_gff"
            log_info "[$species]    文件大小: $(du -h $merged_gff | cut -f1)"
            log_info "[$species]    行数: $(wc -l < $merged_gff)"
        else
            log_error "[$species] 合并失败"
        fi
    else
        log_warn "[$species] 没有成功的GeMoMa预测结果"
    fi
    
    log_info "[$species] ✅ GeMoMa预测完成"
}

# 主函数
main() {
    local main_log_file="${LOG_DIR}/main_$(date +%Y%m%d_%H%M%S).log"
    LOG_FILE="$main_log_file"
    
    log_info "=========================================="
    log_info "GeMoMa同源预测（并行优化版）"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "最大并行任务数: $MAX_PARALLEL_JOBS"
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
    
    # 并行处理BH和CK
    log_step "并行处理BH和CK两个物种..."
    
    process_species "T01" &
    local bh_pid=$!
    log_info "启动BH预测任务 (PID: $bh_pid)"
    
    sleep 5  # 稍微延迟，避免同时启动过多任务
    
    process_species "T02" &
    local ck_pid=$!
    log_info "启动CK预测任务 (PID: $ck_pid)"
    
    # 等待两个物种都完成
    log_info "等待BH和CK预测完成..."
    wait "$bh_pid"
    local bh_status=$?
    
    wait "$ck_pid"
    local ck_status=$?
    
    log_info ""
    log_info "=========================================="
    log_info "GeMoMa同源预测完成"
    log_info "时间: $(date)"
    log_info "BH状态: $([ $bh_status -eq 0 ] && echo '成功' || echo '失败')"
    log_info "CK状态: $([ $ck_status -eq 0 ] && echo '成功' || echo '失败')"
    log_info "=========================================="
}

main "$@"

