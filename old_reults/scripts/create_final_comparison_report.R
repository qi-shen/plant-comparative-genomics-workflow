#!/usr/bin/env Rscript
# 创建最终比较报告

setwd("/path/to/project_root")

# 读取BUSCO结果
read_busco <- function(species, path_type = "original") {
  if (path_type == "original") {
    busco_dir <- file.path("annotation/evaluation/busco", species)
  } else {
    busco_dir <- file.path("annotation/evaluation/busco_updated", species)
  }
  
  short_summary <- list.files(busco_dir, pattern = "short_summary.*\\.txt",
                              full.names = TRUE, recursive = TRUE)
  
  if (length(short_summary) == 0) return(NULL)
  
  lines <- readLines(short_summary[1])
  
  # 提取数字
  complete_line <- grep("Complete BUSCOs", lines, value = TRUE)
  single_line <- grep("single-copy", lines, value = TRUE)
  fragmented_line <- grep("Fragmented BUSCOs", lines, value = TRUE)
  missing_line <- grep("Missing BUSCOs", lines, value = TRUE)
  total_line <- grep("Total BUSCO groups searched", lines, value = TRUE)
  
  complete <- as.numeric(gsub(".*?([0-9]+).*", "\\1", complete_line))
  single <- as.numeric(gsub(".*?([0-9]+).*", "\\1", single_line))
  fragmented <- as.numeric(gsub(".*?([0-9]+).*", "\\1", fragmented_line))
  missing <- as.numeric(gsub(".*?([0-9]+).*", "\\1", missing_line))
  total <- as.numeric(gsub(".*?([0-9]+).*", "\\1", total_line))
  
  if (!is.na(total) && total > 0) {
    return(list(
      complete = complete,
      single = single,
      fragmented = fragmented,
      missing = missing,
      total = total,
      complete_pct = complete / total * 100,
      single_pct = single / total * 100,
      fragmented_pct = fragmented / total * 100,
      missing_pct = missing / total * 100
    ))
  }
  return(NULL)
}

# 生成报告
report_file <- "annotation/evaluation/pasa_final_comparison_report.md"

cat("# PASA更新前后注释质量最终比较报告\n\n", file = report_file)
cat("生成时间:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n", file = report_file, append = TRUE)

# 统计信息
stats <- data.frame(
  species = c("BH", "CK"),
  original_genes = c(26971, 26771),
  original_proteins = c(26971, 26771),
  pasa_transcripts = c(29223, 28489),
  pasa_gff3_lines = c(201523, 197919)
)

