#!/bin/bash
# 可视化任务总结报告
# 用途：生成可视化任务的完成情况报告

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  比较基因组分析可视化任务总结报告"
echo "=========================================="
echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 统计各部分的图片数量
echo "各分析部分生成的图片统计:"
echo "----------------------------------------"
TOTAL=0
for dir in "$BASE_DIR"/*/figures; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "*.pdf" -o -name "*.png" 2>/dev/null | wc -l)
        if [ "$count" -gt 0 ]; then
            dirname=$(basename "$(dirname "$dir")")
            echo "  $dirname: $count 个文件"
            TOTAL=$((TOTAL + count))
        fi
    fi
done
echo "----------------------------------------"
echo "总计: $TOTAL 个图片文件"
echo ""

# 列出所有PDF文件
echo "PDF文件列表:"
echo "----------------------------------------"
find "$BASE_DIR" -path "*/figures/*.pdf" | while read file; do
    echo "  $(basename $(dirname $(dirname $file)))/figures/$(basename $file)"
done | head -20
if [ $(find "$BASE_DIR" -path "*/figures/*.pdf" | wc -l) -gt 20 ]; then
    echo "  ... (还有更多文件)"
fi
echo ""

# 列出所有PNG文件
echo "PNG文件列表:"
echo "----------------------------------------"
find "$BASE_DIR" -path "*/figures/*.png" | while read file; do
    echo "  $(basename $(dirname $(dirname $file)))/figures/$(basename $file)"
done | head -20
if [ $(find "$BASE_DIR" -path "*/figures/*.png" | wc -l) -gt 20 ]; then
    echo "  ... (还有更多文件)"
fi
echo ""

echo "所有图片文件已保存在各分析目录的 figures/ 子目录中"
echo ""
