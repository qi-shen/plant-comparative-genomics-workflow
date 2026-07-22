#!/bin/bash

# 使用优化参数重启RepeatModeler

set -e

PROJECT_DIR="/path/to/project_root"
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

# 重启BH RepeatModeler
echo "【重启BH RepeatModeler】"
cd "${ANNOTATION_DIR}/BH/repeat"

if [ "$USE_LTR" = "true" ]; then
    nohup RepeatModeler -database BH_genome -LTRStruct -threads "$THREADS" > repeatmodeler.log 2>&1 &
else
    nohup RepeatModeler -database BH_genome -threads "$THREADS" > repeatmodeler.log 2>&1 &
fi

BH_PID=$!
echo "✓ BH RepeatModeler已启动，PID: $BH_PID"
sleep 2

# 重启CK RepeatModeler
echo ""
echo "【重启CK RepeatModeler】"
cd "${ANNOTATION_DIR}/CK/repeat"

if [ "$USE_LTR" = "true" ]; then
    nohup RepeatModeler -database CK_genome -LTRStruct -threads "$THREADS" > repeatmodeler.log 2>&1 &
else
    nohup RepeatModeler -database CK_genome -threads "$THREADS" > repeatmodeler.log 2>&1 &
fi

CK_PID=$!
echo "✓ CK RepeatModeler已启动，PID: $CK_PID"
sleep 2

# 验证
echo ""
echo "【验证运行状态】"
ps aux | grep "[R]epeatModeler" | grep -v grep

echo ""
echo "【日志检查】"
echo "BH日志:"
tail -5 "${ANNOTATION_DIR}/BH/repeat/repeatmodeler.log" 2>/dev/null || echo "  日志文件尚未生成"
echo ""
echo "CK日志:"
tail -5 "${ANNOTATION_DIR}/CK/repeat/repeatmodeler.log" 2>/dev/null || echo "  日志文件尚未生成"

echo ""
echo "=========================================="
echo "优化重启完成"
echo "监控命令: bash scripts/check_running_tasks.sh"
echo "=========================================="

