#!/bin/bash

# 监控Exonerate预测进度

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_DIR="${PROJECT_DIR}/logs/exonerate_parallel"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo "=========================================="
echo "🔍 Exonerate预测实时监控"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. 进程统计
exonerate_proc=$(ps aux | grep -E "[e]xonerate" | grep -v grep | wc -l)
echo "【进程状态】"
if [ $exonerate_proc -gt 0 ]; then
    echo -e "  ${GREEN}✅ Exonerate进程: $exonerate_proc 个${NC}"
    ps aux | grep -E "[e]xonerate" | grep -v grep | awk '{print "    PID "$2": CPU "$3"% | MEM "$4"% | "$11}' | head -10
else
    echo -e "  ${YELLOW}⚠️  无Exonerate进程运行${NC}"
fi

echo ""

# 2. 资源使用
echo "【资源使用】"
total_cpu=$(ps aux | awk '{cpu+=$3} END {print cpu}')
total_mem=$(ps aux | awk '{mem+=$4} END {print mem}')
echo "  总CPU使用: ${total_cpu}%"
echo "  总内存使用: ${total_mem}%"

echo ""

# 3. 任务进度
echo "【任务进度】"
for species in T01 T02; do
    echo "  【$species】"
    for ref in hongsha ganmeng chinensis; do
        exonerate_file="${ANNOTATION_DIR}/${species}/structure/exonerate/${ref}/${ref}_exonerate.gff"
        
        if [ -f "$exonerate_file" ] && [ -s "$exonerate_file" ]; then
            size=$(du -h "$exonerate_file" | cut -f1)
            gene_count=$(grep -c "gene" "$exonerate_file" 2>/dev/null || echo "0")
            echo -e "    ${GREEN}✅${NC} $ref: $size ($gene_count 个基因)"
        else
            echo -e "    ${YELLOW}⏳${NC} $ref: 运行中或等待..."
        fi
    done
    
    # 检查合并文件
    merged_file="${ANNOTATION_DIR}/${species}/structure/${species}_exonerate_merged.gff3"
    if [ -f "$merged_file" ] && [ -s "$merged_file" ]; then
        size=$(du -h "$merged_file" | cut -f1)
        gene_count=$(grep -c "gene" "$merged_file" 2>/dev/null || echo "0")
        echo -e "    ${GREEN}✅${NC} 合并文件: $size ($gene_count 个基因)"
    fi
done

echo ""

# 4. 最新日志
echo "【最新日志】"
if [ -d "$LOG_DIR" ]; then
    latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        echo "  📄 $(basename $latest_log):"
        tail -10 "$latest_log" 2>/dev/null | sed 's/^/    /'
    else
        echo "  无日志文件"
    fi
else
    echo "  日志目录不存在"
fi

echo ""
echo "=========================================="
echo "刷新: watch -n 10 bash scripts/monitor_exonerate.sh"
echo "=========================================="

