#!/bin/bash
# 准备共线性分析数据
# 日期: 2024-12-29

set -e

cd /path/to/project_root
WORKDIR="old_reults/comparative_genomics/05_synteny"
mkdir -p "$WORKDIR"/{gff,cds,bed}

echo "=========================================="
echo "准备共线性分析数据"
echo "=========================================="

# 定义物种GFF和CDS文件路径
declare -A GFF_FILES=(
    ["BH"]="new_anno/BH.final.gff3"
    ["CK"]="new_anno/CK.final.gff3"
    ["TAU"]="old_reults/results/C02/tau.gff3"
    ["TCH"]="old_reults/results/C03/Tchinensis.gff3"
    ["RSO"]="old_reults/results/C01/hs.chrom.genome.gff"
)

declare -A CDS_FILES=(
    ["BH"]="new_anno/BH.final.cds.fa"
    ["CK"]="new_anno/CK.final.cds.fa"
    ["TAU"]="old_reults/results/C02/tau.longest_cds.fasta"
    ["TCH"]="old_reults/results/C03/Tchinensis_cds.fa"
    ["RSO"]="old_reults/results/C01/C01.cds.fa"
)

# 处理每个物种
for sp in BH CK TAU TCH RSO; do
    echo ""
    echo "处理 $sp..."
    
    # 复制GFF文件
    gff_src="${GFF_FILES[$sp]}"
    if [ -f "$gff_src" ]; then
        # 提取基因信息为简化的BED格式 (for MCScanX)
        # chr start end gene_id score strand
        awk -F'\t' '$3=="gene" || $3=="mRNA" {
            split($9, attrs, ";");
            for(i in attrs) {
                if(match(attrs[i], /ID=([^;]+)/, arr)) {
                    gene_id = arr[1];
                    break;
                }
            }
            print $1"\t"$4"\t"$5"\t"gene_id"\t0\t"$7
        }' "$gff_src" | sort -k1,1 -k2,2n | uniq > "$WORKDIR/bed/${sp}.bed"
        
        # 创建JCVI格式的bed文件
        awk -F'\t' '$3=="mRNA" || $3=="gene" {
            split($9, attrs, ";");
            gene_id = "";
            for(i in attrs) {
                if(match(attrs[i], /ID=([^;]+)/, arr)) {
                    gene_id = arr[1];
                    break;
                }
            }
            if(gene_id != "") print $1"\t"$4-1"\t"$5"\t"gene_id"\t0\t"$7
        }' "$gff_src" | sort -k1,1 -k2,2n | uniq > "$WORKDIR/gff/${sp}.bed"
        
        count=$(wc -l < "$WORKDIR/bed/${sp}.bed")
        echo "  GFF -> BED: $count 条记录"
    else
        echo "  警告: GFF文件不存在 $gff_src"
    fi
    
    # 复制CDS文件
    cds_src="${CDS_FILES[$sp]}"
    if [ -f "$cds_src" ]; then
        # 添加物种前缀到序列ID
        conda run -n comparative seqkit replace -p '^' -r "${sp}_" "$cds_src" > "$WORKDIR/cds/${sp}.cds.fa" 2>/dev/null || \
        awk -v sp="$sp" '/^>/{gsub(/^>/, ">" sp "_"); print; next} {print}' "$cds_src" > "$WORKDIR/cds/${sp}.cds.fa"
        
        count=$(grep -c '^>' "$WORKDIR/cds/${sp}.cds.fa")
        echo "  CDS序列: $count 条"
    else
        echo "  警告: CDS文件不存在 $cds_src"
    fi
done

echo ""
echo "=========================================="
echo "数据准备完成"
echo "输出目录: $WORKDIR"
echo "=========================================="

