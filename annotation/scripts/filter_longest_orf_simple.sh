#!/bin/bash
# 使用awk提取每个转录本的最长ORF

SPECIES=$1
INPUT_PEP="${PROJECT_ROOT}/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa_updated.pep.fa"
OUTPUT_PEP="${PROJECT_ROOT}/annotation/${SPECIES}/pasa_update/${SPECIES}_pasa_updated_filtered.pep.fa"

if [ ! -f "$INPUT_PEP" ]; then
    echo "错误: 文件不存在: $INPUT_PEP"
    exit 1
fi

echo "过滤最长ORF: ${SPECIES}"

# 使用awk提取每个转录本的最长ORF
awk '
BEGIN {
    RS=">"
    FS="\n"
}
NF > 1 {
    seq = ""
    for (i=2; i<=NF; i++) seq = seq $i
    
    # 提取转录本ID（去掉ORF信息）
    transcript_id = $1
    gsub(/_.*ORF.*/, "", transcript_id)
    gsub(/ \[.*/, "", transcript_id)
    
    # 记录每个转录本的最长序列
    if (length(seq) > length(longest[transcript_id])) {
        longest[transcript_id] = seq
        header[transcript_id] = $1
    }
}
END {
    for (tid in longest) {
        print ">" header[tid]
        print longest[tid]
    }
}
' "$INPUT_PEP" > "$OUTPUT_PEP"

if [ -f "$OUTPUT_PEP" ] && [ -s "$OUTPUT_PEP" ]; then
    echo "✓ 过滤完成: $OUTPUT_PEP"
    echo "  序列数量: $(grep -c '^>' "$OUTPUT_PEP")"
else
    echo "✗ 过滤失败"
fi
