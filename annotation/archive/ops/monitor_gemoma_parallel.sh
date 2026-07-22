#!/bin/bash

# 监控并行GeMoMa预测进度

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
LOG_DIR="${PROJECT_DIR}/logs/gemoma_parallel"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo "=========================================="
echo "🔍 GeMoMa并行预测实时监控"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. 进程统计
gemoma_proc=$(ps aux | grep -E "[G]eMoMa" | grep -v grep | wc -l)
echo -e "【进程状态】"
if [ $gemoma_proc -gt 0 ]; then
    echo -e "  ${GREEN}✅ GeMoMa进程: $gemoma_proc 个${NC}"
    ps aux | grep -E "[G]eMoMa" | grep -v grep | awk '{print "    PID "$2": CPU "$3"% | MEM "$4"% | "$11" "$12" "$13}' | head -10
else
    echo -e "  ${YELLOW}⚠️  无GeMoMa进程运行${NC}"
fi

echo ""

# 2. 资源使用
echo "【资源使用】"
total_cpu=$(ps aux | awk '{cpu+=$3} END {print cpu}')
total_mem=$(ps aux | awk '{mem+=$4} END {print mem}')
echo "  总CPU使用: ${total_cpu}%"
echo "  总内存使用: ${total_mem}%"
echo "  系统负载: $(uptime | awk -F'load average:' '{print $2}')"

echo ""

# 3. 任务进度
echo "【任务进度】"
for species in BH CK; do
    echo "  【$species】"
    for ref in hongsha ganmeng chinensis; do
        gemoma_file="${ANNOTATION_DIR}/${species}/structure/gemoma/${ref}/${ref}_gemoma.gff"
        output_dir="${ANNOTATION_DIR}/${species}/structure/gemoma/${ref}/output"
        
        if [ -f "$gemoma_file" ] && [ -s "$gemoma_file" ]; then
            size=$(du -h "$gemoma_file" | cut -f1)
            echo -e "    ${GREEN}✅${NC} $ref: $size"
        elif [ -d "$output_dir" ]; then
            file_count=$(find "$output_dir" -type f 2>/dev/null | wc -l)
            if [ $file_count -gt 0 ]; then
                echo -e "    ${BLUE}⏳${NC} $ref: 运行中 (输出目录有 $file_count 个文件)"
            else
                echo -e "    ${YELLOW}⏳${NC} $ref: 准备中..."
            fi
        else
            echo -e "    ${YELLOW}⏳${NC} $ref: 等待开始..."
        fi
    done
    
    # 检查合并文件
    merged_file="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
    if [ -f "$merged_file" ] && [ -s "$merged_file" ]; then
        size=$(du -h "$merged_file" | cut -f1)
        echo -e "    ${GREEN}✅${NC} 合并文件: $size"
    fi
done

echo ""

# 4. 最新日志
echo "【最新日志】"
if [ -d "$LOG_DIR" ]; then
    latest_logs=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -3)
    if [ -n "$latest_logs" ]; then
        for log in $latest_logs; do
            echo "  📄 $(basename $log):"
            tail -5 "$log" 2>/dev/null | sed 's/^/    /'
            echo ""
        done
    else
        echo "  无日志文件"
    fi
else
    echo "  日志目录不存在"
fi

echo ""
echo "=========================================="
echo "刷新间隔: 使用 watch -n 10 命令定时刷新"
echo "命令: watch -n 10 bash scripts/monitor_gemoma_parallel.sh"
echo "=========================================="

