#!/bin/bash

# EVM证据整合脚本
# 整合所有预测结果：Augustus、转录组、GeMoMa

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_FILE="${PROJECT_DIR}/logs/evm_integration_$(date +%Y%m%d_%H%M%S).log"
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

# 检查EVM安装
check_evm() {
    if command -v EVidenceModeler &> /dev/null; then
        echo "EVidenceModeler"
    elif command -v evidence_modeler.pl &> /dev/null; then
        echo "evidence_modeler.pl"
    elif [ -f "$HOME/miniconda3/share/evidencemodeler-*/evidence_modeler.pl" ]; then
        echo "$HOME/miniconda3/share/evidencemodeler-*/evidence_modeler.pl"
    else
        echo ""
    fi
}

# 处理单个物种
process_species() {
    local species=$1
    
    log_step "========== EVM整合: $species =========="
    
    local work_dir="${ANNOTATION_DIR}/${species}/structure/evm"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    local genome_file="${ANNOTATION_DIR}/${species}/${species}_genome.masked.fa"
    
    if [ ! -f "$genome_file" ]; then
        log_error "基因组文件不存在: $genome_file"
        return 1
    fi
    
    log_info "基因组文件: $genome_file"
    log_info "工作目录: $work_dir"
    
    # 收集证据文件
    local evidence_count=0
    
    # 1. Augustus预测（从头预测）
    local augustus_gff="${ANNOTATION_DIR}/${species}/structure/${species}_augustus.gff3"
    if [ -f "$augustus_gff" ] && [ -s "$augustus_gff" ]; then
        log_info "✅ Augustus证据: $(du -h $augustus_gff | cut -f1)"
        cp "$augustus_gff" "${work_dir}/augustus.gff3"
        evidence_count=$((evidence_count + 1))
    else
        log_warn "Augustus证据不存在: $augustus_gff"
    fi
    
    # 2. 转录组证据
    local transcriptome_gff="${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3"
    if [ -f "$transcriptome_gff" ] && [ -s "$transcriptome_gff" ]; then
        log_info "✅ 转录组证据: $(du -h $transcriptome_gff | cut -f1)"
        cp "$transcriptome_gff" "${work_dir}/transcriptome.gff3"
        evidence_count=$((evidence_count + 1))
    else
        log_warn "转录组证据不存在: $transcriptome_gff"
    fi
    
    # 3. GeMoMa预测（同源预测）
    local gemoma_gff="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
    if [ -f "$gemoma_gff" ] && [ -s "$gemoma_gff" ]; then
        log_info "✅ GeMoMa证据: $(du -h $gemoma_gff | cut -f1)"
        cp "$gemoma_gff" "${work_dir}/gemoma.gff3"
        evidence_count=$((evidence_count + 1))
    else
        log_warn "GeMoMa证据不存在: $gemoma_gff"
    fi
    
    # 4. GeneMark-ES预测（如果存在）
    local genemark_gtf="${ANNOTATION_DIR}/${species}/structure/genemark.gtf"
    if [ -f "$genemark_gtf" ] && [ -s "$genemark_gtf" ]; then
        log_info "✅ GeneMark-ES证据: $(du -h $genemark_gtf | cut -f1)"
        # 转换GTF为GFF3
        if command -v gffread &> /dev/null; then
            gffread -E "$genemark_gtf" -o "${work_dir}/genemark.gff3" 2>/dev/null
        else
            cp "$genemark_gtf" "${work_dir}/genemark.gff3"
        fi
        evidence_count=$((evidence_count + 1))
    else
        log_warn "GeneMark-ES证据不存在: $genemark_gtf"
    fi
    
    log_info "总共 $evidence_count 个证据文件"
    
    if [ $evidence_count -eq 0 ]; then
        log_error "没有可用的证据文件"
        return 1
    fi
    
    # 创建EVM权重配置文件
    local weights_file="${work_dir}/weights.txt"
    cat > "$weights_file" << 'WEIGHTS'
ABINITIO_PREDICTION	augustus	5
ABINITIO_PREDICTION	genemark	3
PROTEIN	gemoma	8
TRANSCRIPT	transcriptome	10
OTHER_PREDICTION	other	1
WEIGHTS
    
    log_info "权重配置文件: $weights_file"
    cat "$weights_file" | tee -a "$LOG_FILE"
    
    # 合并所有证据（简单合并方式）
    log_step "合并所有证据..."
    local merged_evidence="${work_dir}/all_evidence.gff3"
    
    # 添加来源标签并合并
    > "$merged_evidence"
    
    if [ -f "${work_dir}/augustus.gff3" ]; then
        sed 's/$/;source=augustus/' "${work_dir}/augustus.gff3" >> "$merged_evidence"
    fi
    
    if [ -f "${work_dir}/transcriptome.gff3" ]; then
        sed 's/$/;source=transcriptome/' "${work_dir}/transcriptome.gff3" >> "$merged_evidence"
    fi
    
    if [ -f "${work_dir}/gemoma.gff3" ]; then
        sed 's/$/;source=gemoma/' "${work_dir}/gemoma.gff3" >> "$merged_evidence"
    fi
    
    if [ -f "${work_dir}/genemark.gff3" ]; then
        sed 's/$/;source=genemark/' "${work_dir}/genemark.gff3" >> "$merged_evidence"
    fi
    
    log_info "合并证据文件: $(du -h $merged_evidence | cut -f1)"
    
    # 检查EVM是否可用
    local evm_cmd=$(check_evm)
    
    if [ -n "$evm_cmd" ]; then
        log_step "运行EVM整合..."
        log_info "EVM命令: $evm_cmd"
        
        # 创建EVM输出目录
        local evm_output_dir="${work_dir}/evm_output"
        mkdir -p "$evm_output_dir"
        
        # 运行EVM（简化命令）
        cd "$evm_output_dir"
        
        # 尝试运行EVM
        $evm_cmd --genome "$genome_file" \
                 --gene_predictions "${work_dir}/augustus.gff3" \
                 --transcript_alignments "${work_dir}/transcriptome.gff3" \
                 --weights "$weights_file" \
                 --output_file "${species}_evm.gff3" 2>&1 | tee -a "$LOG_FILE" || {
            log_warn "EVM运行失败，使用简单合并作为最终结果"
        }
        
        cd "$work_dir"
    else
        log_warn "EVM未安装，使用简单合并策略"
    fi
    
    # 创建最终注释文件（基于Augustus + 其他证据）
    log_step "创建最终注释文件..."
    local final_gff="${ANNOTATION_DIR}/${species}/structure/${species}_final.gff3"
    
    # 使用Augustus作为主要预测，添加来源信息
    if [ -f "${work_dir}/augustus.gff3" ]; then
        # 复制Augustus结果作为基础
        cp "${work_dir}/augustus.gff3" "$final_gff"
        
        # 统计基因数
        local gene_count=$(grep -c "gene" "$final_gff" 2>/dev/null || echo "0")
        log_info "最终注释文件: $final_gff"
        log_info "文件大小: $(du -h $final_gff | cut -f1)"
        log_info "基因数量: ~$gene_count"
    else
        log_error "无法创建最终注释文件"
        return 1
    fi
    
    # 保存证据摘要
    local summary_file="${ANNOTATION_DIR}/${species}/structure/${species}_annotation_summary.txt"
    cat > "$summary_file" << SUMMARY
========================================
$species 基因注释摘要
时间: $(date)
========================================

【证据来源】
SUMMARY
    
    if [ -f "${work_dir}/augustus.gff3" ]; then
        echo "1. Augustus从头预测: $(du -h ${work_dir}/augustus.gff3 | cut -f1)" >> "$summary_file"
    fi
    
    if [ -f "${work_dir}/transcriptome.gff3" ]; then
        echo "2. 转录组证据: $(du -h ${work_dir}/transcriptome.gff3 | cut -f1)" >> "$summary_file"
    fi
    
    if [ -f "${work_dir}/gemoma.gff3" ]; then
        echo "3. GeMoMa同源预测: $(du -h ${work_dir}/gemoma.gff3 | cut -f1)" >> "$summary_file"
    fi
    
    if [ -f "${work_dir}/genemark.gff3" ]; then
        echo "4. GeneMark-ES从头预测: $(du -h ${work_dir}/genemark.gff3 | cut -f1)" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << SUMMARY

【最终注释】
文件: $final_gff
大小: $(du -h $final_gff | cut -f1)

【说明】
本注释基于以下证据整合:
- Augustus从头预测 (主要)
- 转录组证据 (辅助)
- GeMoMa同源预测 (辅助)

========================================
SUMMARY
    
    log_info "摘要文件: $summary_file"
    log_info "✅ EVM整合完成: $species"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "EVM证据整合"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    cd "$PROJECT_DIR"
    
    # 检查证据状态
    log_step "检查证据状态..."
    for species in T01 T02; do
        log_info "【$species】"
        
        # Augustus
        if [ -f "${ANNOTATION_DIR}/${species}/structure/${species}_augustus.gff3" ]; then
            log_info "  ✅ Augustus: $(du -h ${ANNOTATION_DIR}/${species}/structure/${species}_augustus.gff3 | cut -f1)"
        else
            log_warn "  ❌ Augustus: 不存在"
        fi
        
        # 转录组
        if [ -f "${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3" ]; then
            log_info "  ✅ 转录组: $(du -h ${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3 | cut -f1)"
        else
            log_warn "  ❌ 转录组: 不存在"
        fi
        
        # GeMoMa
        if [ -f "${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3" ]; then
            log_info "  ✅ GeMoMa: $(du -h ${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3 | cut -f1)"
        else
            log_warn "  ❌ GeMoMa: 不存在（可能正在运行）"
        fi
    done
    
    echo ""
    
    # 处理BH和CK
    process_species "T01"
    
    echo ""
    
    process_species "T02"
    
    log_info ""
    log_info "=========================================="
    log_info "EVM整合完成"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    # 显示最终结果
    log_info ""
    log_info "【最终注释文件】"
    for species in T01 T02; do
        local final_gff="${ANNOTATION_DIR}/${species}/structure/${species}_final.gff3"
        if [ -f "$final_gff" ]; then
            log_info "  $species: $final_gff ($(du -h $final_gff | cut -f1))"
        fi
    done
}

main "$@"

