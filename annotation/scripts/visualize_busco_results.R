#!/usr/bin/env Rscript
# BUSCO结果可视化脚本

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

# 设置工作目录
work_dir <- "${PROJECT_ROOT}"
setwd(work_dir)

output_dir <- file.path(work_dir, "annotation", "evaluation", "busco")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# 解析BUSCO结果
parse_busco_summary <- function(species) {
  result_dir <- file.path(output_dir, species)
  short_summary <- list.files(result_dir, pattern = "short_summary.*\\.txt", 
                              full.names = TRUE, recursive = TRUE)
  
  if (length(short_summary) == 0) {
    return(NULL)
  }
  
  summary_file <- short_summary[1]
  lines <- readLines(summary_file)
  
  # 提取关键信息
  result <- list()
  result$species <- species
  
  # 首先尝试从数字行提取（更可靠）
  complete_line_num <- grep("Complete BUSCOs", lines, value = TRUE)
  single_line_num <- grep("single-copy", lines, value = TRUE)
  duplicated_line_num <- grep("duplicated", lines, value = TRUE)
  fragmented_line_num <- grep("Fragmented", lines, value = TRUE)
  missing_line_num <- grep("Missing", lines, value = TRUE)
  total_line_num <- grep("Total BUSCO groups", lines, value = TRUE)
  
  # 提取数字（使用制表符分隔）
  complete_num <- if (length(complete_line_num) > 0) {
    as.numeric(strsplit(trimws(complete_line_num[1]), "\\s+")[[1]][1])
  } else { NA }
  
  single_num <- if (length(single_line_num) > 0) {
    as.numeric(strsplit(trimws(single_line_num[1]), "\\s+")[[1]][1])
  } else { NA }
  
  duplicated_num <- if (length(duplicated_line_num) > 0) {
    as.numeric(strsplit(trimws(duplicated_line_num[1]), "\\s+")[[1]][1])
  } else { NA }
  
  fragmented_num <- if (length(fragmented_line_num) > 0) {
    as.numeric(strsplit(trimws(fragmented_line_num[1]), "\\s+")[[1]][1])
  } else { NA }
  
  missing_num <- if (length(missing_line_num) > 0) {
    as.numeric(strsplit(trimws(missing_line_num[1]), "\\s+")[[1]][1])
  } else { NA }
  
  total_num <- if (length(total_line_num) > 0) {
    as.numeric(strsplit(trimws(total_line_num[1]), "\\s+")[[1]][1])
  } else { 1614 }
  
  # 设置默认值
  if (is.na(total_num) || total_num == 0) total_num <- 1614
  if (is.na(complete_num)) complete_num <- 0
  if (is.na(single_num)) single_num <- 0
  if (is.na(duplicated_num)) duplicated_num <- 0
  if (is.na(fragmented_num)) fragmented_num <- 0
  if (is.na(missing_num)) missing_num <- 0
  
  # 计算百分比
  result$total <- total_num
  result$complete <- complete_num
  result$single <- single_num
  result$duplicated <- duplicated_num
  result$fragmented <- fragmented_num
  result$missing <- missing_num
  
  result$complete_pct <- complete_num / total_num * 100
  result$single_pct <- single_num / total_num * 100
  result$duplicated_pct <- duplicated_num / total_num * 100
  result$fragmented_pct <- fragmented_num / total_num * 100
  result$missing_pct <- missing_num / total_num * 100
  
  return(result)
}

# 读取结果
species_list <- c("T01", "T02")
results_list <- list()

for (species in species_list) {
  cat(sprintf("解析 %s 的BUSCO结果...\n", species))
  result <- parse_busco_summary(species)
  if (!is.null(result)) {
    results_list[[species]] <- result
  }
}

if (length(results_list) == 0) {
  cat("未找到BUSCO结果文件，请先运行BUSCO评估\n")
  quit(status = 1)
}

# 准备数据
plot_data <- data.frame(
  Species = character(),
  Category = character(),
  Percentage = numeric(),
  Count = numeric(),
  stringsAsFactors = FALSE
)

for (species in names(results_list)) {
  res <- results_list[[species]]
  
  # 确保所有值都存在
  if (is.null(res$single_pct) || is.na(res$single_pct)) res$single_pct <- 0
  if (is.null(res$duplicated_pct) || is.na(res$duplicated_pct)) res$duplicated_pct <- 0
  if (is.null(res$fragmented_pct) || is.na(res$fragmented_pct)) res$fragmented_pct <- 0
  if (is.null(res$missing_pct) || is.na(res$missing_pct)) res$missing_pct <- 0
  if (is.null(res$single) || is.na(res$single)) res$single <- 0
  if (is.null(res$duplicated) || is.na(res$duplicated)) res$duplicated <- 0
  if (is.null(res$fragmented) || is.na(res$fragmented)) res$fragmented <- 0
  if (is.null(res$missing) || is.na(res$missing)) res$missing <- 0
  
  plot_data <- rbind(plot_data,
    data.frame(Species = species, Category = "Complete (Single)", 
               Percentage = res$single_pct, Count = res$single, stringsAsFactors = FALSE),
    data.frame(Species = species, Category = "Complete (Duplicated)", 
               Percentage = res$duplicated_pct, Count = res$duplicated, stringsAsFactors = FALSE),
    data.frame(Species = species, Category = "Fragmented", 
               Percentage = res$fragmented_pct, Count = res$fragmented, stringsAsFactors = FALSE),
    data.frame(Species = species, Category = "Missing", 
               Percentage = res$missing_pct, Count = res$missing, stringsAsFactors = FALSE)
  )
}

