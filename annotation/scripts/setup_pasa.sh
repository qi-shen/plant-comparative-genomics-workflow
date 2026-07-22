#!/bin/bash

# PASA设置和运行脚本
# 简化PASA配置和运行流程

set -e

PROJECT_DIR="${PROJECT_ROOT}"
SPECIES=${1:-"T01"}

PASA_HOME="${PROJECT_ROOT}"
PASA_CONF_DIR="${PROJECT_DIR}/annotation/${SPECIES}/pasa_update"
CONFIG_FILE="${PASA_CONF_DIR}/pasa.CONFIG"

# 文件路径
GENOME="${PROJECT_DIR}/annotation/${SPECIES}/${SPECIES}_genome.masked.fa"
GTF_TRANSCRIPTOME="${PROJECT_DIR}/annotation/${SPECIES}/transcriptome/${SPECIES}_merged.gtf"
GFF3_INPUT="${PROJECT_DIR}/annotation/${SPECIES}/structure/${SPECIES}_final.gff3"

mkdir -p "$PASA_CONF_DIR"

echo "=========================================="
echo "设置PASA配置 - ${SPECIES}样本"
echo "=========================================="
echo ""

# 检查输入文件
if [ ! -f "$GENOME" ]; then
    echo "错误: 基因组文件不存在: $GENOME"
    exit 1
fi

if [ ! -f "$GTF_TRANSCRIPTOME" ]; then
    echo "错误: 转录组GTF文件不存在: $GTF_TRANSCRIPTOME"
    exit 1
fi

# 转换GTF为GFF3（PASA需要GFF3格式）
GFF3_TRANSCRIPTOME="${PASA_CONF_DIR}/${SPECIES}_transcriptome.gff3"
echo "1. 转换GTF为GFF3格式..."
if command -v gffread &> /dev/null; then
    gffread -E "$GTF_TRANSCRIPTOME" -o "$GFF3_TRANSCRIPTOME" 2>&1
    echo "   ✓ 转换完成: $GFF3_TRANSCRIPTOME"
else
    echo "   警告: gffread未找到，尝试使用Python转换..."
    # 简单的GTF到GFF3转换
    python3 << PYTHON_SCRIPT
with open("$GTF_TRANSCRIPTOME", 'r') as f_in, open("$GFF3_TRANSCRIPTOME", 'w') as f_out:
    f_out.write("##gff-version 3\n")
    for line in f_in:
        if not line.startswith('#'):
            f_out.write(line)
PYTHON_SCRIPT
    echo "   ✓ 转换完成: $GFF3_TRANSCRIPTOME"
fi

# 创建PASA配置文件
echo ""
echo "2. 创建PASA配置文件..."

# 使用PASA的模板创建配置文件
TEMPLATE_FILE="${PROJECT_ROOT}"

if [ -f "$TEMPLATE_FILE" ]; then
    # 从模板创建
    sed -e "s|<__DATABASE__>|${SPECIES}_pasa|g" \
        -e "s|<__MIN_PERCENT_ALIGNED__>|80|g" \
        -e "s|<__MIN_AVG_PER_ID__>|95|g" \
        "$TEMPLATE_FILE" > "$CONFIG_FILE"
    
    # 添加其他必要的配置
    cat >> "$CONFIG_FILE" << EOF

# SQLite database (if not using MySQL)
SQLITEDB=${PASA_CONF_DIR}/${SPECIES}_pasa.sqlite

# Genome file
GENOME_FILE=${GENOME}

# Transcript GFF3 file  
TRANSCRIPT_GTF=${GFF3_TRANSCRIPTOME}

# CPU threads
CPU=32

EOF
else
    # 如果模板不存在，创建基本配置
    cat > "$CONFIG_FILE" << EOF
##################################################
# PASA Align Assembly Configuration
##################################################

# Database settings
DATABASE=${SPECIES}_pasa

# SQLite database (alternative to MySQL)
SQLITEDB=${PASA_CONF_DIR}/${SPECIES}_pasa.sqlite

# Genome file
GENOME_FILE=${GENOME}

# Transcript GFF3 file
TRANSCRIPT_GTF=${GFF3_TRANSCRIPTOME}

# CPU threads
CPU=32

# Alignment validation parameters
validate_alignments_in_db.dbi:--MIN_PERCENT_ALIGNED=80
validate_alignments_in_db.dbi:--MIN_AVG_PER_ID=95

# Subcluster builder parameters
subcluster_builder.dbi:-m=50

EOF
fi

echo "   ✓ 配置文件已创建: $CONFIG_FILE"

# 显示使用说明
echo ""
echo "=========================================="
echo "PASA配置完成！"
echo "=========================================="
echo ""
echo "配置文件: $CONFIG_FILE"
echo ""
echo "下一步: 运行PASA更新"
echo "  bash scripts/run_pasa_update.sh ${SPECIES}"
echo ""
echo "或手动运行:"
echo "  cd $PASA_CONF_DIR"
echo "  conda run -n pasa $PASA_HOME/Launch_PASA_pipeline.pl \\"
echo "    -c pasa.CONFIG \\"
echo "    -C -R \\"
echo "    -g $GENOME \\"
echo "    -t $GFF3_TRANSCRIPTOME"
echo ""

