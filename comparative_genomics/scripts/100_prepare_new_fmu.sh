#!/bin/bash
# Phase 0: 准备新版C08(FMU) HR基因组数据
# 替换旧版 AYY 84,768基因 → 新版 35,926基因
set -euo pipefail

BASE="/path/to/project_root"
FMU_SRC="$BASE/HR_genome/19720381"
FMU_STAGE="$BASE/comparative_genomics/fmu_new"
PROTEOME_DIR="$BASE/comparative_genomics/01_proteomes"

echo "=== Phase 0: 准备新版 FMU 数据 ==="
echo "源数据: $FMU_SRC"
echo "暂存区: $FMU_STAGE"

# Step 1: 解压
mkdir -p "$FMU_STAGE"
echo "[1/4] 解压蛋白序列..."
zcat "$FMU_SRC/Fmu.pep.fa.gz" > "$FMU_STAGE/Fmu.pep.fa"

# Step 2: 验证基因数
GENE_COUNT=$(grep -c '^>' "$FMU_STAGE/Fmu.pep.fa")
echo "[2/4] 新FMU基因数: $GENE_COUNT (预期 35,926)"
if [ "$GENE_COUNT" -lt 30000 ] || [ "$GENE_COUNT" -gt 40000 ]; then
    echo "ERROR: 基因数异常，请检查输入文件"
    exit 1
fi

# Step 3: 备份旧文件
if [ -f "$PROTEOME_DIR/FMU.fa" ] && [ ! -f "$PROTEOME_DIR/FMU.fa.old_84768" ]; then
    echo "[3/4] 备份旧FMU蛋白质组..."
    OLD_COUNT=$(grep -c '^>' "$PROTEOME_DIR/FMU.fa")
    cp "$PROTEOME_DIR/FMU.fa" "$PROTEOME_DIR/FMU.fa.old_${OLD_COUNT}"
    echo "  旧文件已备份: FMU.fa.old_${OLD_COUNT} ($OLD_COUNT 条序列)"
else
    echo "[3/4] 旧文件已备份或不存在，跳过"
fi

# Step 4: 添加 FMU_ 前缀并替换
echo "[4/4] 添加 FMU_ 前缀，生成新蛋白质组..."
awk '/^>/{sub(/^>/, ">FMU_"); print; next} {print}' "$FMU_STAGE/Fmu.pep.fa" \
    > "$PROTEOME_DIR/FMU.fa"

# 验证结果
NEW_COUNT=$(grep -c '^>' "$PROTEOME_DIR/FMU.fa")
echo ""
echo "=== 完成 ==="
echo "新FMU蛋白质组: $PROTEOME_DIR/FMU.fa"
echo "序列数: $NEW_COUNT"
echo "示例ID: $(grep '^>' "$PROTEOME_DIR/FMU.fa" | head -3)"
