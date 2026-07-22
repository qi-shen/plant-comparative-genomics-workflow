#!/bin/bash
# 等待BUSCO完成并生成最终报告

echo "等待BUSCO评估完成..."

# 等待BUSCO进程完成
while ps aux | grep -E "busco.*updated" | grep -v grep > /dev/null; do
    sleep 60
    echo "$(date '+%H:%M:%S') - BUSCO评估进行中..."
done

echo "BUSCO评估完成，生成最终报告..."

# 运行比较脚本
conda run -n annotation Rscript /path/to/project_root/scripts/compare_annotation_quality.R

# 更新最终报告
bash /path/to/project_root/scripts/generate_final_report.sh

echo "最终报告已生成！"