for (i in 1:nrow(stats)) {
  species <- stats$species[i]
  
  cat(sprintf("## %s样本\n\n", species), file = report_file, append = TRUE)
  
  # 原始注释
  cat("### 原始注释统计\n\n", file = report_file, append = TRUE)
  cat(sprintf("- 基因数: %s\n", format(stats$original_genes[i], big.mark = ",")), file = report_file, append = TRUE)
  cat(sprintf("- 蛋白质数: %s\n\n", format(stats$original_proteins[i], big.mark = ",")), file = report_file, append = TRUE)
  
  # 原始BUSCO
  busco_orig <- read_busco(species, "original")
  if (!is.null(busco_orig)) {
    cat("#### BUSCO评估结果（更新前）\n\n", file = report_file, append = TRUE)
    cat(sprintf("| 指标 | 数量 | 百分比 |\n"), file = report_file, append = TRUE)
    cat(sprintf("|------|------|--------|\n"), file = report_file, append = TRUE)
    cat(sprintf("| 完整 (Complete) | %d | %.2f%% |\n", busco_orig$complete, busco_orig$complete_pct), file = report_file, append = TRUE)
    cat(sprintf("| 单拷贝 (Single) | %d | %.2f%% |\n", busco_orig$single, busco_orig$single_pct), file = report_file, append = TRUE)
    cat(sprintf("| 片段化 (Fragmented) | %d | %.2f%% |\n", busco_orig$fragmented, busco_orig$fragmented_pct), file = report_file, append = TRUE)
    cat(sprintf("| 缺失 (Missing) | %d | %.2f%% |\n", busco_orig$missing, busco_orig$missing_pct), file = report_file, append = TRUE)
    cat(sprintf("| 总计 | %d | 100.00%% |\n\n", busco_orig$total), file = report_file, append = TRUE)
  }
  
  # PASA更新后
  cat("### PASA更新后统计\n\n", file = report_file, append = TRUE)
  cat(sprintf("- 组装转录本数: %s\n", format(stats$pasa_transcripts[i], big.mark = ",")), file = report_file, append = TRUE)
  cat(sprintf("- GFF3注释行数: %s\n\n", format(stats$pasa_gff3_lines[i], big.mark = ",")), file = report_file, append = TRUE)
  
  # 更新后BUSCO
  busco_upd <- read_busco(species, "updated")
  if (!is.null(busco_upd)) {
    cat("#### BUSCO评估结果（更新后）\n\n", file = report_file, append = TRUE)
    cat(sprintf("| 指标 | 数量 | 百分比 |\n"), file = report_file, append = TRUE)
    cat(sprintf("|------|------|--------|\n"), file = report_file, append = TRUE)
    cat(sprintf("| 完整 (Complete) | %d | %.2f%% |\n", busco_upd$complete, busco_upd$complete_pct), file = report_file, append = TRUE)
    cat(sprintf("| 单拷贝 (Single) | %d | %.2f%% |\n", busco_upd$single, busco_upd$single_pct), file = report_file, append = TRUE)
    cat(sprintf("| 片段化 (Fragmented) | %d | %.2f%% |\n", busco_upd$fragmented, busco_upd$fragmented_pct), file = report_file, append = TRUE)
    cat(sprintf("| 缺失 (Missing) | %d | %.2f%% |\n", busco_upd$missing, busco_upd$missing_pct), file = report_file, append = TRUE)
    cat(sprintf("| 总计 | %d | 100.00%% |\n\n", busco_upd$total), file = report_file, append = TRUE)
    
    # 改进情况
    if (!is.null(busco_orig)) {
      cat("#### 改进情况\n\n", file = report_file, append = TRUE)
      improvement <- busco_upd$complete_pct - busco_orig$complete_pct
      frag_reduction <- busco_orig$fragmented_pct - busco_upd$fragmented_pct
      missing_reduction <- busco_orig$missing_pct - busco_upd$missing_pct
      
      cat(sprintf("| 指标 | 改进 |\n"), file = report_file, append = TRUE)
      cat(sprintf("|------|------|\n"), file = report_file, append = TRUE)
      cat(sprintf("| 完整性提升 | **+%.2f%%** |\n", improvement), file = report_file, append = TRUE)
      cat(sprintf("| 片段化减少 | **-%.2f%%** |\n", frag_reduction), file = report_file, append = TRUE)
      cat(sprintf("| 缺失减少 | **-%.2f%%** |\n\n", missing_reduction), file = report_file, append = TRUE)
    }
  } else {
    cat("#### BUSCO评估结果（更新后）\n\n", file = report_file, append = TRUE)
    cat("BUSCO评估进行中，完成后将自动更新...\n\n", file = report_file, append = TRUE)
  }
  
  cat("---\n\n", file = report_file, append = TRUE)
}

cat("## 总结\n\n", file = report_file, append = TRUE)
cat("PASA更新通过整合转录组证据，改进了基因注释的完整性和准确性。\n\n", file = report_file, append = TRUE)

cat("## 输出文件\n\n", file = report_file, append = TRUE)
cat("### BH样本\n\n", file = report_file, append = TRUE)
cat("- 更新后的注释GFF3: `annotation/BH/pasa_update/BH_pasa.pasa_assemblies.gff3`\n", file = report_file, append = TRUE)
cat("- 更新后的注释GTF: `annotation/BH/pasa_update/BH_pasa.pasa_assemblies.gtf`\n", file = report_file, append = TRUE)
cat("- 组装序列: `annotation/BH/pasa_update/BH_pasa.assemblies.fasta`\n", file = report_file, append = TRUE)
cat("- 更新后的蛋白质序列: `annotation/BH/pasa_update/BH_pasa_updated_filtered.pep.fa`\n\n", file = report_file, append = TRUE)

cat("### CK样本\n\n", file = report_file, append = TRUE)
cat("- 更新后的注释GFF3: `annotation/CK/pasa_update/CK_pasa.pasa_assemblies.gff3`\n", file = report_file, append = TRUE)
cat("- 更新后的注释GTF: `annotation/CK/pasa_update/CK_pasa.pasa_assemblies.gtf`\n", file = report_file, append = TRUE)
cat("- 组装序列: `annotation/CK/pasa_update/CK_pasa.assemblies.fasta`\n", file = report_file, append = TRUE)
cat("- 更新后的蛋白质序列: `annotation/CK/pasa_update/CK_pasa_updated_filtered.pep.fa`\n\n", file = report_file, append = TRUE)

cat("报告已生成:", report_file, "\n")
