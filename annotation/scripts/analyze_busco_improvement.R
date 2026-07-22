#!/usr/bin/env Rscript
# 分析BUSCO完整度改进方案

suppressPackageStartupMessages({
  library(dplyr)
})

work_dir <- "${PROJECT_ROOT}"
setwd(work_dir)

output_dir <- file.path(work_dir, "annotation", "evaluation", "busco", "improvement_analysis")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# 分析缺失和片段化的BUSCO基因
analyze_busco_status <- function(species) {
  cat(sprintf("\n=== 分析 %s 样本 ===\n", species))
  
  full_table <- file.path(work_dir, "annotation", "evaluation", "busco", 
                         species, species, "run_embryophyta_odb10", "full_table.tsv")
  
  if (!file.exists(full_table)) {
    cat(sprintf("文件不存在: %s\n", full_table))
    return(NULL)
  }
  
  # 读取完整表格
  data <- read.delim(full_table, sep = "\t", stringsAsFactors = FALSE, 
                    comment.char = "#", check.names = FALSE)
  
  # 统计
  total <- nrow(data)
  complete <- sum(data$Status == "Complete")
  fragmented <- sum(data$Status == "Fragmented")
  missing <- sum(data$Status == "Missing")
  
  cat(sprintf("总BUSCO数: %d\n", total))
  cat(sprintf("完整: %d (%.2f%%)\n", complete, complete/total*100))
  cat(sprintf("片段化: %d (%.2f%%)\n", fragmented, fragmented/total*100))
  cat(sprintf("缺失: %d (%.2f%%)\n", missing, missing/total*100))
  
  # 分析片段化基因
  fragmented_genes <- data[data$Status == "Fragmented", ]
  if (nrow(fragmented_genes) > 0) {
    cat(sprintf("\n片段化基因分析:\n"))
    cat(sprintf("  有匹配的基因数: %d\n", sum(!is.na(fragmented_genes$Sequence))))
    
    # 检查片段化基因的长度
    if ("Length" %in% colnames(fragmented_genes)) {
      cat(sprintf("  平均长度: %.0f aa\n", mean(fragmented_genes$Length, na.rm = TRUE)))
      cat(sprintf("  最短: %d aa\n", min(fragmented_genes$Length, na.rm = TRUE)))
      cat(sprintf("  最长: %d aa\n", max(fragmented_genes$Length, na.rm = TRUE)))
    }
  }
  
  # 分析缺失基因
  missing_genes <- data[data$Status == "Missing", ]
  if (nrow(missing_genes) > 0) {
    cat(sprintf("\n缺失基因分析:\n"))
    cat(sprintf("  缺失的BUSCO ID数: %d\n", nrow(missing_genes)))
  }
  
  return(list(
    species = species,
    data = data,
    fragmented = fragmented_genes,
    missing = missing_genes,
    stats = list(
      total = total,
      complete = complete,
      fragmented = fragmented,
      missing = missing
    )
  ))
}

# 分析两个样本
bh_result <- analyze_busco_status("T01")
ck_result <- analyze_busco_status("T02")

# 生成改进建议报告
report_file <- file.path(output_dir, "improvement_recommendations.txt")
sink(report_file)

cat("BUSCO完整度改进建议报告\n")
cat("=", rep("=", 60), "\n", sep = "")
cat(sprintf("生成时间: %s\n\n", Sys.time()))

cat("当前状态:\n")
cat(rep("-", 60), "\n", sep = "")
if (!is.null(bh_result)) {
  cat(sprintf("T01: Complete %.2f%%, Fragmented %.2f%%, Missing %.2f%%\n",
              bh_result$stats$complete/bh_result$stats$total*100,
              bh_result$stats$fragmented/bh_result$stats$total*100,
              bh_result$stats$missing/bh_result$stats$total*100))
}
if (!is.null(ck_result)) {
  cat(sprintf("T02: Complete %.2f%%, Fragmented %.2f%%, Missing %.2f%%\n",
              ck_result$stats$complete/ck_result$stats$total*100,
              ck_result$stats$fragmented/ck_result$stats$total*100,
              ck_result$stats$missing/ck_result$stats$total*100))
}

cat("\n\n改进建议:\n")
cat(rep("=", 60), "\n", sep = "")

cat("\n1. 改进注释质量 (针对片段化基因)\n")
cat(rep("-", 60), "\n", sep = "")
cat("   片段化基因通常是因为:\n")
cat("   - 基因预测不完整（缺少外显子）\n")
cat("   - 基因模型错误（错误的外显子边界）\n")
cat("   - 低质量区域导致预测中断\n")
cat("\n   改进方法:\n")
cat("   a) 使用更多证据来源改进注释:\n")
cat("      - 增加转录组数据覆盖度\n")
cat("      - 使用更多同源物种的蛋白质序列\n")
cat("      - 使用PASA或StringTie改进基因模型\n")
cat("   b) 重新运行基因预测:\n")
cat("      - 使用BRAKER2（结合转录组和蛋白质证据）\n")
cat("      - 使用MAKER（整合多种证据）\n")
cat("      - 调整AUGUSTUS参数\n")
cat("   c) 手动检查片段化基因:\n")
cat("      - 检查是否有对应的转录组支持\n")
cat("      - 检查同源物种中该基因的完整序列\n")
cat("      - 手动修正基因模型\n")

