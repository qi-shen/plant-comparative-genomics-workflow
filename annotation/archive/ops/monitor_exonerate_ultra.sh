#!/bin/bash

# 监控超并行Exonerate预测进度

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_DIR="${PROJECT_DIR}/logs/exonerate_ultra"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo "=========================================="
echo "🚀 Exonerate超并行预测实时监控"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 进程和资源
exonerate_count=$(ps aux | grep -E "[e]xonerate" | wc -l)
total_cpu=$(ps aux | awk '{cpu+=$3} END {print cpu}')
total_mem=$(ps aux | awk '{mem+=$4} END {print mem}')

echo "【系统资源】"
echo "  CPU核心数: $(nproc)"
echo "  Exonerate进程: $exonerate_count"
echo "  总CPU使用: ${total_cpu}%"
echo "  总内存使用: ${total_mem}%"
echo "  系统负载: $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "【任务进度】"

for species in BH CK; do
    echo "  【$species】"
    
    work_dir="${ANNOTATION_DIR}/${species}/structure/exonerate_ultra"
    
    for ref in hongsha ganmeng chinensis; do
        ref_dir="${work_dir}/${ref}"
        final_gff="${ref_dir}/${ref}_exonerate.gff"
        output_dir="${ref_dir}/outputs"
        
        if [ -f "$final_gff" ] && [ -s "$final_gff" ]; then
            size=$(du -h "$final_gff" | cut -f1)
            genes=$(grep -c "gene" "$final_gff" 2>/dev/null || echo "0")
            echo -e "    ${GREEN}✅${NC} $ref: $size ($genes 个基因)"
        elif [ -d "$output_dir" ]; then
            completed=$(ls "$output_dir"/chunk_*.gff 2>/dev/null | wc -l)
            total=$(ls "$ref_dir"/chunks/chunk_*.fa 2>/dev/null | wc -l)
            if [ $total -gt 0 ]; then
                progress=$((completed * 100 / total))
                echo -e "    ${BLUE}⏳${NC} $ref: $completed/$total chunks ($progress%)"
            else
                echo -e "    ${YELLOW}⏳${NC} $ref: 准备中..."
            fi
        else
            echo -e "    ${YELLOW}⏳${NC} $ref: 等待开始..."
        fi
    done
    
    # 合并文件
    merged_file="${ANNOTATION_DIR}/${species}/structure/${species}_exonerate_merged.gff3"
    if [ -f "$merged_file" ] && [ -s "$merged_file" ]; then
        size=$(du -h "$merged_file" | cut -f1)
        genes=$(grep -c "gene" "$merged_file" 2>/dev/null || echo "0")
        echo -e "    ${GREEN}✅${NC} 合并文件: $size ($genes 个基因)"
    fi
done

echo ""
echo "【最新日志】"
latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
    echo "  📄 $(basename $latest_log):"
    tail -5 "$latest_log" 2>/dev/null | sed 's/^/    /'
else
    echo "  无日志文件"
fi

echo ""
echo "=========================================="
echo "刷新: watch -n 5 bash scripts/monitor_exonerate_ultra.sh"
echo "=========================================="

