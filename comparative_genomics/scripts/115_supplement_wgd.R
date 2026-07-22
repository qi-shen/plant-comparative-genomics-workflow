#!/usr/bin/env Rscript
# WGD 补充图表：(1) Ks高斯混合拟合峰 (2) 种间ortholog Ks分布
# 数据来源: 现有 04_wgd/ 结果

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(scales)
})

BASE <- "/path/to/project_root/comparative_genomics"
OUT_DIR <- file.path(BASE, "figures_supplement")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

theme_pub <- function(base_size = 12) {
  theme_classic(base_size = base_size) +
    theme(
      panel.grid = element_blank(),
      axis.line = element_line(color = "black", linewidth = 0.4),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      legend.title = element_blank()
    )
}

ks_species <- c("BH", "CK", "TAU", "TCH", "RSO")
ks_colors <- c(BH = "#00BFAE", CK = "#1F77B4", TAU = "#9467BD",
               TCH = "#FF7F0E", RSO = "#D62728")

# ============================================================
# 补充图1: Ks分布 + 高斯拟合峰标注
# ============================================================
cat("生成 WGD 补充图1: Ks高斯拟合...\n")

ks_file <- file.path(BASE, "04_wgd/ks_all_results.tsv")
ks_all <- fread(ks_file, select = c("Species", "Ks"))
ks_all <- ks_all[!is.na(Ks) & Ks > 0 & Ks <= 5 & Species %in% ks_species]

# 对每个物种找密度峰
peak_data <- ks_all[Ks <= 3, {
  d <- density(Ks, adjust = 1.2)
  peak_idx <- which.max(d$y)
  list(peak_ks = d$x[peak_idx], peak_density = d$y[peak_idx])
}, by = Species]

p_ks_peak <- ggplot(ks_all[Ks <= 3], aes(x = Ks)) +
  geom_histogram(aes(y = after_stat(density)), bins = 80,
                 fill = "grey80", color = "white", linewidth = 0.2) +
  geom_density(aes(color = Species), linewidth = 0.8, adjust = 1.2) +
  geom_vline(data = peak_data, aes(xintercept = peak_ks, color = Species),
             linetype = "dashed", linewidth = 0.5) +
  geom_text(data = peak_data,
            aes(x = peak_ks, y = peak_density * 1.1,
                label = sprintf("%.2f", peak_ks), color = Species),
            size = 3, hjust = -0.1, show.legend = FALSE) +
  scale_color_manual(values = ks_colors) +
  facet_wrap(~ Species, ncol = 3, scales = "free_y") +
  labs(x = expression(italic(K[s])),
       y = "Density",
       title = expression(paste(italic(K[s]), " distribution with peak identification"))) +
  theme_pub(10) +
  theme(legend.position = "none",
        strip.background = element_rect(fill = "grey95", color = NA))

ggsave(file.path(OUT_DIR, "WGD_Ks_peak_fitting.pdf"), p_ks_peak,
       width = 12, height = 8, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "WGD_Ks_peak_fitting.png"), p_ks_peak,
       width = 12, height = 8, dpi = 300)

# ============================================================
# 补充图2: Ks分布对比（叠加直方图+密度）
# ============================================================
cat("生成 WGD 补充图2: 分物种Ks分布对比...\n")

ks_summary <- fread(file.path(BASE, "04_wgd/ks_summary_stats.tsv"))
ks_summary <- ks_summary[Pair %in% ks_species]

p_ks_stats <- ggplot(ks_summary, aes(x = Pair)) +
  geom_col(aes(y = Count, fill = Pair), width = 0.6) +
  geom_point(aes(y = Mean_Ks * max(ks_summary$Count) / max(ks_summary$Mean_Ks)),
             size = 3, color = "black") +
  geom_point(aes(y = Median_Ks * max(ks_summary$Count) / max(ks_summary$Mean_Ks)),
             size = 3, color = "red", shape = 17) +
  scale_fill_manual(values = ks_colors) +
  scale_y_continuous(
    name = "Number of gene pairs",
    labels = comma,
    sec.axis = sec_axis(~ . * max(ks_summary$Mean_Ks) / max(ks_summary$Count),
                        name = expression(paste("Mean / Median ", italic(K[s]))))
  ) +
  labs(x = NULL,
       title = expression(paste(italic(K[s]), " summary statistics by species"))) +
  theme_pub(11) +
  theme(legend.position = "none")

ggsave(file.path(OUT_DIR, "WGD_Ks_summary_stats.pdf"), p_ks_stats,
       width = 8, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "WGD_Ks_summary_stats.png"), p_ks_stats,
       width = 8, height = 6, dpi = 300)

cat("WGD 补充图完成\n")
