#!/bin/bash

# 监控任务进度脚本

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"

echo "=========================================="
echo "任务进度监控"
echo "时间: $(date)"
echo "=========================================="
echo ""

echo "【转录组处理】"
echo "---"
if [ -d "${ANNOTATION_DIR}/T01/transcriptome" ]; then
    echo "T01转录组文件:"
    ls -lh "${ANNOTATION_DIR}/T01/transcriptome/" 2>/dev/null | grep -E "\.(fq|bam|gtf)" | wc -l && echo "个文件"
else
    echo "T01转录组处理尚未开始"
fi

if [ -d "${ANNOTATION_DIR}/T02/transcriptome" ]; then
    echo "T02转录组文件:"
    ls -lh "${ANNOTATION_DIR}/T02/transcriptome/" 2>/dev/null | grep -E "\.(fq|bam|gtf)" | wc -l && echo "个文件"
else
    echo "T02转录组处理尚未开始"
fi

echo ""
echo "【重复序列注释】"
echo "---"
if [ -d "${ANNOTATION_DIR}/T01/repeat" ]; then
    echo "T01重复序列文件:"
    ls -lh "${ANNOTATION_DIR}/T01/repeat/" 2>/dev/null | head -5
    if [ -f "${ANNOTATION_DIR}/T01/repeat/repeatmodeler.log" ]; then
        echo "RepeatModeler日志最后几行:"
        tail -5 "${ANNOTATION_DIR}/T01/repeat/repeatmodeler.log" 2>/dev/null
    fi
fi

if [ -d "${ANNOTATION_DIR}/T02/repeat" ]; then
    echo "T02重复序列文件:"
    ls -lh "${ANNOTATION_DIR}/T02/repeat/" 2>/dev/null | head -5
fi

echo ""
echo "【运行中的进程】"
echo "---"
ps aux | grep -E "RepeatModeler|hisat2|fastp|stringtie" | grep -v grep | head -5

echo ""
echo "=========================================="

