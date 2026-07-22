#!/bin/bash

# 基因组注释质量评估脚本
# 包括：BUSCO评估、基因长度分布、序列完整性验证

set -e

PROJECT_DIR="${PROJECT_ROOT}"
ANNOTATION_DIR="${PROJECT_DIR}/annotation"
OUTPUT_DIR="${ANNOTATION_DIR}/quality_assessment"
LOG_FILE="${PROJECT_DIR}/logs/quality_assessment.log"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname $LOG_FILE)"

# 日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"
}

# 激活conda环境
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
    conda activate base
fi

# 检查BUSCO
BUSCO_CMD="busco"
if ! command -v busco &> /dev/null; then
    log_error "BUSCO未安装，尝试安装..."
    conda install -y -c bioconda -c conda-forge busco=5.7.1
fi

log_info "开始质量评估..."

# 处理每个物种
for species in T01 T02; do
    log_info "处理物种: $species"
    
    SPECIES_DIR="${OUTPUT_DIR}/${species}"
    mkdir -p "$SPECIES_DIR"
    
    # 文件路径
    gff_file="${ANNOTATION_DIR}/${species}/structure/${species}_final.gff3"
    cds_file="${ANNOTATION_DIR}/${species}/functional/${species}.cds.fa"
    pep_file="${ANNOTATION_DIR}/${species}/functional/${species}.pep.fa"
    
    # 检查文件是否存在
    if [ ! -f "$gff_file" ]; then
        log_error "$species GFF文件不存在: $gff_file"
        continue
    fi
    
    if [ ! -f "$cds_file" ]; then
        log_error "$species CDS文件不存在: $cds_file"
        continue
    fi
    
    if [ ! -f "$pep_file" ]; then
        log_error "$species PEP文件不存在: $pep_file"
        continue
    fi
    
    log_info "  ✅ 所有输入文件存在"
    
    # ============================================
    # 1. 基因长度分布分析
    # ============================================
    log_info "  1. 分析基因长度分布..."
    
    # 从GFF3提取基因长度（CDS长度）
    awk -F'\t' '
    BEGIN {OFS="\t"}
    $3 == "CDS" {
        gene_id = ""
        for (i=9; i<=NF; i++) {
            if ($i ~ /^Parent=/) {
                split($i, a, "=")
                gene_id = a[2]
                gsub(/;.*/, "", gene_id)
                break
            }
        }
        if (gene_id != "") {
            cds_len = $5 - $4 + 1
            if (!(gene_id in total_length)) {
                total_length[gene_id] = 0
            }
            total_length[gene_id] += cds_len
        }
    }
    END {
        for (gene in total_length) {
            print gene, total_length[gene]
        }
    }' "$gff_file" | sort -k2 -n > "${SPECIES_DIR}/${species}_gene_lengths.txt"
    
    # 统计基因长度分布
    python3 << PYTHON_SCRIPT
import sys
import numpy as np

species = "${species}"
lengths_file = "${SPECIES_DIR}/${species}_gene_lengths.txt"
stats_file = "${SPECIES_DIR}/${species}_gene_length_stats.txt"

lengths = []
with open(lengths_file, "r") as f:
    for line in f:
        if line.strip():
            parts = line.strip().split()
            if len(parts) >= 2:
                try:
                    length = int(parts[1])
                    lengths.append(length)
                except:
                    pass

if lengths:
    lengths = np.array(lengths)
    stats = {
        'count': len(lengths),
        'mean': np.mean(lengths),
        'median': np.median(lengths),
        'std': np.std(lengths),
        'min': np.min(lengths),
        'max': np.max(lengths),
        'q25': np.percentile(lengths, 25),
        'q75': np.percentile(lengths, 75)
    }
    
    with open(stats_file, "w") as f:
        f.write(f"基因长度统计 ({species})\n")
        f.write("=" * 50 + "\n")
        f.write(f"总基因数: {stats['count']}\n")
        f.write(f"平均长度: {stats['mean']:.2f} bp\n")
        f.write(f"中位数长度: {stats['median']:.2f} bp\n")
        f.write(f"标准差: {stats['std']:.2f} bp\n")
        f.write(f"最小长度: {stats['min']} bp\n")
        f.write(f"最大长度: {stats['max']} bp\n")
        f.write(f"25%分位数: {stats['q25']:.2f} bp\n")
        f.write(f"75%分位数: {stats['q75']:.2f} bp\n")
    
    print(f"✅ 基因长度统计完成: {stats['count']} 个基因")
else:
    print("❌ 未找到基因长度数据")
PYTHON_SCRIPT
    
    log_info "  ✅ 基因长度分布分析完成"
    
    # ============================================
    # 2. CDS序列完整性验证
    # ============================================
    log_info "  2. 验证CDS序列完整性..."
    
    python3 << PYTHON_SCRIPT
from Bio import SeqIO
import sys

species = "${species}"
cds_file = "${cds_file}"
output_file = "${SPECIES_DIR}/${species}_cds_validation.txt"

stats = {
    'total': 0,
    'valid': 0,
    'invalid': 0,
    'with_stop': 0,
    'no_start': 0,
    'lengths': []
}

