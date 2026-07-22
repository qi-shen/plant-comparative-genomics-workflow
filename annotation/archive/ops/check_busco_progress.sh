#!/bin/bash
# 检查BUSCO评估进度

PROJECT_DIR="/path/to/project_root"
BUSCO_DIR="${PROJECT_DIR}/annotation/evaluation/busco"

echo "=========================================="
echo "BUSCO评估进度检查"
echo "时间: $(date)"
echo "=========================================="
echo ""

# 检查进程
echo "【运行中的进程】"
ps aux | grep -E "conda.*busco|busco.*proteins" | grep -v grep | head -5
echo ""

# 检查输出目录
for species in "BH" "CK"; do
    result_dir="${BUSCO_DIR}/${species}"
    echo "【${species} 样本】"
    echo "输出目录: ${result_dir}"
    
    if [ -d "$result_dir" ]; then
        # 检查是否有结果文件
        short_summary=$(find "$result_dir" -name "short_summary.*.txt" | head -1)
        if [ -f "$short_summary" ]; then
            echo "状态: ✓ 已完成"
            echo "结果文件: $short_summary"
            echo "结果摘要:"
            grep -E "^C:|^F:|^M:" "$short_summary" | head -3
        else
            # 检查是否有运行中的文件
            if [ -f "${result_dir}/run_${species}/busco.log" ]; then
                echo "状态: 🔄 运行中"
                echo "最新日志:"
                tail -3 "${result_dir}/run_${species}/busco.log" 2>/dev/null || echo "  日志文件读取中..."
            else
                echo "状态: ⏳ 等待开始"
            fi
        fi
    else
        echo "状态: ⏳ 尚未开始"
    fi
    echo ""
done

echo "=========================================="
echo "提示: 使用以下命令查看详细日志"
echo "  tail -f ${PROJECT_DIR}/logs/busco_annotation_*.log"
echo "=========================================="

