# PASA更新基因结构注释指南

## 概述

PASA (Program to Assemble Spliced Alignments) 是一个强大的工具，用于使用转录组数据改进基因结构注释。

## 当前状态

- **转录组数据**: 已有merged.gtf文件
- **现有注释**: T01_final.gff3, T02_final.gff3
- **目标**: 使用转录组数据改进基因结构，特别是片段化的BUSCO基因

## PASA安装

### 方法1: 使用Conda安装

```bash
conda install -c bioconda pasa
```

### 方法2: 从源码安装

```bash
# 下载PASA
cd ~/Biosofts
git clone https://github.com/PASApipeline/PASApipeline.git
cd PASApipeline
make

# 设置环境变量
export PASA_HOME=~/Biosofts/PASApipeline
export PATH=$PASA_HOME/bin:$PATH
```

## PASA工作流程

### 步骤1: 准备数据

1. **基因组序列** (FASTA格式)
   - 文件: `annotation/T01/T01_genome.masked.fa`

2. **转录组GTF文件**
   - 文件: `annotation/T01/transcriptome/T01_merged.gtf`

3. **现有注释** (可选)
   - 文件: `annotation/T01/structure/T01_final.gff3`

### 步骤2: 配置PASA数据库

PASA需要MySQL数据库。如果未安装MySQL，可以使用SQLite（PASA 2.4.1+支持）。

```bash
# 创建PASA配置文件
cat > pasa_align.config << EOF
##################################################
# PASA Align Configuration File
##################################################

# MySQL database (如果使用MySQL)
DATABASE=target_pasa
DBUSER=root
DBPASS=

# 或使用SQLite (推荐，无需MySQL)
PASA_DB=target_pasa.sqlite

# 基因组文件
GENOME_FILE=${PROJECT_ROOT}/annotation/T01/T01_genome.masked.fa

# 转录组GTF文件
TRANSCRIPT_GTF=${PROJECT_ROOT}/annotation/T01/transcriptome/T01_merged.gff3

# 线程数
CPU=32

# 对齐参数
MIN_PERCENT_ALIGNED=80
MIN_AVG_PER_ID=95
MIN_BLAST_HIT_LENGTH=100
EOF
```

### 步骤3: 转换GTF为GFF3

PASA需要GFF3格式的转录组数据：

```bash
# 使用gffread转换
gffread -E annotation/T01/transcriptome/T01_merged.gtf \
        -o annotation/T01/transcriptome/T01_merged.gff3
```

### 步骤4: 运行PASA对齐

```bash
# 对齐转录组到基因组
PASA.pl \
    -c pasa_align.config \
    -C -R \
    -g annotation/T01/T01_genome.masked.fa \
    -t annotation/T01/transcriptome/T01_merged.gff3 \
    --ALIGNERS gmap,blat \
    --CPU 32
```

### 步骤5: 更新现有注释

```bash
# 使用PASA更新现有注释
PASA.pl \
    -c pasa_align.config \
    -g annotation/T01/T01_genome.masked.fa \
    -t annotation/T01/transcriptome/T01_merged.gff3 \
    -u annotation/T01/structure/T01_final.gff3 \
    --ALIGNERS gmap,blat \
    --CPU 32
```

### 步骤6: 提取更新的注释

```bash
# 从PASA数据库提取更新的注释
# 输出文件通常在 pasa_assemblies.gff3
cp pasa_assemblies.gff3 annotation/T01/structure/T01_pasa_updated.gff3
```

## 替代方案（如果PASA不可用）

### 方案1: 使用gffcompare + 手动整合

```bash
# 比较现有注释和转录组
gffcompare -r annotation/T01/structure/T01_final.gff3 \
           -o comparison \
           annotation/T01/transcriptome/T01_merged.gtf

# 查看比较结果
cat comparison.tracking
```

### 方案2: 使用StringTie合并

```bash
# 合并现有注释和转录组
stringtie --merge \
          -p 32 \
          -o T01_merged_updated.gtf \
          -G annotation/T01/structure/T01_final.gff3 \
          gtf_list.txt
```

### 方案3: 使用TACO

```bash
# 合并转录本
taco_run -p 32 \
         -o taco_output \
         annotation/T01/structure/T01_final.gtf \
         annotation/T01/transcriptome/T01_merged.gtf
```

## 针对片段化BUSCO基因的改进

### 步骤1: 提取片段化基因

```bash
# 使用之前创建的脚本
bash scripts/extract_problematic_buscos.sh T01
```

### 步骤2: 检查转录组支持

```bash
# 检查片段化基因是否有转录组支持
grep -f annotation/improvement/T01/fragmented_gene_ids.txt \
      annotation/T01/transcriptome/T01_merged.gtf > \
      annotation/improvement/T01/fragmented_with_transcriptome.gtf
```

### 步骤3: 使用PASA改进这些基因

```bash
# 针对片段化基因运行PASA
# 可以只对这些基因区域运行PASA，提高效率
```

## 验证改进效果

### 重新运行BUSCO评估

```bash
# 提取更新后的蛋白质序列
gffread -y annotation/T01/structure/T01_pasa_updated.gff3 \
        -g annotation/T01/T01_genome.masked.fa \
        -x annotation/T01/structure/T01_pasa_updated.cds.fa

# 翻译为蛋白质
transeq annotation/T01/structure/T01_pasa_updated.cds.fa \
         annotation/T01/structure/T01_pasa_updated.pep.fa

# 重新运行BUSCO
bash scripts/run_busco_annotation.sh
```

## 注意事项

1. **PASA需要大量内存**: 建议至少32GB RAM
2. **运行时间**: 可能需要数小时到数天
3. **数据库配置**: 如果使用MySQL，需要正确配置
4. **对齐工具**: 需要安装gmap或blat
5. **质量检查**: 更新后需要验证改进效果

## 推荐工作流程

1. **快速改进** (1-2天):
   - 使用gffcompare识别问题
   - 使用StringTie合并改进明显的问题

2. **深度改进** (1-2周):
   - 安装和配置PASA
   - 运行完整的PASA更新流程
   - 验证改进效果

3. **迭代优化**:
   - 重新运行BUSCO评估
   - 识别仍需要改进的基因
   - 重复改进流程

## 脚本使用

已创建的脚本：

1. **update_annotation_with_transcriptome.sh**: 
   - 自动尝试多种更新方法
   - 不依赖PASA，使用gffcompare和StringTie

2. **run_pasa_update.sh**: 
   - 完整的PASA更新流程
   - 需要PASA已安装

```bash
# 使用替代方法（推荐，不依赖PASA）
bash scripts/update_annotation_with_transcriptome.sh T01

# 使用PASA（如果已安装）
bash scripts/run_pasa_update.sh T01
```

