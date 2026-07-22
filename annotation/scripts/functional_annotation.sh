#!/bin/bash
# 功能注释脚本 - 使用Diamond和eggnog-mapper

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 配置
PROJECT_DIR="${PROJECT_ROOT}"
DIAMOND="${PROJECT_ROOT}"
EMAPPER="${PROJECT_ROOT}"
EGGNOG_DATA="${PROJECT_ROOT}"
SWISSPROT_DB="${PROJECT_DIR}/databases/swissprot"
THREADS=32

# 检查工具
check_tools() {
    log_step "检查工具..."
    
    if [ ! -x "$DIAMOND" ]; then
        log_error "Diamond不存在: $DIAMOND"
        exit 1
    fi
    log_info "Diamond: $($DIAMOND --version 2>&1 | head -1)"
    
    if [ ! -f "$EMAPPER" ]; then
        log_error "eggnog-mapper不存在: $EMAPPER"
        exit 1
    fi
    
    if [ ! -d "$EGGNOG_DATA" ]; then
        log_error "eggnog数据库目录不存在: $EGGNOG_DATA"
        exit 1
    fi
    
    log_info "工具检查完成"
}

# 使用Diamond注释SwissProt
annotate_swissprot() {
    local SPECIES=$1
    local PEP_FILE="${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_genes.pep.fa"
    local OUTPUT_DIR="${PROJECT_DIR}/annotation/${SPECIES}/function"
    local OUTPUT_PREFIX="${OUTPUT_DIR}/${SPECIES}_swissprot"
    
    log_step "========== Diamond注释SwissProt: ${SPECIES} =========="
    
    mkdir -p "$OUTPUT_DIR"
    
    # 检查SwissProt数据库是否存在
    if [ ! -f "${SWISSPROT_DB}.dmnd" ]; then
        log_info "SwissProt Diamond数据库不存在，正在创建..."
        $DIAMOND makedb --in "${PROJECT_DIR}/databases/uniprot_sprot.fasta" \
            -d "$SWISSPROT_DB" \
            --threads $THREADS
        log_info "预处理数据库..."
        $DIAMOND prepdb -d "$SWISSPROT_DB"
    elif [ ! -f "${SWISSPROT_DB}.acc" ]; then
        log_info "预处理数据库..."
        $DIAMOND prepdb -d "$SWISSPROT_DB"
    fi
    
    log_info "运行Diamond搜索..."
    $DIAMOND blastp \
        --query "$PEP_FILE" \
        --db "$SWISSPROT_DB" \
        --out "${OUTPUT_PREFIX}.blastp" \
        --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
        --threads $THREADS \
        --max-target-seqs 5 \
        --evalue 1e-5 \
        --more-sensitive
    
    log_info "✅ SwissProt注释完成: ${OUTPUT_PREFIX}.blastp"
    log_info "匹配数: $(wc -l < ${OUTPUT_PREFIX}.blastp)"
}

# 使用eggnog-mapper注释
annotate_eggnog() {
    local SPECIES=$1
    local PEP_FILE="${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_genes.pep.fa"
    local OUTPUT_DIR="${PROJECT_DIR}/annotation/${SPECIES}/function"
    local OUTPUT_PREFIX="${OUTPUT_DIR}/${SPECIES}_eggnog"
    
    log_step "========== eggnog-mapper注释: ${SPECIES} =========="
    
    mkdir -p "$OUTPUT_DIR"
    
    log_info "运行eggnog-mapper..."
    
    python3 "$EMAPPER" \
        -i "$PEP_FILE" \
        --output "${OUTPUT_PREFIX}" \
        --output_dir "$OUTPUT_DIR" \
        --data_dir "$EGGNOG_DATA" \
        --cpu $THREADS \
        --dmnd_db "$EGGNOG_DATA/eggnog_proteins.dmnd" \
        --override \
        --tax_scope 33090 \
        --go_evidence non-electronic \
        --target_orthologs all \
        --seed_ortholog_evalue 0.001 \
        --seed_ortholog_score 60 \
        --query-cover 20 \
        --subject-cover 0 \
        --pfam_realign none \
        --excel
    
    log_info "✅ eggnog-mapper注释完成"
    
    # 检查输出文件
    if [ -f "${OUTPUT_PREFIX}.emapper.annotations" ]; then
        log_info "注释结果: ${OUTPUT_PREFIX}.emapper.annotations"
        log_info "注释基因数: $(grep -v '^#' ${OUTPUT_PREFIX}.emapper.annotations | wc -l)"
    fi
}

