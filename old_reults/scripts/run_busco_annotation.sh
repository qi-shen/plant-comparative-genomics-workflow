#!/bin/bash

# BUSCO评估脚本 - 评估注释结果
# 对BH和CK的注释蛋白质序列进行BUSCO评估

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
BUSCO_DIR="${PROJECT_DIR}/annotation/evaluation/busco"
LOG_FILE="${PROJECT_DIR}/logs/busco_annotation_$(date +%Y%m%d_%H%M%S).log"
THREADS=32
LINEAGE="embryophyta_odb10"
LINEAGE_PATH="${PROJECT_DIR}/busco_downloads/lineages/${LINEAGE}"

mkdir -p "$BUSCO_DIR" "${PROJECT_DIR}/logs"

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

# 运行BUSCO评估
run_busco() {
    local pep_file=$1
    local species_name=$2
    local output_dir="${BUSCO_DIR}/${species_name}"
    
    if [ ! -f "$pep_file" ]; then
        log_error "蛋白质文件不存在: $pep_file"
        return 1
    fi
    
    log_step "运行BUSCO评估: $species_name"
    log_info "蛋白质文件: $pep_file"
    log_info "输出目录: $output_dir"
    
    mkdir -p "$output_dir"
    
    cd "$output_dir"
    
    # 使用绝对路径
    local abs_pep_file=$(readlink -f "$pep_file")
    
    # 使用conda环境运行BUSCO
    log_info "使用conda环境运行BUSCO"
    
    # 运行BUSCO评估（蛋白质模式）
    conda run -n busco busco \
        -i "$abs_pep_file" \
        -l "$LINEAGE_PATH" \
        -o "${species_name}" \
        -m proteins \
        -c "$THREADS" \
        --offline \
        2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_info "✓ BUSCO评估完成: $species_name"
        return 0
    else
        log_error "✗ BUSCO评估失败: $species_name"
        return 1
    fi
}

# 解析BUSCO结果
parse_busco_results() {
    local species_name=$1
    local result_dir="${BUSCO_DIR}/${species_name}"
    local short_summary=$(find "$result_dir" -name "short_summary.*.txt" | head -1)
    
    if [ ! -f "$short_summary" ]; then
        log_warn "未找到BUSCO结果文件: $short_summary"
        return 1
    fi
    
    # 提取关键指标
    local complete=$(grep -E "^C:" "$short_summary" | grep -oE "[0-9]+" | head -1)
    local single=$(grep -E "^C:" "$short_summary" | grep -oE "\[S:[0-9]+" | grep -oE "[0-9]+" | head -1)
    local duplicated=$(grep -E "^C:" "$short_summary" | grep -oE "\[D:[0-9]+" | grep -oE "[0-9]+" | head -1)
    local fragmented=$(grep -E "^F:" "$short_summary" | grep -oE "[0-9]+" | head -1)
    local missing=$(grep -E "^M:" "$short_summary" | grep -oE "[0-9]+" | head -1)
    local total=$(grep -E "^C:" "$short_summary" | grep -oE "n:[0-9]+" | grep -oE "[0-9]+" | head -1)
    
    echo "$species_name|$complete|$single|$duplicated|$fragmented|$missing|$total"
}

# 生成汇总报告
generate_summary() {
    local summary_file="${BUSCO_DIR}/BUSCO_annotation_summary.txt"
    
    log_info "生成BUSCO汇总报告..."
    
    {
        echo "=========================================="
        echo "BUSCO注释评估汇总报告"
        echo "生成时间: $(date)"
        echo "数据库: ${LINEAGE}"
        echo "评估模式: proteins (蛋白质序列)"
        echo "=========================================="
        echo ""
        
        for species in "BH" "CK"; do
            result_dir="${BUSCO_DIR}/${species}"
            short_summary=$(find "$result_dir" -name "short_summary.*.txt" | head -1)
            
            if [ -f "$short_summary" ]; then
                echo "【${species} 样本】"
                echo "----------------------------------------"
                cat "$short_summary"
                echo ""
            else
                echo "【${species} 样本】"
                echo "----------------------------------------"
                echo "结果文件未找到"
                echo ""
            fi
        done
        
        echo "=========================================="
        echo "结果说明:"
        echo "  C: Complete (完整) - 单拷贝或重复"
        echo "    S: Single-copy (单拷贝)"
        echo "    D: Duplicated (重复)"
        echo "  F: Fragmented (片段化)"
        echo "  M: Missing (缺失)"
        echo "  n: Total BUSCO groups searched (总BUSCO组数)"
        echo ""
        echo "质量评估标准:"
        echo "  >90% Complete: 优秀"
        echo "  80-90% Complete: 良好"
        echo "  70-80% Complete: 中等"
        echo "  <70% Complete: 需要改进"
        echo "=========================================="
    } > "$summary_file"
    
    log_info "✓ 汇总报告已生成: $summary_file"
}

