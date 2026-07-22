#!/bin/bash

# 检查所有预测任务进度

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"

echo "=========================================="
echo "📊 预测任务进度检查"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 1. 检查GeMoMa进程
echo "【1️⃣ GeMoMa同源预测】"
gemoma_count=$(ps aux | grep -E "[g]emoma|[t]blastn.*annotation" | grep -v grep | wc -l)
if [ $gemoma_count -gt 0 ]; then
    echo -e "  ${GREEN}✅ 正在运行${NC} ($gemoma_count 个进程)"
    ps aux | grep -E "[t]blastn.*annotation" | grep -v grep | awk '{print "    - tblastn: "$2" (CPU: "$3"%)"}' | head -2
    
    # 检查当前处理的参考物种
    current_ref=$(tail -50 ${PROJECT_DIR}/logs/gemoma_*.log 2>/dev/null | grep -o "处理参考物种: [a-z]*" | tail -1)
    if [ -n "$current_ref" ]; then
        echo "    当前: $current_ref"
    fi
else
    # 检查是否已完成
    if [ -f "${ANNOTATION_DIR}/T01/structure/T01_gemoma_merged.gff3" ] && [ -f "${ANNOTATION_DIR}/T02/structure/T02_gemoma_merged.gff3" ]; then
        echo -e "  ${GREEN}✅ 已完成${NC}"
    else
        echo -e "  ${YELLOW}⚠️  未运行或已失败${NC}"
    fi
fi

# 显示GeMoMa输出文件
for species in T01 T02; do
    gemoma_file="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
    if [ -f "$gemoma_file" ] && [ -s "$gemoma_file" ]; then
        size=$(du -h "$gemoma_file" | cut -f1)
        echo -e "  ${GREEN}✅${NC} $species: $size"
    else
        echo -e "  ${YELLOW}⏳${NC} $species: 等待中..."
    fi
done

echo ""

# 2. 检查tblastn比对结果
echo "【2️⃣ tblastn比对结果】"
for species in T01 T02; do
    echo "  【$species】"
    gemoma_dir="${ANNOTATION_DIR}/${species}/structure/gemoma"
    if [ -d "$gemoma_dir" ]; then
        for ref in hongsha ganmeng chinensis; do
            tblastn_file="${gemoma_dir}/${ref}/${ref}_tblastn.txt"
            if [ -f "$tblastn_file" ] && [ -s "$tblastn_file" ]; then
                size=$(du -h "$tblastn_file" | cut -f1)
                lines=$(wc -l < "$tblastn_file")
                echo -e "    ${GREEN}✅${NC} $ref: $size ($lines 条比对)"
            else
                echo -e "    ${YELLOW}⏳${NC} $ref: 等待..."
            fi
        done
    else
        echo "    目录不存在"
    fi
done

echo ""

# 3. 检查所有证据文件
echo "【3️⃣ 证据文件状态】"
for species in T01 T02; do
    echo "  【$species】"
    
    # Augustus
    augustus="${ANNOTATION_DIR}/${species}/structure/${species}_augustus.gff3"
    if [ -f "$augustus" ] && [ -s "$augustus" ]; then
        size=$(du -h "$augustus" | cut -f1)
        echo -e "    ${GREEN}✅${NC} Augustus: $size"
    else
        echo -e "    ${RED}❌${NC} Augustus: 不存在"
    fi
    
    # 转录组
    transcriptome="${ANNOTATION_DIR}/${species}/structure/${species}_transcriptome.gff3"
    if [ -f "$transcriptome" ] && [ -s "$transcriptome" ]; then
        size=$(du -h "$transcriptome" | cut -f1)
        echo -e "    ${GREEN}✅${NC} 转录组: $size"
    else
        echo -e "    ${RED}❌${NC} 转录组: 不存在"
    fi
    
    # GeMoMa
    gemoma="${ANNOTATION_DIR}/${species}/structure/${species}_gemoma_merged.gff3"
    if [ -f "$gemoma" ] && [ -s "$gemoma" ]; then
        size=$(du -h "$gemoma" | cut -f1)
        echo -e "    ${GREEN}✅${NC} GeMoMa: $size"
    else
        echo -e "    ${YELLOW}⏳${NC} GeMoMa: 等待中..."
    fi
    
    # 最终注释
    final="${ANNOTATION_DIR}/${species}/structure/${species}_final.gff3"
    if [ -f "$final" ] && [ -s "$final" ]; then
        size=$(du -h "$final" | cut -f1)
        echo -e "    ${GREEN}✅${NC} 最终注释: $size"
    else
        echo -e "    ${YELLOW}⏳${NC} 最终注释: 等待EVM整合"
    fi
done

echo ""

# 4. 下一步建议
echo "【4️⃣ 下一步】"
if [ $gemoma_count -gt 0 ]; then
    echo "  ⏳ 等待GeMoMa完成..."
    echo "  📊 监控命令: tail -f ${PROJECT_DIR}/logs/gemoma_*.log"
elif [ -f "${ANNOTATION_DIR}/T01/structure/T01_gemoma_merged.gff3" ] && [ -f "${ANNOTATION_DIR}/T02/structure/T02_gemoma_merged.gff3" ]; then
    echo "  ✅ GeMoMa已完成!"
    echo "  💡 运行EVM整合: bash ${PROJECT_DIR}/scripts/run_evm_integration.sh"
else
    echo "  ⚠️  GeMoMa未运行，请检查日志"
fi

echo ""
echo "=========================================="