cat("\n2. 改进基因组组装 (针对缺失基因)\n")
cat(rep("-", 60), "\n", sep = "")
cat("   缺失基因可能因为:\n")
cat("   - 基因组组装不完整（基因位于未组装的contig上）\n")
cat("   - 基因在重复区域（难以组装）\n")
cat("   - 物种特异性缺失（真实缺失）\n")
cat("\n   改进方法:\n")
cat("   a) 检查缺失基因是否在未组装的序列中:\n")
cat("      - 在原始reads或contig中搜索\n")
cat("      - 检查是否有转录组证据\n")
cat("   b) 改进组装:\n")
cat("      - 增加测序深度\n")
cat("      - 使用长读长测序（PacBio/Nanopore）\n")
cat("      - 使用Hi-C或光学图谱改进scaffolding\n")
cat("   c) 检查是否为真实缺失:\n")
cat("      - 与近缘物种比较\n")
cat("      - 检查功能是否被其他基因替代\n")

cat("\n3. 优化注释流程\n")
cat(rep("-", 60), "\n", sep = "")
cat("   a) 使用多证据整合:\n")
cat("      - 转录组 + 同源蛋白质 + 从头预测\n")
cat("      - 使用EVM或MAKER整合多种证据\n")
cat("   b) 迭代改进:\n")
cat("      - 基于BUSCO结果识别问题区域\n")
cat("      - 针对性地改进这些区域的注释\n")
cat("      - 重新评估直到满意\n")
cat("   c) 质量控制:\n")
cat("      - 检查基因长度分布\n")
cat("      - 检查CDS完整性\n")
cat("      - 检查蛋白质序列质量\n")

cat("\n4. 具体操作步骤\n")
cat(rep("-", 60), "\n", sep = "")
cat("   步骤1: 识别问题基因\n")
cat("      - 提取片段化和缺失的BUSCO ID\n")
cat("      - 检查这些基因在注释中的状态\n")
cat("\n   步骤2: 收集证据\n")
cat("      - 在转录组数据中搜索这些基因\n")
cat("      - 在同源物种中查找完整序列\n")
cat("      - 检查基因组中是否有未注释的序列\n")
cat("\n   步骤3: 改进注释\n")
cat("      - 使用新证据重新预测基因\n")
cat("      - 手动修正明显错误的基因模型\n")
cat("      - 整合多源证据\n")
cat("\n   步骤4: 重新评估\n")
cat("      - 重新运行BUSCO评估\n")
cat("      - 检查改进效果\n")
cat("      - 迭代直到达到目标（>90%）\n")

# 计算潜在改进空间
if (!is.null(bh_result) && !is.null(ck_result)) {
  cat("\n\n潜在改进空间:\n")
  cat(rep("=", 60), "\n", sep = "")
  
  # 如果所有片段化都能修复
  bh_potential <- (bh_result$stats$complete + bh_result$stats$fragmented) / bh_result$stats$total * 100
  ck_potential <- (ck_result$stats$complete + ck_result$stats$fragmented) / ck_result$stats$total * 100
  
  cat(sprintf("\n如果修复所有片段化基因:\n"))
  cat(sprintf("  T01: 可从 %.2f%% 提升到 %.2f%%\n",
              bh_result$stats$complete/bh_result$stats$total*100,
              bh_potential))
  cat(sprintf("  T02: 可从 %.2f%% 提升到 %.2f%%\n",
              ck_result$stats$complete/ck_result$stats$total*100,
              ck_potential))
  
  cat(sprintf("\n目标: >90%% Complete\n"))
  cat(sprintf("  T01: 需要修复 %.0f 个片段化基因 (%.1f%%)\n",
              bh_result$stats$fragmented * 0.2, 20))
  cat(sprintf("  T02: 需要修复 %.0f 个片段化基因 (%.1f%%)\n",
              ck_result$stats$fragmented * 0.25, 25))
}

sink()

cat(sprintf("\n改进建议报告已保存至: %s\n", report_file))

# 导出片段化和缺失的BUSCO ID列表
if (!is.null(bh_result)) {
  write.table(bh_result$fragmented$Busco.id, 
              file.path(output_dir, "T01_fragmented_busco_ids.txt"),
              row.names = FALSE, col.names = FALSE, quote = FALSE)
  write.table(bh_result$missing$Busco.id, 
              file.path(output_dir, "T01_missing_busco_ids.txt"),
              row.names = FALSE, col.names = FALSE, quote = FALSE)
}

if (!is.null(ck_result)) {
  write.table(ck_result$fragmented$Busco.id, 
              file.path(output_dir, "T02_fragmented_busco_ids.txt"),
              row.names = FALSE, col.names = FALSE, quote = FALSE)
  write.table(ck_result$missing$Busco.id, 
              file.path(output_dir, "T02_missing_busco_ids.txt"),
              row.names = FALSE, col.names = FALSE, quote = FALSE)
}

cat("BUSCO ID列表已导出\n")
cat("处理完成！\n")

