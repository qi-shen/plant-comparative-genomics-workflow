#!/bin/bash

# 检查正在运行的任务脚本

echo "=========================================="
echo "当前运行任务检查"
echo "时间: $(date)"
echo "=========================================="
echo ""

echo "【RepeatModeler进程】"
if ps aux | grep -q "[R]epeatModeler"; then
    echo "✓ RepeatModeler正在运行:"
    ps aux | grep "[R]epeatModeler" | grep -v grep | awk '{print "  PID: "$2", CPU: "$3"%, 内存: "$4"%, 运行时间: "$10}'
    
    echo ""
    echo "【T01 RepeatModeler日志最新内容】"
    tail -5 annotation/T01/repeat/repeatmodeler.log 2>/dev/null || echo "  日志文件不存在"
    
    echo ""
    echo "【T02 RepeatModeler日志最新内容】"
    tail -5 annotation/T02/repeat/repeatmodeler.log 2>/dev/null || echo "  日志文件不存在"
else
    echo "✗ RepeatModeler未运行"
fi

echo ""
echo "【其他可能运行的任务】"
ps aux | grep -E "[h]isat2|[f]astp|[s]tringtie|[G]eneMark|[a]ugustus|[b]usco" | head -5 || echo "  无其他相关任务运行"

echo ""
echo "【系统负载】"
uptime

echo ""
echo "=========================================="