# 整合注释结果
integrate_annotations() {
    local SPECIES=$1
    local OUTPUT_DIR="${PROJECT_DIR}/annotation/${SPECIES}/function"
    
    log_step "========== 整合注释结果: ${SPECIES} =========="
    
    # 创建整合脚本
    python3 << EOF
import pandas as pd
import sys

species = "$SPECIES"
output_dir = "$OUTPUT_DIR"

# 读取eggnog结果
eggnog_file = f"{output_dir}/{species}_eggnog.emapper.annotations"
swissprot_file = f"{output_dir}/{species}_swissprot.blastp"

# 读取eggnog注释
eggnog_df = pd.read_csv(eggnog_file, sep='\t', comment='#', 
                        names=['query', 'seed_ortholog', 'evalue', 'score', 
                               'eggNOG_OGs', 'max_annot_lvl', 'COG_category',
                               'Description', 'Preferred_name', 'GOs', 'EC',
                               'KEGG_ko', 'KEGG_Pathway', 'KEGG_Module',
                               'KEGG_Reaction', 'KEGG_rclass', 'BRITE',
                               'KEGG_TC', 'CAZy', 'BiGG_Reaction', 'PFAMs'])

# 读取SwissProt结果（取top hit）
swissprot_df = pd.read_csv(swissprot_file, sep='\t', header=None,
                          names=['query', 'sseqid', 'pident', 'length', 
                                'mismatch', 'gapopen', 'qstart', 'qend',
                                'sstart', 'send', 'evalue', 'bitscore', 'stitle'])

# 取每个query的top hit
swissprot_top = swissprot_df.sort_values('bitscore', ascending=False).drop_duplicates('query')

# 合并结果
result = eggnog_df.merge(swissprot_top[['query', 'sseqid', 'pident', 'evalue', 'bitscore', 'stitle']], 
                         on='query', how='left', suffixes=('', '_swissprot'))

# 保存
output_file = f"{output_dir}/{species}_functional_annotation.txt"
result.to_csv(output_file, sep='\t', index=False)
print(f"整合注释结果已保存: {output_file}")
print(f"总基因数: {len(result)}")
print(f"有eggnog注释: {result['seed_ortholog'].notna().sum()}")
print(f"有SwissProt注释: {result['sseqid'].notna().sum()}")
EOF

    log_info "✅ 注释结果整合完成"
}

# 处理单个物种
process_species() {
    local SPECIES=$1
    
    log_info "=========================================="
    log_info "功能注释: ${SPECIES}"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    # 检查蛋白序列文件
    local PEP_FILE="${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_genes.pep.fa"
    if [ ! -f "$PEP_FILE" ]; then
        log_error "蛋白序列文件不存在: $PEP_FILE"
        return 1
    fi
    
    log_info "蛋白序列数: $(grep -c '^>' $PEP_FILE)"
    
    # 1. Diamond注释SwissProt
    annotate_swissprot "$SPECIES"
    
    echo ""
    
    # 2. eggnog-mapper注释
    annotate_eggnog "$SPECIES"
    
    echo ""
    
    # 3. 整合结果
    integrate_annotations "$SPECIES"
    
    log_info "✅ ${SPECIES} 功能注释完成"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "功能注释流程"
    log_info "工具: Diamond + eggnog-mapper"
    log_info "时间: $(date)"
    log_info "=========================================="
    
    check_tools
    
    # 处理BH
    process_species "T01"
    
    echo ""
    
    # 处理CK
    process_species "T02"
    
    log_info ""
    log_info "=========================================="
    log_info "功能注释完成"
    log_info "时间: $(date)"
    log_info "=========================================="
}

main "$@"
