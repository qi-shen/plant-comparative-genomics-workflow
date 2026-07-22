#!/usr/bin/env Rscript
# 可视化PASA更新前后的BUSCO比较

library(ggplot2)
library(dplyr)

setwd("${PROJECT_ROOT}")

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
  
  complete <- as.numeric(gsub(".*?([0-9]+).*", "\\1", grep("Complete BUSCOs", lines, value = TRUE)))
  single <- as.numeric(gsub(".*?([0-9]+).*", "\\1", grep("single-copy", lines, value = TRUE)))
  fragmented <- as.numeric(gsub(".*?([0-9]+).*", "\\1", grep("Fragmented BUSCOs", lines, value = TRUE)))
  missing <- as.numeric(gsub(".*?([0-9]+).*", "\\1", grep("Missing BUSCOs", lines, value = TRUE)))
  total <- as.numeric(gsub(".*?([0-9]+).*", "\\1", grep("Total BUSCO groups searched", lines, value = TRUE)))
  
  if (!is.na(total) && total > 0) {
    return(data.frame(
      complete = complete,
      single = single,
      duplicated = complete - single,
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

# 收集数据
data_list <- list()

for (species in c("T01", "T02")) {
  orig <- read_busco(species, "original")
  upd <- read_busco(species, "updated")
  
  if (!is.null(orig)) {
    data_list[[paste0(species, "_original")]] <- data.frame(
      species = species,
      type = "更新前",
      complete = orig$complete_pct,
      fragmented = orig$fragmented_pct,
      missing = orig$missing_pct
    )
  }
  
  if (!is.null(upd)) {
    data_list[[paste0(species, "_updated")]] <- data.frame(
      species = species,
      type = "更新后",
      complete = upd$complete_pct,
      fragmented = upd$fragmented_pct,
      missing = upd$missing_pct
    )
  }
}

if (length(data_list) > 0) {
  plot_data <- do.call(rbind, data_list)
  plot_data$type <- factor(plot_data$type, levels = c("更新前", "更新后"))
  
  # 转换为长格式
  plot_data_long <- plot_data %>%
    tidyr::pivot_longer(cols = c(complete, fragmented, missing),
                        names_to = "category",
                        values_to = "percentage")
  
  plot_data_long$category <- factor(plot_data_long$category,
                                    levels = c("complete", "fragmented", "missing"),
                                    labels = c("完整", "片段化", "缺失"))
  
  # 创建堆叠柱状图
  p <- ggplot(plot_data_long, aes(x = type, y = percentage, fill = category)) +
    geom_bar(stat = "identity", position = "stack") +
    facet_wrap(~ species, ncol = 2) +
    scale_fill_manual(values = c("完整" = "#00BFAE", "片段化" = "#FF7F0E", "缺失" = "#D62728")) +
    labs(title = "PASA更新前后BUSCO完整性比较",
         x = "", y = "百分比 (%)", fill = "类别") +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
          strip.text = element_text(size = 12, face = "bold"),
          axis.text = element_text(size = 10),
          legend.position = "bottom")
  
  # 保存图片
  pdf_file <- "annotation/evaluation/busco_comparison.pdf"
  ggsave(pdf_file, p, width = 10, height = 6)
  cat("图表已保存到:", pdf_file, "\n")
} else {
  cat("BUSCO结果尚未全部完成，稍后生成图表\n")
}
