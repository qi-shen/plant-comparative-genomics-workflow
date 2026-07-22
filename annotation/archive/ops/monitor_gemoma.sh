#!/bin/bash

# GeMoMa预测监控脚本

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "🔍 GeMoMa预测监控"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 检查进程
gemoma_proc=$(ps aux | grep -E "[G]eMoMa|[g]emoma.*run_gemoma" | grep -v grep | wc -l)
if [ $gemoma_proc -gt 0 ]; then
    echo -e "${GREEN}✅ GeMoMa进程正在运行${NC} ($gemoma_proc 个进程)"
    ps aux | grep -E "[G]eMoMa|[g]emoma.*run_gemoma" | grep -v grep | head -3 | awk '{print "  - PID "$2": "$11" "$12" "$13" "$14" "$15" "$16" "$17" "$18" "$19" "$20}'
else
    echo -e "${YELLOW}⚠️  GeMoMa进程未运行${NC}"
fi

echo ""

# 检查tblastn结果
echo "【tblastn比对结果】"
for species in T01 T02; do
    echo "  【$species】"
    for ref in hongsha ganmeng chinensis; do
        tblastn_file="${ANNOTATION_DIR}/${species}/structure/gemoma/${ref}/${ref}_tblastn.txt"
        if [ -f "$tblastn_file" ] && [ -s "$tblastn_file" ]; then
            size=$(du -h "$tblastn_file" | cut -f1)
            lines=$(wc -l < "$tblastn_file")
            echo -e "    ${GREEN}✅${NC} $ref: $size ($lines 条比对)"
        else
            echo -e "    ${YELLOW}⏳${NC} $ref: 等待..."
        fi
    done
done

echo ""

# 检查GeMoMa输出
echo "【GeMoMa预测输出】"
for species in T01 T02; do
    echo "  【$species】"
    for ref in hongsha ganmeng chinensis; do
        gemoma_dir="${ANNOTATION_DIR}/${species}/structure/gemoma/${ref}"
        gemoma_output="${gemoma_dir}/${ref}_gemoma.gff"
        output_dir="${gemoma_dir}/output"
        
        if [ -f "$gemoma_output" ] && [ -s "$gemoma_output" ]; then
            size=$(du -h "$gemoma_output" | cut -f1)
            echo -e "    ${GREEN}✅${NC} $ref: $size"
        elif [ -d "$output_dir" ]; then
            output_files=$(find "$output_dir" -name "*.gff" -o -name "*.gff3" 2>/dev/null | wc -l)
            if [ $output_files -gt 0 ]; then
                echo -e "    ${BLUE}⏳${NC} $ref: 输出目录中有 $output_files 个GFF文件（可能正在生成）"
                ls -lh "$output_dir"/*.gff* 2>/dev/null | head -3 | awk '{print "      - "$9" ("$5")"}'
            else
                echo -e "    ${YELLOW}⏳${NC} $ref: 运行中..."
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
    else
        echo -e "    ${YELLOW}⏳${NC} 合并文件: 等待中..."
    fi
done

echo ""

# 显示最新日志
echo "【最新日志】"
latest_log=$(ls -t ${PROJECT_DIR}/logs/gemoma_run_*.log 2>/dev/null | head -1)
if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
    echo "  日志文件: $(basename $latest_log)"
    echo "  最后20行:"
    tail -20 "$latest_log" | sed 's/^/  /'
else
    echo "  无日志文件"
fi

echo ""
echo "=========================================="