with open(output_file, "w") as out:
    out.write(f"CDS序列验证报告 ({species})\n")
    out.write("=" * 50 + "\n\n")
    
    for record in SeqIO.parse(cds_file, "fasta"):
        stats['total'] += 1
        seq = str(record.seq).upper()
        length = len(seq)
        stats['lengths'].append(length)
        
        # 检查是否以ATG开始
        starts_with_atg = seq.startswith('ATG')
        if not starts_with_atg:
            stats['no_start'] += 1
        
        # 检查是否以终止密码子结束
        stop_codons = ['TAA', 'TAG', 'TGA']
        ends_with_stop = seq[-3:] in stop_codons
        if ends_with_stop:
            stats['with_stop'] += 1
        
        # 检查长度是否为3的倍数
        is_multiple_of_3 = (length % 3) == 0
        
        # 检查是否包含N或非法字符
        has_invalid = any(c not in 'ATCGN' for c in seq)
        
        if starts_with_atg and is_multiple_of_3 and not has_invalid:
            stats['valid'] += 1
        else:
            stats['invalid'] += 1
    
    # 计算统计信息
    import numpy as np
    if stats['lengths']:
        lengths = np.array(stats['lengths'])
        out.write(f"总序列数: {stats['total']}\n")
        out.write(f"有效序列数: {stats['valid']} ({stats['valid']/stats['total']*100:.2f}%)\n")
        out.write(f"无效序列数: {stats['invalid']} ({stats['invalid']/stats['total']*100:.2f}%)\n")
        out.write(f"包含终止密码子: {stats['with_stop']} ({stats['with_stop']/stats['total']*100:.2f}%)\n")
        out.write(f"不以ATG开始: {stats['no_start']} ({stats['no_start']/stats['total']*100:.2f}%)\n")
        out.write(f"\n长度统计:\n")
        out.write(f"  平均长度: {np.mean(lengths):.2f} bp\n")
        out.write(f"  中位数长度: {np.median(lengths):.2f} bp\n")
        out.write(f"  最小长度: {np.min(lengths)} bp\n")
        out.write(f"  最大长度: {np.max(lengths)} bp\n")
    
    print(f"✅ CDS验证完成: {stats['total']} 个序列")
PYTHON_SCRIPT
    
    log_info "  ✅ CDS序列完整性验证完成"
    
    # ============================================
    # 3. 蛋白质序列完整性验证
    # ============================================
    log_info "  3. 验证蛋白质序列完整性..."
    
    python3 << PYTHON_SCRIPT
from Bio import SeqIO
import sys

species = "${species}"
pep_file = "${pep_file}"
output_file = "${SPECIES_DIR}/${species}_pep_validation.txt"

stats = {
    'total': 0,
    'valid': 0,
    'invalid': 0,
    'with_stop': 0,
    'lengths': []
}

valid_aa = set('ACDEFGHIKLMNPQRSTVWY*')

with open(output_file, "w") as out:
    out.write(f"蛋白质序列验证报告 ({species})\n")
    out.write("=" * 50 + "\n\n")
    
    for record in SeqIO.parse(pep_file, "fasta"):
        stats['total'] += 1
        seq = str(record.seq).upper()
        length = len(seq)
        stats['lengths'].append(length)
        
        # 检查是否包含非法氨基酸
        has_invalid = any(c not in valid_aa for c in seq)
        
        # 检查是否以M开始
        starts_with_m = seq.startswith('M')
        
        # 检查是否以*结束（终止密码子）
        ends_with_stop = seq.endswith('*')
        
        # 检查内部是否有终止密码子（不应该有）
        has_internal_stop = '*' in seq[:-1] if seq.endswith('*') else '*' in seq
        
        if ends_with_stop:
            stats['with_stop'] += 1
        
        if not has_invalid and starts_with_m and (ends_with_stop or not has_internal_stop):
            stats['valid'] += 1
        else:
            stats['invalid'] += 1
    
    # 计算统计信息
    import numpy as np
    if stats['lengths']:
        lengths = np.array(stats['lengths'])
        out.write(f"总序列数: {stats['total']}\n")
        out.write(f"有效序列数: {stats['valid']} ({stats['valid']/stats['total']*100:.2f}%)\n")
        out.write(f"无效序列数: {stats['invalid']} ({stats['invalid']/stats['total']*100:.2f}%)\n")
        out.write(f"包含终止密码子(*): {stats['with_stop']} ({stats['with_stop']/stats['total']*100:.2f}%)\n")
        out.write(f"\n长度统计:\n")
        out.write(f"  平均长度: {np.mean(lengths):.2f} aa\n")
        out.write(f"  中位数长度: {np.median(lengths):.2f} aa\n")
        out.write(f"  最小长度: {np.min(lengths)} aa\n")
        out.write(f"  最大长度: {np.max(lengths)} aa\n")
    
    print(f"✅ 蛋白质验证完成: {stats['total']} 个序列")
PYTHON_SCRIPT
    
    log_info "  ✅ 蛋白质序列完整性验证完成"
    
    # ============================================
    # 4. BUSCO评估
    # ============================================
    log_info "  4. 运行BUSCO评估..."
    
    BUSCO_OUTPUT="${SPECIES_DIR}/busco"
    BUSCO_DB="embryophyta_odb10"
    
    # 检查数据库是否存在
    if [ ! -d "$BUSCO_OUTPUT" ]; then
        log_info "  运行BUSCO评估（可能需要下载数据库）..."
        
        $BUSCO_CMD \
            -i "$pep_file" \
            -o busco \
            -l "$BUSCO_DB" \
            -m proteins \
            -c 8 \
            --out_path "$SPECIES_DIR" \
            >> "$LOG_FILE" 2>&1 || {
                log_error "BUSCO评估失败，可能数据库未下载"
                log_info "  提示: 首次运行需要下载数据库，可能需要较长时间"
            }
    else
        log_info "  BUSCO结果已存在，跳过"
    fi
    
    log_info "  ✅ BUSCO评估完成"
    
    log_info "完成 $species 的质量评估"
    echo ""
done

log_info "所有质量评估完成！"
log_info "结果保存在: $OUTPUT_DIR"

