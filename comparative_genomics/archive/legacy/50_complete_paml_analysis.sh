#!/bin/bash
# 完成剩余的PAML分析

set -e

SELECTION_DIR="/path/to/project_root/comparative_genomics/06_selection"
PAML_DIR="${SELECTION_DIR}/paml_alignments"
LOG_DIR="${SELECTION_DIR}/logs"
mkdir -p "$LOG_DIR"

# 激活conda环境
source $(conda info --base)/etc/profile.d/conda.sh
conda activate comparative

echo "============================================================"
echo "完成剩余PAML分析"
echo "============================================================"

# 查找未完成的家族
incomplete_families=()
for dir in "$PAML_DIR"/OG*; do
    if [ -d "$dir" ]; then
        family=$(basename "$dir")
        if [ ! -f "$dir/mlc" ] || [ ! -s "$dir/mlc" ]; then
            incomplete_families+=("$family")
        fi
    fi
done

echo "未完成的家族数: ${#incomplete_families[@]}"

if [ ${#incomplete_families[@]} -eq 0 ]; then
    echo "所有家族已完成分析"
    exit 0
fi

# 显示前10个
echo "前10个未完成的家族:"
for i in "${!incomplete_families[@]}"; do
    if [ $i -lt 10 ]; then
        echo "  ${incomplete_families[$i]}"
    fi
done

# 批量运行codeml（每次处理10个）
batch_size=10
total=${#incomplete_families[@]}
processed=0

for ((i=0; i<total; i+=batch_size)); do
    batch_end=$((i+batch_size-1))
    if [ $batch_end -ge $total ]; then
        batch_end=$((total-1))
    fi
    
    echo ""
    echo "处理批次 $((i/batch_size+1)): 家族 $((i+1))-$((batch_end+1)) / $total"
    
    for ((j=i; j<=batch_end; j++)); do
        family="${incomplete_families[$j]}"
        family_dir="$PAML_DIR/$family"
        
        if [ ! -d "$family_dir" ]; then
            continue
        fi
        
        # 检查必要文件
        if [ ! -f "$family_dir/codon_aln.phy" ] || [ ! -f "$family_dir/tree.nwk" ]; then
            echo "  ⚠️  $family: 缺少必要文件，跳过"
            continue
        fi
        
        # 运行codeml
        echo "  🔄 处理 $family..."
        (
            cd "$family_dir"
            if codeml codeml.ctl > "${LOG_DIR}/${family}.log" 2>&1; then
                if [ -f "mlc" ] && [ -s "mlc" ]; then
                    echo "  ✅ $family: 完成"
                else
                    echo "  ❌ $family: mlc文件为空"
                fi
            else
                echo "  ❌ $family: codeml运行失败"
            fi
        ) &
        
        # 限制并发数
        if (( (j-i+1) % 5 == 0 )); then
            wait
        fi
    done
    
    wait
    processed=$((batch_end+1))
    echo "进度: $processed / $total ($((processed*100/total))%)"
done

echo ""
echo "============================================================"
echo "PAML分析完成"
echo "============================================================"

# 统计完成情况
completed=0
for dir in "$PAML_DIR"/OG*; do
    if [ -d "$dir" ] && [ -f "$dir/mlc" ] && [ -s "$dir/mlc" ]; then
        ((completed++))
    fi
done

echo "已完成家族数: $completed"
echo "总家族数: $(ls -d "$PAML_DIR"/OG* 2>/dev/null | wc -l)"

