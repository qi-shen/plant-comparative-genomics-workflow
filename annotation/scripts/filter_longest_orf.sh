#!/bin/bash
# 从getorf结果中提取每个转录本的最长ORF

SPECIES=$1
INPUT_PEP="${PROJECT_ROOT}/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa_updated.pep.fa"
OUTPUT_PEP="${PROJECT_ROOT}/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa_updated_filtered.pep.fa"

if [ ! -f "$INPUT_PEP" ]; then
    echo "错误: 文件不存在: $INPUT_PEP"
    exit 1
fi

echo "过滤最长ORF: ${SPECIES}"

# 使用Python脚本提取每个转录本的最长ORF
python3 << PYTHON
from Bio import SeqIO
from collections import defaultdict
import sys

input_file = "$INPUT_PEP"
output_file = "$OUTPUT_PEP"

# 按转录本ID分组（假设ID格式为 >transcript_id_ORF_start_end）
transcript_orfs = defaultdict(list)

for record in SeqIO.parse(input_file, "fasta"):
    # 提取转录本ID（去掉ORF信息）
    transcript_id = record.id.split("_ORF")[0].split(" [")[0]
    transcript_orfs[transcript_id].append(record)

# 为每个转录本选择最长的ORF
longest_orfs = []
for transcript_id, orfs in transcript_orfs.items():
    longest = max(orfs, key=lambda x: len(x.seq))
    longest_orfs.append(longest)

# 写入输出文件
SeqIO.write(longest_orfs, output_file, "fasta")
print(f"提取了 {len(longest_orfs)} 个最长ORF")
PYTHON

if [ -f "$OUTPUT_PEP" ]; then
    echo "✓ 过滤完成: $OUTPUT_PEP"
    echo "  序列数量: $(grep -c '^>' "$OUTPUT_PEP")"
else
    echo "✗ 过滤失败"
fi