# 设置因子顺序
plot_data$Category <- factor(plot_data$Category, 
                             levels = c("Complete (Single)", "Complete (Duplicated)", 
                                       "Fragmented", "Missing"))

# 生成可视化
plot_file <- file.path(output_dir, "busco_results_visualization.pdf")
pdf(plot_file, width = 12, height = 8)

# 1. 堆叠条形图
p1 <- ggplot(plot_data, aes(x = Species, y = Percentage, fill = Category)) +
  geom_bar(stat = "identity", position = "stack") +
  scale_fill_manual(values = c(
    "Complete (Single)" = "#00BFAE",
    "Complete (Duplicated)" = "#1F77B4",
    "Fragmented" = "#FF7F0E",
    "Missing" = "#D62728"
  )) +
  labs(title = "BUSCO评估结果 - 百分比", 
       x = "样本", 
       y = "百分比 (%)",
       fill = "类别") +
  ylim(0, 100) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(color = "black"),
        panel.border = element_rect(color = "black", fill = NA),
        legend.position = "right")
print(p1)

# 2. 分组条形图
p2 <- ggplot(plot_data, aes(x = Category, y = Percentage, fill = Species)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_manual(values = c("T01" = "#00BFAE", "T02" = "#1F77B4")) +
  labs(title = "BUSCO评估结果比较", 
       x = "类别", 
       y = "百分比 (%)",
       fill = "样本") +
  ylim(0, max(plot_data$Percentage) * 1.1) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(color = "black"),
        panel.border = element_rect(color = "black", fill = NA),
        axis.text.x = element_text(angle = 45, hjust = 1))
print(p2)

# 3. 完整度比较
complete_data <- data.frame(
  Species = names(results_list),
  Complete = sapply(results_list, function(x) x$complete_pct),
  Single = sapply(results_list, function(x) x$single_pct),
  Duplicated = sapply(results_list, function(x) x$duplicated_pct)
)

p3 <- ggplot(complete_data, aes(x = Species)) +
  geom_bar(aes(y = Complete, fill = "Complete"), stat = "identity", alpha = 0.7) +
  geom_bar(aes(y = Single, fill = "Single-copy"), stat = "identity") +
  scale_fill_manual(values = c("Complete" = "#1F77B4", "Single-copy" = "#00BFAE"),
                   name = "类型") +
  labs(title = "BUSCO完整度比较", 
       x = "样本", 
       y = "百分比 (%)") +
  ylim(0, 100) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(color = "black"),
        panel.border = element_rect(color = "black", fill = NA))
print(p3)

dev.off()

cat(sprintf("\n可视化图表已保存至: %s\n", plot_file))

# 生成文本报告
report_file <- file.path(output_dir, "busco_detailed_report.txt")
sink(report_file)

cat("BUSCO注释评估详细报告\n")
cat("=", rep("=", 50), "\n", sep = "")
cat(sprintf("生成时间: %s\n\n", Sys.time()))

for (species in names(results_list)) {
  res <- results_list[[species]]
  cat(sprintf("\n【%s 样本】\n", species))
  cat(rep("-", 60), "\n", sep = "")
  cat(sprintf("总BUSCO组数: %d\n", res$total))
  cat(sprintf("\n完整 (Complete): %.2f%% (%d)\n", res$complete_pct, res$complete))
  cat(sprintf("  单拷贝 (Single-copy): %.2f%% (%d)\n", res$single_pct, res$single))
  cat(sprintf("  重复 (Duplicated): %.2f%% (%d)\n", res$duplicated_pct, res$duplicated))
  cat(sprintf("片段化 (Fragmented): %.2f%% (%d)\n", res$fragmented_pct, res$fragmented))
  cat(sprintf("缺失 (Missing): %.2f%% (%d)\n", res$missing_pct, res$missing))
  
  # 质量评估
  cat("\n质量评估:\n")
  if (res$complete_pct >= 90) {
    quality <- "优秀"
  } else if (res$complete_pct >= 80) {
    quality <- "良好"
  } else if (res$complete_pct >= 70) {
    quality <- "中等"
  } else {
    quality <- "需要改进"
  }
  cat(sprintf("  完整度: %.2f%% - %s\n", res$complete_pct, quality))
  
  if (res$single_pct >= 80) {
    cat("  单拷贝比例: 优秀\n")
  } else if (res$single_pct >= 70) {
    cat("  单拷贝比例: 良好\n")
  } else {
    cat("  单拷贝比例: 需要关注\n")
  }
}

# 比较
if (length(results_list) == 2) {
  cat("\n\n【T01 vs T02 比较】\n")
  cat(rep("-", 60), "\n", sep = "")
  
  bh_res <- results_list[["T01"]]
  ck_res <- results_list[["T02"]]
  
  cat(sprintf("完整度差异: %.2f%% (T01: %.2f%%, T02: %.2f%%)\n",
              abs(bh_res$complete_pct - ck_res$complete_pct),
              bh_res$complete_pct, ck_res$complete_pct))
  
  cat(sprintf("单拷贝差异: %.2f%% (T01: %.2f%%, T02: %.2f%%)\n",
              abs(bh_res$single_pct - ck_res$single_pct),
              bh_res$single_pct, ck_res$single_pct))
  
  cat(sprintf("缺失差异: %.2f%% (T01: %.2f%%, T02: %.2f%%)\n",
              abs(bh_res$missing_pct - ck_res$missing_pct),
              bh_res$missing_pct, ck_res$missing_pct))
}

sink()

cat(sprintf("详细报告已保存至: %s\n", report_file))
cat("\n处理完成！\n")

