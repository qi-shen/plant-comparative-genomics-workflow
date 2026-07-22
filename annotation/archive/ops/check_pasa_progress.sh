#!/bin/bash

# 检查PASA运行进度

PROJECT_DIR="/path/to/project_root"
SPECIES=${1:-"T01"}

PASA_CONF_DIR="${PROJECT_DIR}/annotation/${SPECIES}/pasa_update"
LOG_FILE="${PROJECT_DIR}/logs/pasa_update_${SPECIES}_*.log"

echo "=========================================="
echo "PASA运行进度检查 - ${SPECIES}样本"
echo "时间: $(date)"
echo "=========================================="
echo ""

# 检查进程
echo "【运行中的进程】"
PASA_PROCESSES=$(ps aux | grep -E "PASA|pasa_update|Launch_PASA" | grep -v grep)
if [ -n "$PASA_PROCESSES" ]; then
    echo "$PASA_PROCESSES" | head -5
    echo ""
    echo "✓ PASA正在运行"
else
    echo "✗ 未找到运行中的PASA进程"
fi
echo ""

# 检查日志文件
echo "【最新日志】"
LATEST_LOG=$(ls -t ${PROJECT_DIR}/logs/pasa_update_${SPECIES}_*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ] && [ -f "$LATEST_LOG" ]; then
    echo "日志文件: $LATEST_LOG"
    echo "文件大小: $(du -h "$LATEST_LOG" | cut -f1)"
    echo ""
    echo "最后10行:"
    tail -10 "$LATEST_LOG"
else
    echo "未找到日志文件"
fi
echo ""

# 检查输出目录
echo "【输出目录】"
if [ -d "$PASA_CONF_DIR" ]; then
    echo "目录: $PASA_CONF_DIR"
    echo "文件数: $(find "$PASA_CONF_DIR" -type f | wc -l)"
    echo ""
    echo "主要文件:"
    ls -lh "$PASA_CONF_DIR" 2>/dev/null | grep -E "\.gff3|\.sqlite|\.log|pasa" | head -10
    
    # 检查是否有输出文件
    if [ -f "${PASA_CONF_DIR}/pasa_assemblies.gff3" ] || [ -f "${PASA_CONF_DIR}/${SPECIES}_pasa_updated.gff3" ]; then
        echo ""
        echo "✓ 找到PASA输出文件"
    fi
else
    echo "输出目录不存在: $PASA_CONF_DIR"
fi
echo ""

# 检查数据库文件
echo "【数据库文件】"
DB_FILE="${PASA_CONF_DIR}/${SPECIES}_pasa.sqlite"
if [ -f "$DB_FILE" ]; then
    echo "数据库: $DB_FILE"
    echo "大小: $(du -h "$DB_FILE" | cut -f1)"
    echo "✓ 数据库文件存在"
else
    echo "数据库文件尚未创建"
fi
echo ""

echo "=========================================="
echo "提示:"
echo "  实时监控: tail -f $LATEST_LOG"
echo "  查看进程: ps aux | grep PASA"
echo "=========================================="

