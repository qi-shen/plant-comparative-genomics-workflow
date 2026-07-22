#!/bin/bash
# 从PASA组装序列中提取蛋白质序列

SPECIES=$1
ASSEMBLIES_FASTA="${PROJECT_ROOT}/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa.assemblies.fasta"
OUTPUT_PEP="${PROJECT_ROOT}/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa_updated.pep.fa"

if [ ! -f "$ASSEMBLIES_FASTA" ]; then
    echo "错误: 文件不存在: $ASSEMBLIES_FASTA"
    exit 1
fi

echo "从PASA组装序列提取蛋白质序列: ${SPECIES}"

# 使用getorf或类似工具从转录本序列提取ORF
# 或者直接从组装序列转换（如果已经是CDS）
# 由于PASA组装的是转录本，我们需要找到ORF

# 方法1: 使用getorf (EMBOSS)
if command -v getorf &> /dev/null; then
    getorf -sequence "$ASSEMBLIES_FASTA" -outseq "$OUTPUT_PEP" -minsize 30 -find 1 -methionine 1 2>&1 | tail -5
elif conda run -n annotation which getorf &> /dev/null; then
    conda run -n annotation getorf -sequence "$ASSEMBLIES_FASTA" -outseq "$OUTPUT_PEP" -minsize 30 -find 1 -methionine 1 2>&1 | tail -5
else
    # 方法2: 使用TransDecoder
    if command -v TransDecoder.LongOrfs &> /dev/null; then
        TransDecoder.LongOrfs -t "$ASSEMBLIES_FASTA" -O "${OUTPUT_PEP%.pep.fa}.transdecoder_dir" 2>&1 | tail -5
        if [ -f "${OUTPUT_PEP%.pep.fa}.transdecoder_dir/longest_orfs.pep" ]; then
            cp "${OUTPUT_PEP%.pep.fa}.transdecoder_dir/longest_orfs.pep" "$OUTPUT_PEP"
        fi
    else
        echo "警告: 未找到getorf或TransDecoder，尝试使用简单方法..."
        # 方法3: 假设序列已经是CDS，直接翻译（不推荐，但作为备选）
        echo "请手动提取或使用其他工具"
    fi
fi

if [ -f "$OUTPUT_PEP" ] && [ -s "$OUTPUT_PEP" ]; then
    echo "✓ 蛋白质序列已提取: $OUTPUT_PEP"
    echo "  序列数量: $(grep -c '^>' "$OUTPUT_PEP")"
else
    echo "✗ 提取失败"
fi
