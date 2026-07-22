# 提高BUSCO完整度的方法

## 当前状态

- **BH样本**: 88.3% Complete (1426/1614)
  - Fragmented: 7.8% (126)
  - Missing: 3.9% (62)
  
- **CK样本**: 87.6% Complete (1414/1614)
  - Fragmented: 8.5% (137)
  - Missing: 3.9% (63)

## 改进目标

- **短期目标**: >90% Complete
- **长期目标**: >95% Complete

## 改进方法

### 1. 针对片段化基因 (Fragmented) - 优先级高

片段化基因通常有部分匹配，说明基因存在但预测不完整。

#### 方法A: 改进基因注释

**步骤1: 识别片段化基因**
```bash
# 提取片段化BUSCO ID
grep "Fragmented" annotation/evaluation/busco/T01/T01/run_embryophyta_odb10/full_table.tsv | cut -f1 > fragmented_busco_ids.txt
```

**步骤2: 使用转录组证据改进**
- 检查这些基因是否有转录组支持
- 使用PASA或StringTie改进基因模型
- 手动检查并修正明显错误的基因模型

**步骤3: 使用同源蛋白质改进**
- 在SwissProt/UniProt中查找同源序列
- 使用Exonerate或GeMoMa进行同源预测
- 整合到现有注释中

**步骤4: 重新运行基因预测**
```bash
# 使用BRAKER2（推荐）
braker.pl --genome=genome.fa --bam=transcriptome.bam --prot_seq=proteins.fa --species=species

# 或使用MAKER
maker -genome genome.fa -base annotation_name
```

#### 方法B: 调整预测参数

- 降低AUGUSTUS的min_intron_len参数
- 增加外显子预测的灵敏度
- 使用更宽松的基因边界检测

### 2. 针对缺失基因 (Missing) - 优先级中

缺失基因可能真的不存在，也可能在未组装的区域。

#### 方法A: 检查未组装的序列

**步骤1: 在原始数据中搜索**
```bash
# 在原始reads中搜索缺失的BUSCO序列
# 使用BUSCO数据库中的HMM模型
hmmsearch missing_busco.hmm raw_reads.fa > missing_in_reads.txt
```

**步骤2: 检查未组装的contig**
- 在scaffold的gap区域搜索
- 检查是否有未组装的contig包含这些基因

#### 方法B: 改进基因组组装

- 增加测序深度
- 使用长读长测序（PacBio/Nanopore）填补gap
- 使用Hi-C数据改进scaffolding

#### 方法C: 检查是否为真实缺失

- 与近缘物种比较
- 检查功能是否被其他基因替代
- 某些基因可能在特定物种中确实缺失

### 3. 优化注释流程

#### 使用多证据整合

**推荐流程:**
1. **转录组证据** (StringTie/PASA)
2. **同源蛋白质证据** (Exonerate/GeMoMa)
3. **从头预测** (AUGUSTUS/BRAKER2)
4. **证据整合** (EVM/MAKER)

#### 迭代改进策略

1. 运行BUSCO评估
2. 识别问题基因（片段化+缺失）
3. 针对性地改进这些基因的注释
4. 重新运行BUSCO
5. 重复直到达到目标

### 4. 具体操作脚本

#### 脚本1: 提取问题基因并搜索证据

```bash
#!/bin/bash
# extract_problematic_buscos.sh

SPECIES="T01"
BUSCO_DIR="annotation/evaluation/busco/${SPECIES}/${SPECIES}/run_embryophyta_odb10"
OUTPUT_DIR="annotation/improvement/${SPECIES}"

mkdir -p "$OUTPUT_DIR"

# 提取片段化基因
grep "Fragmented" "${BUSCO_DIR}/full_table.tsv" | cut -f1,3 > "${OUTPUT_DIR}/fragmented_genes.txt"

# 提取缺失基因
grep "Missing" "${BUSCO_DIR}/full_table.tsv" | cut -f1 > "${OUTPUT_DIR}/missing_busco_ids.txt"

# 在转录组中搜索
# 这里需要根据实际情况调整
```

#### 脚本2: 使用BRAKER2重新注释

```bash
#!/bin/bash
# rerun_annotation_braker2.sh

GENOME="annotation/T01/BH_genome.masked.fa"
BAM="annotation/T01/transcriptome/BH_merged.bam"
PROTEINS="databases/uniprot_sprot.fasta"
OUTPUT="annotation/T01/braker2"

braker.pl \
    --genome="$GENOME" \
    --bam="$BAM" \
    --prot_seq="$PROTEINS" \
    --species=target_sp \
    --cores=32 \
    --softmasking \
    --gff3
```

### 5. 预期改进效果

如果成功修复所有片段化基因：
- **T01**: 可从 88.3% 提升到 **96.1%** (88.3% + 7.8%)
- **T02**: 可从 87.6% 提升到 **96.1%** (87.6% + 8.5%)

如果修复50%的片段化基因：
- **T01**: 可提升到 **92.2%** (88.3% + 3.9%)
- **T02**: 可提升到 **91.9%** (87.6% + 4.25%)

### 6. 推荐操作顺序

1. **快速改进** (1-2天):
   - 提取片段化基因列表
   - 检查是否有转录组支持
   - 手动修正明显错误的短基因

2. **中等改进** (1-2周):
   - 使用PASA改进基因模型
   - 使用同源蛋白质证据补充
   - 重新运行部分区域的注释

3. **深度改进** (1-2月):
   - 使用BRAKER2重新注释
   - 改进基因组组装（如有必要）
   - 全面质量检查

### 7. 注意事项

1. **片段化基因可能的原因**:
   - 基因预测不完整（最常见）
   - 低质量区域
   - 重复区域导致预测困难

2. **缺失基因可能的原因**:
   - 真实缺失（物种特异性）
   - 未组装的区域
   - 重复区域难以组装

3. **改进的权衡**:
   - 过度修正可能导致假阳性
   - 需要平衡完整度和准确性
   - 建议逐步改进并验证

### 8. 验证改进效果

每次改进后：
```bash
# 重新运行BUSCO
bash scripts/run_busco_annotation.sh

# 比较改进前后
diff annotation/evaluation/busco/BUSCO_annotation_summary.txt \
      annotation/evaluation/busco/BUSCO_annotation_summary_improved.txt
```

## 总结

当前完整度已经很好（>87%），但要达到>90%的目标，主要需要：

1. **优先处理片段化基因** - 这些基因存在但预测不完整
2. **使用多证据整合** - 结合转录组、同源蛋白质和从头预测
3. **迭代改进** - 逐步优化，每次改进后重新评估

预计通过改进片段化基因，可以将完整度提升到>90%。

