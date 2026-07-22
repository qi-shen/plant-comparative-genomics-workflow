#!/usr/bin/env Rscript
# 比较PASA更新前后的注释质量

library(data.table)
library(ggplot2)

# 设置工作目录
setwd("${PROJECT_ROOT}")

# 读取原始注释统计
original_stats <- data.frame(
  species = c("T01", "T02"),
  genes = c(26971, 26771),
  transcripts = c(NA, NA),
  proteins = c(26971, 26771)
)

# 读取PASA更新后的统计
pasa_stats <- data.frame(
  species = c("T01", "T02"),
  assemblies = c(29223, 28489),
  gff3_lines = c(201523, 197919)
)

# 读取BUSCO结果（如果存在）
read_busco_summary <- function(species, path_type = "original") {
  if (path_type == "original") {
    busco_dir <- file.path("annotation/evaluation/busco", species)
  } else {
    busco_dir <- file.path("annotation/evaluation/busco_updated", species)
  }
  
  short_summary <- list.files(busco_dir, pattern = "short_summary.*\\.txt", 
                              full.names = TRUE, recursive = TRUE)
  
  if (length(short_summary) == 0) {
    return(NULL)
  }
  
  lines <- readLines(short_summary[1])
  
  complete_num <- as.numeric(gsub(".*Complete BUSCOs.*?([0-9]+).*", "\\1", 
                                   grep("Complete BUSCOs", lines, value = TRUE)))
  single_num <- as.numeric(gsub(".*single-copy.*?([0-9]+).*", "\\1", 
                                 grep("single-copy", lines, value = TRUE)))
  duplicated_num <- as.numeric(gsub(".*duplicated.*?([0-9]+).*", "\\1", 
                                     grep("duplicated", lines, value = TRUE)))
  fragmented_num <- as.numeric(gsub(".*Fragmented BUSCOs.*?([0-9]+).*", "\\1", 
                                     grep("Fragmented BUSCOs", lines, value = TRUE)))
  missing_num <- as.numeric(gsub(".*Missing BUSCOs.*?([0-9]+).*", "\\1", 
                                  grep("Missing BUSCOs", lines, value = TRUE)))
  total_num <- as.numeric(gsub(".*Total BUSCO groups searched.*?([0-9]+).*", "\\1", 
                                grep("Total BUSCO groups searched", lines, value = TRUE)))
  
  if (!is.na(total_num) && total_num > 0) {
    return(data.frame(
      complete = complete_num,
      single = single_num,
      duplicated = duplicated_num,
      fragmented = fragmented_num,
      missing = missing_num,
      total = total_num,
      complete_pct = complete_num / total_num * 100,
      single_pct = single_num / total_num * 100,
      fragmented_pct = fragmented_num / total_num * 100,
      missing_pct = missing_num / total_num * 100
    ))
  }
  return(NULL)
}

# 读取BUSCO结果
busco_original <- list()
busco_updated <- list()

for (species in c("T01", "T02")) {
  busco_original[[species]] <- read_busco_summary(species, "original")
  busco_updated[[species]] <- read_busco_summary(species, "updated")
}

# 生成比较报告
cat("\n==========================================\n")
cat("PASA更新前后注释质量比较报告\n")
cat("==========================================\n\n")

for (species in c("T01", "T02")) {
  cat(sprintf("\n%s样本:\n", species))
  cat("------------------------------------------\n")
  cat(sprintf("原始注释:\n"))
  cat(sprintf("  基因数: %d\n", original_stats$genes[original_stats$species == species]))
  cat(sprintf("  蛋白质数: %d\n", original_stats$proteins[original_stats$species == species]))
  
  if (!is.null(busco_original[[species]])) {
    cat(sprintf("  BUSCO完整性: %.2f%%\n", busco_original[[species]]$complete_pct))
    cat(sprintf("  单拷贝: %.2f%%\n", busco_original[[species]]$single_pct))
    cat(sprintf("  片段化: %.2f%%\n", busco_original[[species]]$fragmented_pct))
    cat(sprintf("  缺失: %.2f%%\n", busco_original[[species]]$missing_pct))
  }
  
  cat(sprintf("\nPASA更新后:\n"))
  cat(sprintf("  组装转录本数: %d\n", pasa_stats$assemblies[pasa_stats$species == species]))
  cat(sprintf("  GFF3行数: %d\n", pasa_stats$gff3_lines[pasa_stats$species == species]))
  
  if (!is.null(busco_updated[[species]])) {
    cat(sprintf("  BUSCO完整性: %.2f%%\n", busco_updated[[species]]$complete_pct))
    cat(sprintf("  单拷贝: %.2f%%\n", busco_updated[[species]]$single_pct))
    cat(sprintf("  片段化: %.2f%%\n", busco_updated[[species]]$fragmented_pct))
    cat(sprintf("  缺失: %.2f%%\n", busco_updated[[species]]$missing_pct))
    
    if (!is.null(busco_original[[species]])) {
      improvement <- busco_updated[[species]]$complete_pct - busco_original[[species]]$complete_pct
      cat(sprintf("\n改进:\n"))
      cat(sprintf("  完整性提升: %.2f%%\n", improvement))
      cat(sprintf("  片段化减少: %.2f%%\n", 
                  busco_original[[species]]$fragmented_pct - busco_updated[[species]]$fragmented_pct))
      cat(sprintf("  缺失减少: %.2f%%\n", 
                  busco_original[[species]]$missing_pct - busco_updated[[species]]$missing_pct))
    }
  } else {
    cat("  BUSCO评估进行中...\n")
  }
}

# 保存报告
report_file <- "annotation/evaluation/pasa_comparison_report.txt"
dir.create(dirname(report_file), showWarnings = FALSE, recursive = TRUE)
sink(report_file)
cat("\n==========================================\n")
cat("PASA更新前后注释质量比较报告\n")
cat("生成时间:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("==========================================\n\n")
# 重新输出内容
sink()

cat("\n报告已保存到:", report_file, "\n")
