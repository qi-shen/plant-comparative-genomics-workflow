#!/bin/bash

# Exonerate同源预测并行脚本
# 替代GeMoMa进行同源基因预测

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
LOG_DIR="${PROJECT_DIR}/logs/exonerate_parallel"
THREADS=32  # 每个exonerate任务使用的线程数
MAX_PARALLEL_JOBS=4  # 最多同时运行4个exonerate任务

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

# 处理单个参考物种的Exonerate预测（用于并行）
process_reference() {
    local species=$1
    local ref_id=$2
    local ref_pep=$3
    local masked_genome=$4
    local work_dir=$5
    local log_file=$6
    
    (
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 开始Exonerate预测" | tee -a "$log_file"
        
        local ref_dir="${work_dir}/${ref_id}"
        mkdir -p "$ref_dir"
        cd "$ref_dir"
        
        # Exonerate预测
        local exonerate_output="${ref_id}_exonerate.gff"
        
        if [ -f "$exonerate_output" ] && [ -s "$exonerate_output" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] Exonerate输出已存在，跳过" | tee -a "$log_file"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] 运行Exonerate预测..." | tee -a "$log_file"
            
            # 使用protein2genome模型，输出GFF格式
            # --maxintron 15000: 最大内含子长度
            # --showalignment FALSE: 不显示详细比对，加速运行
            # --showvulgar FALSE: 不显示vulgar格式
            # --ryo: 自定义输出格式
            exonerate \
                --model protein2genome \
                --query "$ref_pep" \
                --target "$masked_genome" \
                --percent 70 \
                --maxintron 15000 \
                --showalignment FALSE \
                --showvulgar FALSE \
                --ryo "GFF\n" \
                --bestn 1 \
                > "${ref_id}_exonerate_raw.gff" 2>> "$log_file"
            
            if [ $? -ne 0 ]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$species-$ref_id] Exonerate失败" | tee -a "$log_file"
                return 1
            fi
            
            # 提取GFF行（过滤掉注释和其他信息）
            grep -v "^#" "${ref_id}_exonerate_raw.gff" | \
            grep -v "^Command line" | \
            grep -v "^Hostname" | \
            awk '$3 == "gene" || $3 == "exon" || $3 == "cds"' > "$exonerate_output"
            
            if [ -s "$exonerate_output" ]; then
                local size=$(du -h "$exonerate_output" | cut -f1)
                local gene_count=$(grep -c "gene" "$exonerate_output" 2>/dev/null || echo "0")
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$species-$ref_id] ✅ Exonerate完成: $size ($gene_count 个基因)" | tee -a "$log_file"
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$species-$ref_id] Exonerate输出为空" | tee -a "$log_file"
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
    
    log_step "========== Exonerate同源预测: $species =========="
    
    local masked_genome="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    if [ ! -f "$masked_genome" ]; then
        log_error "掩蔽基因组不存在: $masked_genome"
        return 1
    fi
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/exonerate"
    mkdir -p "$work_dir"
    
    log_info "使用掩蔽基因组: $masked_genome"
    log_info "工作目录: $work_dir"
    
    # 参考物种配置
    declare -A ref_peps
    
    ref_peps["hongsha"]="${RESULTS_DIR}/C01/C01.pep.fa"
    ref_peps["ganmeng"]="${RESULTS_DIR}/C02/protein.fa"
    ref_peps["C03"]="${RESULTS_DIR}/C03/protein.fa"
    
    # 并行处理所有参考物种
    local pids=()
    local ref_ids=()
    
    for ref_id in hongsha ganmeng C03; do
        local ref_pep="${ref_peps[$ref_id]}"
        
        if [ ! -f "$ref_pep" ]; then
            log_warn "参考物种文件不存在: $ref_id，跳过"
            continue
        fi
        
        # 控制并行数
        while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL_JOBS ]; do
            sleep 5
        done
        
        local ref_log_file="${LOG_DIR}/${species}_${ref_id}_$(date +%Y%m%d_%H%M%S).log"
        process_reference "$species" "$ref_id" "$ref_pep" "$masked_genome" "$work_dir" "$ref_log_file" &
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
    
    # 合并所有Exonerate预测结果
    log_step "[$species] 合并Exonerate预测结果..."
    local merged_gff="${ANNOTATION_DIR}/${species}/structure/${species}_exonerate_merged.gff3"
    local exonerate_predictions=()
    
    for ref_id in hongsha ganmeng C03; do
        local exonerate_gff="${work_dir}/${ref_id}/${ref_id}_exonerate.gff"
        if [ -f "$exonerate_gff" ] && [ -s "$exonerate_gff" ]; then
            exonerate_predictions+=("$exonerate_gff")
        fi
    done
    
    if [ ${#exonerate_predictions[@]} -gt 0 ]; then
        # 添加GFF3头部
        echo "##gff-version 3" > "$merged_gff"
        cat "${exonerate_predictions[@]}" >> "$merged_gff"
        
        if [ -f "$merged_gff" ] && [ -s "$merged_gff" ]; then
            log_info "[$species] ✅ 合并完成: $merged_gff"
            log_info "[$species]    文件大小: $(du -h $merged_gff | cut -f1)"
            log_info "[$species]    行数: $(wc -l < $merged_gff)"
            local gene_count=$(grep -c "gene" "$merged_gff" 2>/dev/null || echo "0")
            log_info "[$species]    基因数: $gene_count"
        else
            log_error "[$species] 合并失败"
        fi
    else
        log_warn "[$species] 没有成功的Exonerate预测结果"
    fi
    
    log_info "[$species] ✅ Exonerate预测完成"
}

# 主函数
main() {
    local main_log_file="${LOG_DIR}/main_$(date +%Y%m%d_%H%M%S).log"
    LOG_FILE="$main_log_file"
    
    log_info "=========================================="
    log_info "Exonerate同源预测（并行优化版）"
    log_info "时间: $(date)"
    log_info "每任务线程数: $THREADS"
    log_info "最大并行任务数: $MAX_PARALLEL_JOBS"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查工具
    if ! command -v exonerate &> /dev/null; then
        log_error "Exonerate未安装"
        log_info "安装命令: conda install -y -c bioconda exonerate"
        exit 1
    fi
    
    log_info "Exonerate版本: $(exonerate --version 2>&1 | head -1)"
    
    # 并行处理T01和T02
    log_step "并行处理T01和T02两个物种..."
    
    process_species "T01" &
    local bh_pid=$!
    log_info "启动T01预测任务 (PID: $bh_pid)"
    
    sleep 5  # 稍微延迟，避免同时启动过多任务
    
    process_species "T02" &
    local ck_pid=$!
    log_info "启动T02预测任务 (PID: $ck_pid)"
    
    # 等待两个物种都完成
    log_info "等待T01和T02预测完成..."
    wait "$bh_pid"
    local bh_status=$?
    
    wait "$ck_pid"
    local ck_status=$?
    
    log_info ""
    log_info "=========================================="
    log_info "Exonerate同源预测完成"
    log_info "时间: $(date)"
    log_info "T01状态: $([ $bh_status -eq 0 ] && echo '成功' || echo '失败')"
    log_info "T02状态: $([ $ck_status -eq 0 ] && echo '成功' || echo '失败')"
    log_info "=========================================="
    
    # 显示结果摘要
    log_info ""
    log_info "【预测结果】"
    for species in T01 T02; do
        local merged_file="${ANNOTATION_DIR}/${species}/structure/${species}_exonerate_merged.gff3"
        if [ -f "$merged_file" ] && [ -s "$merged_file" ]; then
            local size=$(du -h "$merged_file" | cut -f1)
            local gene_count=$(grep -c "gene" "$merged_file" 2>/dev/null || echo "0")
            log_info "  $species: $merged_file ($size, $gene_count 个基因)"
        fi
    done
}

main "$@"

