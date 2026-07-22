#!/bin/bash

# 使用优化参数重启RepeatModeler

set -e

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
THREADS=32  # 增加到32线程
USE_LTR=true  # 设置为false可以加速，但会减少LTR分析

source ~/miniconda3/etc/profile.d/conda.sh
conda activate base

echo "=========================================="
echo "使用优化参数重启RepeatModeler"
echo "线程数: $THREADS"
echo "LTR分析: $USE_LTR"
echo "=========================================="
echo ""

# 停止当前运行的RepeatModeler
echo "【停止当前任务】"
for pid in $(ps aux | grep "[R]epeatModeler" | grep -v grep | awk '{print $2}'); do
    echo "停止进程: $pid"
    kill $pid 2>/dev/null || true
done

sleep 5

# 检查是否已停止
if ps aux | grep -q "[R]epeatModeler"; then
    echo "⚠️ 部分进程仍在运行，强制停止..."
    pkill -f RepeatModeler || true
    sleep 3
fi

echo "✓ 已停止"
echo ""

# 重启T01 RepeatModeler
echo "【重启T01 RepeatModeler】"
cd "${ANNOTATION_DIR}/T01/repeat"

if [ "$USE_LTR" = "true" ]; then
    nohup RepeatModeler -database T01_genome -LTRStruct -threads "$THREADS" > repeatmodeler.log 2>&1 &
else
    nohup RepeatModeler -database T01_genome -threads "$THREADS" > repeatmodeler.log 2>&1 &
fi

T01_PID=$!
echo "✓ T01 RepeatModeler已启动，PID: $T01_PID"
sleep 2

# 重启T02 RepeatModeler
echo ""
echo "【重启T02 RepeatModeler】"
cd "${ANNOTATION_DIR}/T02/repeat"

if [ "$USE_LTR" = "true" ]; then
    nohup RepeatModeler -database T02_genome -LTRStruct -threads "$THREADS" > repeatmodeler.log 2>&1 &
else
    nohup RepeatModeler -database T02_genome -threads "$THREADS" > repeatmodeler.log 2>&1 &
fi

T02_PID=$!
echo "✓ T02 RepeatModeler已启动，PID: $T02_PID"
sleep 2

# 验证
echo ""
echo "【验证运行状态】"
ps aux | grep "[R]epeatModeler" | grep -v grep

echo ""
echo "【日志检查】"
echo "T01日志:"
tail -5 "${ANNOTATION_DIR}/T01/repeat/repeatmodeler.log" 2>/dev/null || echo "  日志文件尚未生成"
echo ""
echo "T02日志:"
tail -5 "${ANNOTATION_DIR}/T02/repeat/repeatmodeler.log" 2>/dev/null || echo "  日志文件尚未生成"

echo ""
echo "=========================================="
echo "优化重启完成"
echo "监控命令: bash scripts/check_running_tasks.sh"
echo "=========================================="