# 生成比较报告
generate_comparison() {
    local comparison_file="${BUSCO_DIR}/BUSCO_comparison.txt"
    
    log_info "生成比较报告..."
    
    {
        echo "=========================================="
        echo "BH vs CK BUSCO评估比较"
        echo "生成时间: $(date)"
        echo "=========================================="
        echo ""
        
        for species in "BH" "CK"; do
            result_dir="${BUSCO_DIR}/${species}"
            short_summary=$(find "$result_dir" -name "short_summary.*.txt" | head -1)
            
            if [ -f "$short_summary" ]; then
                echo "【${species}】"
                grep -E "^C:|^F:|^M:|^n:" "$short_summary"
                echo ""
            fi
        done
    } > "$comparison_file"
    
    log_info "✓ 比较报告已生成: $comparison_file"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "开始BUSCO注释评估"
    log_info "时间: $(date)"
    log_info "线程数: $THREADS"
    log_info "数据库: ${LINEAGE}"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查数据库是否存在
    if [ ! -d "$LINEAGE_PATH" ]; then
        log_error "BUSCO数据库不存在: $LINEAGE_PATH"
        log_info "请先下载数据库或检查路径"
        exit 1
    fi
    
    # 定义蛋白质文件
    declare -A species_peps
    species_peps["BH"]="${PROJECT_DIR}/annotation/BH/structure/BH_genes.pep.fa"
    species_peps["CK"]="${PROJECT_DIR}/annotation/CK/structure/CK_genes.pep.fa"
    
    # 运行BUSCO评估（并行运行）
    local success_count=0
    local total=${#species_peps[@]}
    local pids=()
    
    # 启动所有评估任务（后台并行运行）
    for species in "${!species_peps[@]}"; do
        pep_file="${species_peps[$species]}"
        
        if [ -f "$pep_file" ]; then
            log_step "[启动 ${species} 评估任务]"
            (
                if run_busco "$pep_file" "$species"; then
                    echo "[${species}] ✓ 评估完成" >> "$LOG_FILE"
                else
                    echo "[${species}] ✗ 评估失败" >> "$LOG_FILE"
                fi
            ) &
            pids+=($!)
            log_info "  ${species} 任务已启动 (PID: ${pids[-1]})"
        else
            log_warn "跳过 ${species} (文件不存在: $pep_file)"
        fi
    done
    
    # 等待所有任务完成
    log_info ""
    log_info "等待所有评估任务完成..."
    for i in "${!pids[@]}"; do
        pid=${pids[$i]}
        species=$(echo "${!species_peps[@]}" | awk -v idx=$i '{split($0, arr); print arr[idx+1]}')
        log_info "等待 ${species} 任务完成 (PID: $pid)..."
        if wait $pid; then
            success_count=$((success_count + 1))
            log_info "  ✓ ${species} 任务完成"
        else
            log_error "  ✗ ${species} 任务失败"
        fi
    done
    
    # 生成报告
    if [ $success_count -gt 0 ]; then
        generate_summary
        generate_comparison
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "BUSCO注释评估完成"
    log_info "成功: ${success_count}/${total}"
    log_info "时间: $(date)"
    log_info "结果保存在: $BUSCO_DIR"
    log_info "=========================================="
}

main "$@"

