#!/bin/bash
# 创建交付包 v2.0 - 使用EVM整合结果

set -e

PROJECT_DIR="/path/to/project_root"
DELIVERY_DIR="${PROJECT_DIR}/annotation/delivery_v2"

echo "=========================================="
echo "创建交付包 v2.0"
echo "时间: $(date)"
echo "=========================================="

# 清理并创建目录
rm -rf "$DELIVERY_DIR"
mkdir -p "$DELIVERY_DIR/BH" "$DELIVERY_DIR/CK"

# 处理BH
echo ""
echo "=== 处理 BH ==="
cp "${PROJECT_DIR}/annotation/BH/structure/BH_genes.gff3" "$DELIVERY_DIR/BH/"
cp "${PROJECT_DIR}/annotation/BH/structure/BH_genes.cds.fa" "$DELIVERY_DIR/BH/"
cp "${PROJECT_DIR}/annotation/BH/structure/BH_genes.pep.fa" "$DELIVERY_DIR/BH/"
cp "${PROJECT_DIR}/annotation/BH/structure/BH_id_mapping.tsv" "$DELIVERY_DIR/BH/"

# 检查功能注释文件
if [ -f "${PROJECT_DIR}/annotation/BH/function/BH_functional_annotation.txt" ]; then
    cp "${PROJECT_DIR}/annotation/BH/function/BH_functional_annotation.txt" "$DELIVERY_DIR/BH/"
fi

echo "BH文件:"
ls -lh "$DELIVERY_DIR/BH/"
echo "BH基因数: $(grep -c '	gene	' $DELIVERY_DIR/BH/BH_genes.gff3)"

# 处理CK
echo ""
echo "=== 处理 CK ==="
cp "${PROJECT_DIR}/annotation/CK/structure/CK_genes.gff3" "$DELIVERY_DIR/CK/"
cp "${PROJECT_DIR}/annotation/CK/structure/CK_genes.cds.fa" "$DELIVERY_DIR/CK/"
cp "${PROJECT_DIR}/annotation/CK/structure/CK_genes.pep.fa" "$DELIVERY_DIR/CK/"
cp "${PROJECT_DIR}/annotation/CK/structure/CK_id_mapping.tsv" "$DELIVERY_DIR/CK/"

# 检查功能注释文件
if [ -f "${PROJECT_DIR}/annotation/CK/function/CK_functional_annotation.txt" ]; then
    cp "${PROJECT_DIR}/annotation/CK/function/CK_functional_annotation.txt" "$DELIVERY_DIR/CK/"
fi

echo "CK文件:"
ls -lh "$DELIVERY_DIR/CK/"
echo "CK基因数: $(grep -c '	gene	' $DELIVERY_DIR/CK/CK_genes.gff3)"

# 创建README
echo ""
echo "=== 创建README ==="
cat > "$DELIVERY_DIR/README.txt" << 'EOF'
targets注释结果交付包
========================

生成日期: $(date)

目录结构:
---------
BH/ - BH样本注释结果
  - BH_genes.gff3       : 基因结构注释（GFF3格式）
  - BH_genes.cds.fa     : CDS序列（FASTA格式）
  - BH_genes.pep.fa     : 蛋白质序列（FASTA格式）
  - BH_id_mapping.tsv   : 基因ID映射表

CK/ - CK样本注释结果
  - CK_genes.gff3       : 基因结构注释（GFF3格式）
  - CK_genes.cds.fa     : CDS序列（FASTA格式）
  - CK_genes.pep.fa     : 蛋白质序列（FASTA格式）
  - CK_id_mapping.tsv   : 基因ID映射表

基因ID命名规则:
--------------
格式: {物种代码}{染色体号}G{基因编号}
示例: BH01G000001 = BH物种 + 01号染色体 + 第1个基因

注释统计:
---------
BH: 26,971 个基因
CK: 26,771 个基因

注释方法:
---------
1. AUGUSTUS从头预测
2. 转录组比对证据
3. EVidenceModeler (EVM v2.1.0) 证据整合

EOF

# 更新README中的日期
sed -i "s/\$(date)/$(date)/" "$DELIVERY_DIR/README.txt"

# 压缩
echo ""
echo "=== 压缩文件 ==="
cd "${PROJECT_DIR}/annotation"
tar -czvf delivery_v2.tar.gz delivery_v2/
echo ""
echo "压缩包: ${PROJECT_DIR}/annotation/delivery_v2.tar.gz"
ls -lh "${PROJECT_DIR}/annotation/delivery_v2.tar.gz"

echo ""
echo "=========================================="
echo "交付包创建完成"
echo "=========================================="

