#!/bin/bash
# 停止可视化任务
# 用途：安全停止正在运行的可视化任务

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$BASE_DIR/logs"
PID_FILE="$LOG_DIR/visualization.pid"

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

echo "正在停止可视化任务 (PID: $PID)..."
kill "$PID"

# 等待进程结束
sleep 2

if ps -p "$PID" > /dev/null 2>&1; then
    echo "强制停止..."
    kill -9 "$PID"
fi

rm -f "$PID_FILE"
echo "任务已停止"
