#!/usr/bin/env bash
# Phase 2: 用更新后的FMU(35,926基因)重跑OrthoFinder
# 预计运行 2-6 小时（120线程）
set -euo pipefail

BASE="/path/to/project_root/comparative_genomics"
LOGDIR="$BASE/logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/orthofinder_fmu_update_$(date +%Y%m%d_%H%M%S).log"

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate comparative

echo "=== Phase 2: 重跑 OrthoFinder ===" | tee "$LOG"
echo "输入: $BASE/01_proteomes_longest/ (15物种)" | tee -a "$LOG"
echo "FMU基因数: $(grep -c '^>' "$BASE/01_proteomes_longest/FMU.fa")" | tee -a "$LOG"
echo "开始时间: $(date)" | tee -a "$LOG"

# 备份旧结果
OF_OUT="$BASE/02_orthofinder_results_longest"
if [ -d "$OF_OUT" ]; then
    BACKUP="${OF_OUT}_backup_$(date +%Y%m%d_%H%M%S)"
    echo "备份旧结果: $BACKUP" | tee -a "$LOG"
    mv "$OF_OUT" "$BACKUP"
fi

# 运行OrthoFinder
python "/home/shenq/Biosofts/OrthoFinder_source/orthofinder.py" \
    -f "$BASE/01_proteomes_longest" \
    -t 120 -a 64 -S diamond -M msa \
    -o "$OF_OUT" 2>&1 | tee -a "$LOG"

# 输出摘要
RESULTS_DIR=$(ls -td "$OF_OUT"/Results_* 2>/dev/null | head -1)
if [ -n "$RESULTS_DIR" ]; then
    echo "" | tee -a "$LOG"
    echo "=== OrthoFinder 完成 ===" | tee -a "$LOG"
    echo "结果目录: $RESULTS_DIR" | tee -a "$LOG"
    echo "结束时间: $(date)" | tee -a "$LOG"

    # 关键统计
    SC_DIR="$RESULTS_DIR/Single_Copy_Orthologue_Sequences"
    if [ -d "$SC_DIR" ]; then
        SC_COUNT=$(ls "$SC_DIR"/*.fa 2>/dev/null | wc -l)
        echo "单拷贝直系同源基因数: $SC_COUNT (旧版仅33个)" | tee -a "$LOG"
    fi

    if [ -f "$RESULTS_DIR/Comparative_Genomics_Statistics/Statistics_Overall.tsv" ]; then
        echo "--- 总体统计 ---" | tee -a "$LOG"
        cat "$RESULTS_DIR/Comparative_Genomics_Statistics/Statistics_Overall.tsv" | tee -a "$LOG"
    fi
else
    echo "ERROR: 未找到结果目录" | tee -a "$LOG"
    exit 1
fi
