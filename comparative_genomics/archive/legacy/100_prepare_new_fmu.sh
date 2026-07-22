#!/bin/bash
# Phase 0: 准备新版C08(C08) HR基因组数据
# 替换旧版 C08 84,768基因 → 新版 35,926基因
set -euo pipefail

BASE="/path/to/project_root"
C08_SRC="$BASE/HR_genome/19720381"
C08_STAGE="$BASE/comparative_genomics/fmu_new"
PROTEOME_DIR="$BASE/comparative_genomics/01_proteomes"

echo "=== Phase 0: 准备新版 C08 数据 ==="
echo "源数据: $C08_SRC"
echo "暂存区: $C08_STAGE"

# Step 1: 解压
mkdir -p "$C08_STAGE"
echo "[1/4] 解压蛋白序列..."
zcat "$C08_SRC/C08.pep.fa.gz" > "$C08_STAGE/C08.pep.fa"

# Step 2: 验证基因数
GENE_COUNT=$(grep -c '^>' "$C08_STAGE/C08.pep.fa")
echo "[2/4] 新C08基因数: $GENE_COUNT (预期 35,926)"
if [ "$GENE_COUNT" -lt 30000 ] || [ "$GENE_COUNT" -gt 40000 ]; then
    echo "ERROR: 基因数异常，请检查输入文件"
    exit 1
fi

# Step 3: 备份旧文件
if [ -f "$PROTEOME_DIR/C08.fa" ] && [ ! -f "$PROTEOME_DIR/C08.fa.old_84768" ]; then
    echo "[3/4] 备份旧C08蛋白质组..."
    OLD_COUNT=$(grep -c '^>' "$PROTEOME_DIR/C08.fa")
    cp "$PROTEOME_DIR/C08.fa" "$PROTEOME_DIR/C08.fa.old_${OLD_COUNT}"
    echo "  旧文件已备份: C08.fa.old_${OLD_COUNT} ($OLD_COUNT 条序列)"
else
    echo "[3/4] 旧文件已备份或不存在，跳过"
fi

# Step 4: 添加 C08_ 前缀并替换
echo "[4/4] 添加 C08_ 前缀，生成新蛋白质组..."
awk '/^>/{sub(/^>/, ">C08_"); print; next} {print}' "$C08_STAGE/C08.pep.fa" \
    > "$PROTEOME_DIR/C08.fa"

# 验证结果
NEW_COUNT=$(grep -c '^>' "$PROTEOME_DIR/C08.fa")
echo ""
echo "=== 完成 ==="
echo "新C08蛋白质组: $PROTEOME_DIR/C08.fa"
echo "序列数: $NEW_COUNT"
echo "示例ID: $(grep '^>' "$PROTEOME_DIR/C08.fa" | head -3)"
