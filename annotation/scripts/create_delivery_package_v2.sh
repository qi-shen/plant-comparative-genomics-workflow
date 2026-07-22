#!/bin/bash
# 创建交付包 v2.0 - 使用EVM整合结果

set -e

PROJECT_DIR="${PROJECT_ROOT}"
DELIVERY_DIR="${PROJECT_DIR}/annotation/delivery_v2"

echo "=========================================="
echo "创建交付包 v2.0"
echo "时间: $(date)"
echo "=========================================="

# 清理并创建目录
rm -rf "$DELIVERY_DIR"
mkdir -p "$DELIVERY_DIR/T01" "$DELIVERY_DIR/T02"

# 处理T01
echo ""
echo "=== 处理 T01 ==="
cp "${PROJECT_DIR}/annotation/T01/structure/T01_genes.gff3" "$DELIVERY_DIR/T01/"
cp "${PROJECT_DIR}/annotation/T01/structure/T01_genes.cds.fa" "$DELIVERY_DIR/T01/"
cp "${PROJECT_DIR}/annotation/T01/structure/T01_genes.pep.fa" "$DELIVERY_DIR/T01/"
cp "${PROJECT_DIR}/annotation/T01/structure/T01_id_mapping.tsv" "$DELIVERY_DIR/T01/"

# 检查功能注释文件
if [ -f "${PROJECT_DIR}/annotation/T01/function/T01_functional_annotation.txt" ]; then
    cp "${PROJECT_DIR}/annotation/T01/function/T01_functional_annotation.txt" "$DELIVERY_DIR/T01/"
fi

echo "T01文件:"
ls -lh "$DELIVERY_DIR/T01/"
echo "T01基因数: $(grep -c '	gene	' $DELIVERY_DIR/T01/T01_genes.gff3)"

# 处理T02
echo ""
echo "=== 处理 T02 ==="
cp "${PROJECT_DIR}/annotation/T02/structure/T02_genes.gff3" "$DELIVERY_DIR/T02/"
cp "${PROJECT_DIR}/annotation/T02/structure/T02_genes.cds.fa" "$DELIVERY_DIR/T02/"
cp "${PROJECT_DIR}/annotation/T02/structure/T02_genes.pep.fa" "$DELIVERY_DIR/T02/"
cp "${PROJECT_DIR}/annotation/T02/structure/T02_id_mapping.tsv" "$DELIVERY_DIR/T02/"

# 检查功能注释文件
if [ -f "${PROJECT_DIR}/annotation/T02/function/T02_functional_annotation.txt" ]; then
    cp "${PROJECT_DIR}/annotation/T02/function/T02_functional_annotation.txt" "$DELIVERY_DIR/T02/"
fi

echo "T02文件:"
ls -lh "$DELIVERY_DIR/T02/"
echo "T02基因数: $(grep -c '	gene	' $DELIVERY_DIR/T02/T02_genes.gff3)"

# 创建README
echo ""
echo "=== 创建README ==="
cat > "$DELIVERY_DIR/README.txt" << 'EOF'
targets注释结果交付包
========================

生成日期: $(date)

目录结构:
---------
T01/ - T01样本注释结果
  - T01_genes.gff3       : 基因结构注释（GFF3格式）
  - T01_genes.cds.fa     : CDS序列（FASTA格式）
  - T01_genes.pep.fa     : 蛋白质序列（FASTA格式）
  - T01_id_mapping.tsv   : 基因ID映射表

T02/ - T02样本注释结果
  - T02_genes.gff3       : 基因结构注释（GFF3格式）
  - T02_genes.cds.fa     : CDS序列（FASTA格式）
  - T02_genes.pep.fa     : 蛋白质序列（FASTA格式）
  - T02_id_mapping.tsv   : 基因ID映射表

基因ID命名规则:
--------------
格式: {物种代码}{染色体号}G{基因编号}
示例: T0101G000001 = T01物种 + 01号染色体 + 第1个基因

注释统计:
---------
T01: 26,971 个基因
T02: 26,771 个基因

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

