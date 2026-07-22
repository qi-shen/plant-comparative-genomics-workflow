#!/bin/bash
# 自动监控可视化任务进度
# 用途：定期检查并显示任务进度

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$BASE_DIR/logs"
PID_FILE="$LOG_DIR/visualization.pid"

INTERVAL=10  # 检查间隔（秒）

echo "=========================================="
echo "  可视化任务自动监控"
echo "=========================================="
echo "检查间隔: ${INTERVAL}秒"
echo "按 Ctrl+C 退出监控"
echo ""

while true; do
    clear
    echo "=========================================="
    echo "  可视化任务监控 - $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    if [ ! -f "$PID_FILE" ]; then
        echo "状态: 任务未运行"
        echo ""
        echo "启动任务:"
        echo "  bash scripts/run_visualizations_background.sh"
        break
    fi
    
    PID=$(cat "$PID_FILE")
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo "状态: 任务已完成"
        rm -f "$PID_FILE"
        
        # 显示最终统计
        LATEST_LOG=$(ls -t "$LOG_DIR"/visualization_*.log 2>/dev/null | head -1)
        if [ -f "$LATEST_LOG" ]; then
            echo ""
            echo "最终统计:"
            echo "----------------------------------------"
            grep -E "成功|失败|总计" "$LATEST_LOG" | tail -5
            echo "----------------------------------------"
        fi
        break
    fi
    
    LATEST_LOG=$(ls -t "$LOG_DIR"/visualization_*.log 2>/dev/null | head -1)
    
    if [ -f "$LATEST_LOG" ]; then
        echo "进程ID (PID): $PID"
        echo "日志文件: $LATEST_LOG"
        echo ""
        echo "最近输出 (最后15行):"
        echo "----------------------------------------"
        tail -15 "$LATEST_LOG"
        echo "----------------------------------------"
        echo ""
        
        # 统计进度
        SUCCESS=$(grep -c "✓" "$LATEST_LOG" 2>/dev/null || echo "0")
        FAIL=$(grep -c "✗" "$LATEST_LOG" 2>/dev/null || echo "0")
        CURRENT=$(grep -oE "\[[0-9]+/[0-9]+\]" "$LATEST_LOG" | tail -1 || echo "")
        
        echo "进度统计:"
        echo "  当前步骤: $CURRENT"
        echo "  成功: $SUCCESS"
        echo "  失败: $FAIL"
        echo ""
        
        # 检查生成的图片数量
        TOTAL_FIGURES=0
        for dir in "$BASE_DIR"/*/figures; do
            if [ -d "$dir" ]; then
                count=$(find "$dir" -name "*.pdf" -o -name "*.png" 2>/dev/null | wc -l)
                TOTAL_FIGURES=$((TOTAL_FIGURES + count))
            fi
        done
        echo "  已生成图片: $TOTAL_FIGURES 个"
    fi
    
    echo ""
    echo "下次更新: ${INTERVAL}秒后 (按 Ctrl+C 退出)"
    sleep "$INTERVAL"
done
