#!/bin/bash
# 整理15个物种的蛋白质序列到统一目录
# 日期: 2024-12-29

set -e
cd /path/to/project_root

# 创建输出目录
OUTDIR="comparative_genomics/01_proteomes"
mkdir -p $OUTDIR

echo "=========================================="
echo "整理15个物种蛋白质序列"
echo "=========================================="

# 定义物种信息: 物种代码 | 蛋白文件路径
declare -A SPECIES=(
    ["BH"]="new_anno/BH.final.pep.fa"
    ["CK"]="new_anno/CK.final.pep.fa"
    ["TAU"]="old_reults/results/C02/tau.longest_pep.fasta"
    ["TCH"]="old_reults/results/C03/Tchinensis_pep.fa"
    ["RSO"]="old_reults/results/C01/C01.pep.fa"
    ["CQU"]="old_reults/results/C05/0321072RM_v1-prot.fasta"
    ["GPA"]="old_reults/results/C07/Gpan_WG.pep"
    ["APA"]="old_reults/results/C04/Haplome_1/C04_hap1.proteins.fa.fasta"
    ["FMU"]="old_reults/results/C08/AYY.gene.rename.pep.fa"
    ["HAM"]="old_reults/results/C09/protein.fasta"
    ["POL"]="old_reults/results/C10/GWHCBIU00000000.Protein.faa"
    ["DCA"]="old_reults/results/C06/C06_hap1.pep.fa"
    ["SMO"]="old_reults/results/C11/hap1_prot.fa"
    ["ATH"]="old_reults/results/O01/O01.pep.fa"
    ["VVI"]="old_reults/results/O02/O02.pep.fa"
)

# 物种中文名映射
declare -A SPECIES_CN=(
    ["BH"]="目标种BH"
    ["CK"]="目标种CK"
    ["TAU"]="C02"
    ["TCH"]="C03"
    ["RSO"]="C01"
    ["CQU"]="C05"
    ["GPA"]="C07"
    ["APA"]="C04"
    ["FMU"]="C08"
    ["HAM"]="C09"
    ["POL"]="C10"
    ["DCA"]="C06"
    ["SMO"]="C11"
    ["ATH"]="O01"
    ["VVI"]="O02"
)

# 处理每个物种
for sp in "${!SPECIES[@]}"; do
    src="${SPECIES[$sp]}"
    dst="$OUTDIR/${sp}.fa"
    
    echo "处理 $sp (${SPECIES_CN[$sp]})..."
    
    if [ -f "$src" ]; then
        # 复制并重命名序列ID (添加物种前缀)，同时清理无效字符（如"."）
        awk -v sp="$sp" '
            /^>/{gsub(/^>/, ">" sp "_"); print; next}
            {gsub(/\./, ""); gsub(/\*/, ""); print}
        ' "$src" > "$dst"

        # 统计序列数
        count=$(grep -c '^>' "$dst")
        echo "  - 序列数: $count"
    else
        echo "  - 警告: 文件不存在 $src"
    fi
done

echo ""
echo "=========================================="
echo "统计蛋白质序列文件"
echo "=========================================="
echo ""

# 生成统计表
echo -e "物种代码\t中文名\t序列数\t文件大小" > "$OUTDIR/proteome_stats.tsv"
for sp in BH CK TAU TCH RSO CQU GPA APA FMU HAM POL DCA SMO ATH VVI; do
    if [ -f "$OUTDIR/${sp}.fa" ]; then
        count=$(grep -c '^>' "$OUTDIR/${sp}.fa")
        size=$(ls -lh "$OUTDIR/${sp}.fa" | awk '{print $5}')
        echo -e "${sp}\t${SPECIES_CN[$sp]}\t${count}\t${size}" >> "$OUTDIR/proteome_stats.tsv"
    fi
done

cat "$OUTDIR/proteome_stats.tsv"

echo ""
echo "=========================================="
echo "蛋白质序列整理完成!"
echo "输出目录: $OUTDIR"
echo "=========================================="

