#!/bin/bash
# 检查可视化任务状态
# 用途：快速查看任务运行状态和进度

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$BASE_DIR/logs"
PID_FILE="$LOG_DIR/visualization.pid"

echo "=========================================="
echo "  可视化任务状态检查"
echo "=========================================="
echo ""

# 检查任务是否在运行
if [ ! -f "$PID_FILE" ]; then
    echo "状态: 未运行"
    echo ""
    echo "启动任务:"
    echo "  bash scripts/run_visualizations_background.sh"
    exit 0
fi

PID=$(cat "$PID_FILE")
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "状态: 已完成或已停止"
    rm -f "$PID_FILE"
    exit 0
fi

# 查找最新的日志文件
LATEST_LOG=$(ls -t "$LOG_DIR"/visualization_*.log 2>/dev/null | head -1)

echo "状态: 运行中"
echo "进程ID (PID): $PID"
echo "日志文件: $LATEST_LOG"
echo ""

# 检查已完成的步骤
if [ -f "$LATEST_LOG" ]; then
    echo "执行进度:"
    echo "----------------------------------------"
    grep -E "\[.*/.*\]|✓|✗|成功|失败" "$LATEST_LOG" | tail -10
    echo "----------------------------------------"
    echo ""
    
    # 统计成功和失败
    SUCCESS=$(grep -c "✓" "$LATEST_LOG" 2>/dev/null || echo "0")
    FAIL=$(grep -c "✗" "$LATEST_LOG" 2>/dev/null || echo "0")
    
    echo "统计:"
    echo "  成功: $SUCCESS"
    echo "  失败: $FAIL"
    echo ""
    
    # 检查生成的图片
    echo "已生成的图片:"
    for dir in "$BASE_DIR"/*/figures; do
        if [ -d "$dir" ]; then
            count=$(find "$dir" -name "*.pdf" -o -name "*.png" 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                dirname=$(basename "$(dirname "$dir")")
                echo "  $dirname: $count 个文件"
            fi
        fi
    done
    echo ""
fi

echo "查看实时日志:"
echo "  tail -f $LATEST_LOG"
echo "  或运行: bash scripts/monitor_visualization.sh"
echo ""
echo "停止任务:"
echo "  bash scripts/stop_visualization.sh"
