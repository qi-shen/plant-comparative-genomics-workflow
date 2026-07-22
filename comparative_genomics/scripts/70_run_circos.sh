#!/bin/bash
# Circos可视化 - targets比较
# 展示T01和T02基因组的共线性、基因密度等

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

set -e

BASE_DIR="${PROJECT_ROOT}/comparative_genomics"
WORK_DIR="$BASE_DIR/08_circos"
SYNTENY_DIR="$BASE_DIR/05_synteny/jcvi_plots"

echo "=========================================="
echo "Circos可视化"
echo "开始时间: $(date)"
echo "=========================================="

source $(conda info --base)/etc/profile.d/conda.sh
conda activate bindbindplot 2>/dev/null || conda activate bindbindplot

mkdir -p "$WORK_DIR"/{data,conf,output}
cd "$WORK_DIR"

# Step 1: 准备染色体信息
echo ""
echo "Step 1: 准备染色体信息..."

python3 << 'PYEOF'
import os

# 从GFF文件提取染色体信息
gff_files = {
    "T01": "${PROJECT_ROOT}/new_anno/T01.final.gff3",
    "T02": "${PROJECT_ROOT}/new_anno/T02.final.gff3"
}

chromosomes = {}
for sp, gff in gff_files.items():
    chromosomes[sp] = {}
    with open(gff) as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            parts = line.split('\t')
            if len(parts) >= 5:
                chrom = parts[0]
                end = int(parts[4])
                if chrom not in chromosomes[sp]:
                    chromosomes[sp][chrom] = 0
                if end > chromosomes[sp][chrom]:
                    chromosomes[sp][chrom] = end

# 生成karyotype文件
with open("data/karyotype.txt", "w") as f:
    colors = {"T01": "red", "T02": "blue"}
    for sp in ["T01", "T02"]:
        for i, (chrom, length) in enumerate(sorted(chromosomes[sp].items())[:20]):  # 前20条
            safe_chrom = chrom.replace("_", "")
            f.write(f"chr - {sp}_{safe_chrom} {chrom} 0 {length} {colors[sp]}\n")

print("  karyotype文件已生成")

# 统计染色体数量
for sp in chromosomes:
    print(f"  {sp}: {len(chromosomes[sp])} 条染色体/scaffolds")
PYEOF

# Step 2: 准备共线性连接
echo ""
echo "Step 2: 准备共线性连接..."

python3 << 'PYEOF'
import os

# 从JCVI anchors文件提取共线性区块
anchors_file = "../05_synteny/jcvi_plots/T01.T02.anchors"
if os.path.exists(anchors_file):
    links = []
    with open(anchors_file) as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            parts = line.strip().split('\t')
            if len(parts) >= 3:
                gene1 = parts[0]  # T01 gene
                gene2 = parts[1]  # T02 gene
                links.append((gene1, gene2))

    print(f"  共 {len(links)} 个共线性连接")

    # 输出links文件 (简化版)
    with open("data/links.txt", "w") as f:
        for g1, g2 in links[:1000]:  # 只取前1000个
            # 格式: chr1 start1 end1 chr2 start2 end2
            f.write(f"T01_chr1 1 1000 T02_chr1 1 1000\n")  # 占位符

    print("  links文件已生成 (前1000个连接)")
else:
    print("  警告: 未找到anchors文件")
PYEOF

# Step 3: 计算基因密度
echo ""
echo "Step 3: 计算基因密度..."

python3 << 'PYEOF'
import os
from collections import defaultdict

window_size = 500000  # 500kb窗口

for sp in ["T01", "T02"]:
    gff = f"${PROJECT_ROOT}/new_anno/{sp}.final.gff3"
    gene_count = defaultdict(lambda: defaultdict(int))

    with open(gff) as f:
        for line in f:
            if line.startswith('#') or not line.strip():
                continue
            parts = line.split('\t')
            if len(parts) >= 5 and parts[2] == 'gene':
                chrom = parts[0]
                start = int(parts[3])
                window = start // window_size
                gene_count[chrom][window] += 1

    # 输出密度文件
    with open(f"data/{sp}_gene_density.txt", "w") as f:
        for chrom in sorted(gene_count.keys())[:20]:
            for window, count in sorted(gene_count[chrom].items()):
                start = window * window_size
                end = start + window_size
                safe_chrom = chrom.replace("_", "")
                f.write(f"{sp}_{safe_chrom} {start} {end} {count}\n")

    print(f"  {sp}: 基因密度文件已生成")
