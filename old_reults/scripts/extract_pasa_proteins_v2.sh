#!/bin/bash
# 从PASA结果中提取蛋白质序列 - 使用TransDecoder找最长ORF

SPECIES=$1
ASSEMBLIES_FASTA="/path/to/project_root/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa.assemblies.fasta"
OUTPUT_DIR="/path/to/project_root/annotation/${SPECIES}/pasa_update"
OUTPUT_PEP="${OUTPUT_DIR}/${SPECIES}_pasa_updated.pep.fa"

if [ ! -f "$ASSEMBLIES_FASTA" ]; then
    echo "错误: 文件不存在: $ASSEMBLIES_FASTA"
    exit 1
fi

echo "使用TransDecoder提取最长ORF: ${SPECIES}"

# 安装TransDecoder如果需要
if ! command -v TransDecoder.LongOrfs &> /dev/null && ! conda run -n annotation which TransDecoder.LongOrfs &> /dev/null; then
    echo "安装TransDecoder..."
    conda install -n annotation -c bioconda transdecoder -y 2>&1 | tail -5
fi

# 运行TransDecoder
TD_DIR="${OUTPUT_DIR}/transdecoder_${SPECIES}"
mkdir -p "$TD_DIR"

if conda run -n annotation TransDecoder.LongOrfs -t "$ASSEMBLIES_FASTA" -O "$TD_DIR" 2>&1 | tail -10; then
    if [ -f "${TD_DIR}/longest_orfs.pep" ]; then
        cp "${TD_DIR}/longest_orfs.pep" "$OUTPUT_PEP"
        echo "✓ 蛋白质序列已提取: $OUTPUT_PEP"
        echo "  序列数量: $(grep -c '^>' "$OUTPUT_PEP")"
    else
        echo "✗ TransDecoder输出文件不存在"
    fi
else
    echo "✗ TransDecoder运行失败，使用getorf结果（过滤最长ORF）"
    # 如果TransDecoder失败，使用getorf结果但过滤
    if [ -f "${OUTPUT_DIR}/${SPECIES}_pasa_updated.pep.fa" ]; then
        echo "使用getorf结果（已提取）"
    fi
fi
