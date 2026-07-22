#!/bin/bash
# 后台运行所有可视化脚本
# 用途：在后台执行可视化任务，并记录日志

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/visualization_$(date +%Y%m%d_%H%M%S).log"
PID_FILE="$LOG_DIR/visualization.pid"

# 创建日志目录
mkdir -p "$LOG_DIR"

# 检查是否已有任务在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "警告: 已有可视化任务在运行 (PID: $OLD_PID)"
        echo "如需重新运行，请先停止现有任务: kill $OLD_PID"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# 检查conda环境
if command -v conda &> /dev/null; then
    echo "检测到conda环境，使用conda中的R"
    R_CMD="conda run -n base Rscript"
else
    echo "使用系统R"
    R_CMD="Rscript"
fi

# 启动后台任务
echo "=========================================="
echo "  启动比较基因组分析可视化任务"
echo "=========================================="
echo "日志文件: $LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

cd "$BASE_DIR"

# 后台运行并记录PID
nohup $R_CMD scripts/run_all_visualizations.R > "$LOG_FILE" 2>&1 &
PID=$!

# 保存PID
echo $PID > "$PID_FILE"

echo "任务已在后台启动"
echo "进程ID (PID): $PID"
echo "日志文件: $LOG_FILE"
echo ""
echo "监控进度命令:"
echo "  tail -f $LOG_FILE"
echo "  或运行: bash scripts/monitor_visualization.sh"
echo ""
echo "停止任务命令:"
echo "  kill $PID"
echo "  或运行: bash scripts/stop_visualization.sh"
