#!/bin/bash
# 准备PASA更新注释的交付包

DELIVERY_DIR="${PROJECT_ROOT}/annotation/delivery_pasa_update"
SRC_DIR="${PROJECT_ROOT}/annotation"

echo "开始准备交付包..."

# 复制T01样本文件
echo "整理T01样本文件..."
cp "$SRC_DIR/T01/pasa_update/T01_pasa.pasa_assemblies.gff3" \
   "$DELIVERY_DIR/T01/annotations/gff3/T01_pasa_updated.gff3"
cp "$SRC_DIR/T01/pasa_update/T01_pasa.pasa_assemblies.gtf" \
   "$DELIVERY_DIR/T01/annotations/gtf/T01_pasa_updated.gtf"
cp "$SRC_DIR/T01/pasa_update/T01_pasa.assemblies.fasta" \
   "$DELIVERY_DIR/T01/annotations/sequences/T01_pasa_assemblies.fasta"
cp "$SRC_DIR/T01/pasa_update/T01_pasa_updated_filtered.pep.fa" \
   "$DELIVERY_DIR/T01/annotations/proteins/T01_pasa_updated_proteins.faa"

# 复制T02样本文件
echo "整理T02样本文件..."
cp "$SRC_DIR/T02/pasa_update/T02_pasa.pasa_assemblies.gff3" \
   "$DELIVERY_DIR/T02/annotations/gff3/T02_pasa_updated.gff3"
cp "$SRC_DIR/T02/pasa_update/T02_pasa.pasa_assemblies.gtf" \
   "$DELIVERY_DIR/T02/annotations/gtf/T02_pasa_updated.gtf"
cp "$SRC_DIR/T02/pasa_update/T02_pasa.assemblies.fasta" \
   "$DELIVERY_DIR/T02/annotations/sequences/T02_pasa_assemblies.fasta"
cp "$SRC_DIR/T02/pasa_update/T02_pasa_updated_filtered.pep.fa" \
   "$DELIVERY_DIR/T02/annotations/proteins/T02_pasa_updated_proteins.faa"

# 复制质量评估报告
echo "复制质量评估报告..."
mkdir -p "$DELIVERY_DIR/reports"
cp "$SRC_DIR/../annotation/evaluation/pasa_final_comparison_report.md" \
   "$DELIVERY_DIR/reports/quality_assessment_report.md"
cp "$SRC_DIR/../annotation/evaluation/busco_comparison.pdf" \
   "$DELIVERY_DIR/reports/busco_comparison.pdf" 2>/dev/null || echo "PDF文件不存在，跳过"

# 复制BUSCO评估结果
echo "复制BUSCO评估结果..."
mkdir -p "$DELIVERY_DIR/reports/busco"
for species in T01 T02; do
  cp "$SRC_DIR/../annotation/evaluation/busco_updated/${species}/${species}/short_summary.specific.embryophyta_odb10.${species}.txt" \
     "$DELIVERY_DIR/reports/busco/${species}_busco_updated.txt" 2>/dev/null || echo "${species} BUSCO结果不存在"
  cp "$SRC_DIR/../annotation/evaluation/busco/${species}"/*/short_summary*.txt \
     "$DELIVERY_DIR/reports/busco/${species}_busco_original.txt" 2>/dev/null || echo "${species} 原始BUSCO结果不存在"
done

echo "文件复制完成！"

# 生成文件清单
echo "生成文件清单..."
cat > "$DELIVERY_DIR/file_list.txt" << 'EOF'
PASA更新注释交付包文件清单
生成时间: $(date '+%Y-%m-%d %H:%M:%S')

目录结构:
==========================================

T01/
  annotations/
    gff3/          - GFF3格式注释文件
    gtf/           - GTF格式注释文件
    sequences/     - 转录本序列FASTA文件
    proteins/      - 蛋白质序列FASTA文件

T02/
  annotations/
    gff3/          - GFF3格式注释文件
    gtf/           - GTF格式注释文件
    sequences/     - 转录本序列FASTA文件
    proteins/      - 蛋白质序列FASTA文件

reports/
  quality_assessment_report.md  - 质量评估报告
  busco_comparison.pdf          - BUSCO比较图表
  busco/                        - BUSCO评估结果

文件说明:
==========================================

T01样本:
  - T01_pasa_updated.gff3          GFF3格式注释文件
  - T01_pasa_updated.gtf           GTF格式注释文件
  - T01_pasa_assemblies.fasta      转录本序列
  - T01_pasa_updated_proteins.faa  蛋白质序列

T02样本:
  - T02_pasa_updated.gff3          GFF3格式注释文件
  - T02_pasa_updated.gtf           GTF格式注释文件
  - T02_pasa_assemblies.fasta      转录本序列
  - T02_pasa_updated_proteins.faa  蛋白质序列

EOF

sed -i "s/\$(date '+%Y-%m-%d %H:%M:%S')/$(date '+%Y-%m-%d %H:%M:%S')/g" "$DELIVERY_DIR/file_list.txt"

# 添加文件大小信息
echo "" >> "$DELIVERY_DIR/file_list.txt"
echo "文件大小:" >> "$DELIVERY_DIR/file_list.txt"
echo "==========================================" >> "$DELIVERY_DIR/file_list.txt"
find "$DELIVERY_DIR" -type f -exec ls -lh {} \; | awk '{print $9, $5}' | sed 's|'$DELIVERY_DIR'/||' >> "$DELIVERY_DIR/file_list.txt"

echo "文件清单已生成: $DELIVERY_DIR/file_list.txt"
