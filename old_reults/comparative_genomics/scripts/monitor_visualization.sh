#!/bin/bash
# 监控可视化任务进度
# 用途：实时查看可视化任务的执行进度

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$BASE_DIR/logs"
PID_FILE="$LOG_DIR/visualization.pid"

# 检查任务是否在运行
if [ ! -f "$PID_FILE" ]; then
    echo "没有找到运行中的可视化任务"
    exit 1
fi

PID=$(cat "$PID_FILE")
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "任务已完成或已停止 (PID: $PID)"
    rm -f "$PID_FILE"
    exit 0
fi

# 查找最新的日志文件
LATEST_LOG=$(ls -t "$LOG_DIR"/visualization_*.log 2>/dev/null | head -1)

if [ -z "$LATEST_LOG" ]; then
    echo "未找到日志文件"
    exit 1
fi

echo "=========================================="
echo "  可视化任务监控"
echo "=========================================="
echo "进程ID (PID): $PID"
echo "日志文件: $LATEST_LOG"
echo "状态: 运行中"
echo ""
echo "最近输出 (最后20行):"
echo "----------------------------------------"
tail -20 "$LATEST_LOG"
echo "----------------------------------------"
echo ""
echo "实时监控 (Ctrl+C 退出):"
echo "----------------------------------------"

# 实时跟踪日志
tail -f "$LATEST_LOG"
