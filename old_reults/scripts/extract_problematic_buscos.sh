#!/bin/bash

# 提取片段化和缺失的BUSCO基因，用于改进注释

set -e

PROJECT_DIR="/path/to/project_root"
SPECIES=${1:-"BH"}  # 默认BH，可指定CK

BUSCO_DIR="${PROJECT_DIR}/annotation/evaluation/busco/${SPECIES}/${SPECIES}/run_embryophyta_odb10"
OUTPUT_DIR="${PROJECT_DIR}/annotation/improvement/${SPECIES}"
FULL_TABLE="${BUSCO_DIR}/full_table.tsv"

mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "提取 ${SPECIES} 样本的问题BUSCO基因"
echo "=========================================="
echo ""

if [ ! -f "$FULL_TABLE" ]; then
    echo "错误: 文件不存在: $FULL_TABLE"
    exit 1
fi

# 提取片段化基因
echo "1. 提取片段化基因..."
FRAGMENTED_FILE="${OUTPUT_DIR}/fragmented_buscos.txt"
awk -F'\t' 'NR>3 && $2=="Fragmented" {print $1 "\t" $3 "\t" $5 "\t" $7}' "$FULL_TABLE" > "$FRAGMENTED_FILE"
FRAGMENTED_COUNT=$(wc -l < "$FRAGMENTED_FILE")
echo "   找到 $FRAGMENTED_COUNT 个片段化基因"
echo "   保存至: $FRAGMENTED_FILE"

# 提取缺失基因
echo ""
echo "2. 提取缺失基因..."
MISSING_FILE="${OUTPUT_DIR}/missing_busco_ids.txt"
awk -F'\t' 'NR>3 && $2=="Missing" {print $1}' "$FULL_TABLE" > "$MISSING_FILE"
MISSING_COUNT=$(wc -l < "$MISSING_FILE")
echo "   找到 $MISSING_COUNT 个缺失基因"
echo "   保存至: $MISSING_FILE"

# 提取片段化基因的序列ID
echo ""
echo "3. 提取片段化基因的序列ID..."
FRAGMENTED_GENES="${OUTPUT_DIR}/fragmented_gene_ids.txt"
awk -F'\t' 'NR>3 && $2=="Fragmented" && $3!="" {print $3}' "$FULL_TABLE" | sort -u > "$FRAGMENTED_GENES"
FRAGMENTED_GENES_COUNT=$(wc -l < "$FRAGMENTED_GENES")
echo "   找到 $FRAGMENTED_GENES_COUNT 个不同的基因"
echo "   保存至: $FRAGMENTED_GENES"

# 生成统计报告
echo ""
echo "4. 生成统计报告..."
STATS_FILE="${OUTPUT_DIR}/problematic_buscos_stats.txt"
{
    echo "=========================================="
    echo "${SPECIES} 样本问题BUSCO基因统计"
    echo "生成时间: $(date)"
    echo "=========================================="
    echo ""
    echo "片段化基因 (Fragmented): $FRAGMENTED_COUNT"
    echo "缺失基因 (Missing): $MISSING_COUNT"
    echo "总计: $((FRAGMENTED_COUNT + MISSING_COUNT))"
    echo ""
    echo "改进潜力:"
    echo "  如果修复所有片段化基因，完整度可提升约 $((FRAGMENTED_COUNT * 100 / 1614))%"
    echo ""
    echo "文件说明:"
    echo "  - fragmented_buscos.txt: 片段化BUSCO ID、基因ID、长度、描述"
    echo "  - missing_busco_ids.txt: 缺失的BUSCO ID列表"
    echo "  - fragmented_gene_ids.txt: 需要改进的基因ID列表"
} > "$STATS_FILE"
echo "   保存至: $STATS_FILE"

# 显示片段化基因的长度分布
echo ""
echo "5. 片段化基因长度统计..."
if [ $FRAGMENTED_COUNT -gt 0 ]; then
    awk -F'\t' 'NR>3 && $2=="Fragmented" && $5!="" {print $5}' "$FULL_TABLE" | \
    awk '{
        sum+=$1; count++; 
        if($1<min || min=="") min=$1; 
        if($1>max || max=="") max=$1
    } 
    END {
        if(count>0) {
            print "   平均长度: " int(sum/count) " aa"
            print "   最短: " min " aa"
            print "   最长: " max " aa"
        }
    }'
fi

echo ""
echo "=========================================="
echo "提取完成！"
echo "结果保存在: $OUTPUT_DIR"
echo "=========================================="

