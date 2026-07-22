#!/bin/bash
# 批量运行PAML codeml分析
# 日期: 2024-12-30

set -e

BASE_DIR="/path/to/project_root"
WORK_DIR="$BASE_DIR/comparative_genomics/06_selection"
ALIGN_DIR="$WORK_DIR/paml_alignments"
RESULTS_DIR="$WORK_DIR/paml_results"

echo "=========================================="
echo "批量运行PAML codeml分析"
echo "开始时间: $(date)"
echo "=========================================="

# 激活comparative环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

mkdir -p "$RESULTS_DIR"

# 检查codeml是否可用
if ! command -v codeml &> /dev/null; then
    echo "错误: codeml未找到，请安装PAML"
    echo "安装命令: conda install -c bioconda paml"
    exit 1
fi

# 处理每个基因家族（前10个）
count=0
success=0
failed=0

for og_dir in "$ALIGN_DIR"/OG*; do
    if [ $count -ge 10 ]; then
        break
    fi
    
    og_id=$(basename "$og_dir")
    ctl_file="$og_dir/codeml.ctl"
    phy_file="$og_dir/${og_id}.phy"
    
    if [ ! -f "$ctl_file" ] || [ ! -f "$phy_file" ]; then
        echo "跳过 $og_id: 缺少必要文件"
        continue
    fi
    
    echo ""
    echo "=========================================="
    echo "处理 $og_id ($((count+1))/10)..."
    echo "=========================================="
    
    cd "$og_dir"
    
    # 运行codeml
    echo "运行 codeml..."
    if codeml codeml.ctl > codeml.log 2>&1; then
        if [ -f "mlc" ]; then
            echo "  ✅ codeml完成"
            # 复制结果
            mkdir -p "$RESULTS_DIR/$og_id"
            cp mlc codeml.log "$RESULTS_DIR/$og_id/" 2>/dev/null || true
            success=$((success + 1))
        else
            echo "  ⚠️ codeml运行但未生成mlc文件"
            failed=$((failed + 1))
        fi
    else
        echo "  ❌ codeml运行失败，查看日志: codeml.log"
        failed=$((failed + 1))
    fi
    
    count=$((count + 1))
done

echo ""
echo "=========================================="
echo "PAML分析完成"
echo "成功: $success, 失败: $failed, 总计: $count"
echo "结束时间: $(date)"
echo "结果目录: $RESULTS_DIR"
echo "=========================================="

