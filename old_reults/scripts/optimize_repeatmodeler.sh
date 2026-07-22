#!/bin/bash

# RepeatModeler优化和加速脚本

set -e

PROJECT_DIR="/path/to/project_root"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"

echo "=========================================="
echo "RepeatModeler优化方案"
echo "=========================================="
echo ""

# 检查当前运行状态
echo "【当前运行状态】"
if ps aux | grep -q "[R]epeatModeler"; then
    echo "✓ RepeatModeler正在运行"
    ps aux | grep "[R]epeatModeler" | grep -v grep | awk '{print "  PID: "$2", 线程参数: "$0}'
else
    echo "✗ RepeatModeler未运行"
fi

echo ""
echo "【系统资源】"
echo "CPU核心数: $(nproc)"
echo "可用内存: $(free -h | grep Mem | awk '{print $7}')"
echo "当前负载: $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "【优化建议】"
echo ""

# 1. 增加线程数
echo "1. 增加线程数（推荐）"
echo "   当前: 8线程"
echo "   建议: 32-64线程（系统有128核心）"
echo "   方法: 停止当前任务，使用更多线程重启"
echo "   命令: RepeatModeler -database <db> -LTRStruct -threads 32"
echo ""

# 2. 检查存储速度
echo "2. 存储优化"
echo "   检查工作目录存储类型:"
df -h "$ANNOTATION_DIR" | tail -1
echo "   建议: 使用SSD或快速存储"
echo ""

# 3. 减少LTR分析（可选）
echo "3. 移除LTR结构分析（如果不需要）"
echo "   当前: 使用 -LTRStruct（较慢但更全面）"
echo "   加速: 移除 -LTRStruct 参数可加速约30-50%"
echo "   权衡: 可能遗漏部分LTR重复序列"
echo ""

# 4. 使用更快的BLAST引擎
echo "4. BLAST引擎优化"
echo "   检查当前使用的引擎:"
if command -v rmblastn &> /dev/null; then
    echo "   ✓ rmblastn可用"
else
    echo "   ⚠️ 检查BLAST配置"
fi
echo ""

# 5. 并行策略
echo "5. 并行运行策略"
echo "   当前: BH和CK同时运行"
echo "   建议: 如果系统资源充足，可以增加更多并行任务"
echo "   注意: 监控系统负载，避免过载"
echo ""

echo "【立即优化操作】"
echo "如果要立即优化，可以："
echo "1. 停止当前任务（kill <PID>）"
echo "2. 使用更多线程重启（-threads 32 或 64）"
echo "3. 如果不需要LTR分析，移除 -LTRStruct 参数"
echo ""

echo "=========================================="