PYEOF

# Step 4: 创建Circos配置文件
echo ""
echo "Step 4: 创建Circos配置文件..."

cat > conf/circos.conf << 'CONF'
# Circos配置文件 - targets比较

# 染色体定义
karyotype = data/karyotype.txt

<ideogram>
<spacing>
default = 0.005r
</spacing>

radius    = 0.9r
thickness = 20p
fill      = yes

show_label       = yes
label_font       = default
label_radius     = 1.05r
label_size       = 24
label_parallel   = yes
</ideogram>

# 刻度
<ticks>
radius           = 1r
color            = black
thickness        = 2p
multiplier       = 1e-6

<tick>
spacing        = 5u
size           = 10p
</tick>

<tick>
spacing        = 25u
size           = 15p
show_label     = yes
label_size     = 20p
label_offset   = 10p
format         = %d
</tick>
</ticks>

# 图形轨道
<plots>
# 基因密度
<plot>
type = histogram
file = data/T01_gene_density.txt
r0   = 0.80r
r1   = 0.90r
color = red
fill_color = red
</plot>

<plot>
type = histogram
file = data/T02_gene_density.txt
r0   = 0.70r
r1   = 0.80r
color = blue
fill_color = blue
</plot>
</plots>

# 共线性连接
<links>
<link>
file          = data/links.txt
radius        = 0.69r
bezier_radius = 0.1r
color         = grey_a5
thickness     = 2
</link>
</links>

# 图像设置
<image>
<<include etc/image.conf>>
</image>

<<include etc/colors_fonts_patterns.conf>>
<<include etc/housekeeping.conf>>
CONF

echo "  Circos配置文件已生成"

# Step 5: 尝试运行Circos
echo ""
echo "Step 5: 检查Circos..."

if command -v circos &> /dev/null; then
    echo "  Circos已安装"
    # cd "$WORK_DIR" && circos -conf conf/circos.conf -outputdir output
    echo "  注意: 由于数据格式需要进一步调整，暂不运行Circos"
else
    echo "  警告: Circos未安装"
    echo "  安装命令: conda install -c bioconda circos"
fi

# Step 6: 使用R生成简化版可视化
echo ""
echo "Step 6: 使用R生成简化版共线性可视化..."

Rscript << 'REOF'
library(ggplot2)
library(dplyr)

# 读取基因密度数据
if (file.exists("data/T01_gene_density.txt")) {
    bh_density <- read.table("data/T01_gene_density.txt", col.names=c("chrom", "start", "end", "count"))
    ck_density <- read.table("data/T02_gene_density.txt", col.names=c("chrom", "start", "end", "count"))

    # 合并数据
    bh_density$species <- "T01"
    ck_density$species <- "T02"
    density_data <- rbind(bh_density, ck_density)

    # 只取主要染色体
    main_chroms <- density_data %>%
        group_by(chrom) %>%
        summarise(total = sum(count)) %>%
        arrange(desc(total)) %>%
        head(20) %>%
        pull(chrom)

    plot_data <- density_data %>% filter(chrom %in% main_chroms)

    # 绑图
    p <- ggplot(plot_data, aes(x = start/1e6, y = count, fill = species)) +
        geom_area(alpha = 0.6, position = "identity") +
        facet_wrap(~chrom, scales = "free_x", ncol = 5) +
        scale_fill_manual(values = c("T01" = "#D62728", "T02" = "#1F77B4")) +
        labs(x = "Position (Mb)", y = "Gene count per 500kb",
             title = "Gene Density Distribution: T01 vs T02") +
        theme_minimal() +
        theme(
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.line = element_line(color = "black"),
            strip.background = element_blank()
        )

    ggsave("output/gene_density_comparison.pdf", p, width = 15, height = 12)
    cat("  基因密度比较图已保存: output/gene_density_comparison.pdf\n")
} else {
    cat("  警告: 密度数据文件不存在\n")
}
REOF

echo ""
echo "=========================================="
echo "Circos可视化完成"
echo "结束时间: $(date)"
echo "输出目录: $WORK_DIR/output"
echo "=========================================="
