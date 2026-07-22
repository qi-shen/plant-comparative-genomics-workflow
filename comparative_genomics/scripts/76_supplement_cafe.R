#!/usr/bin/env Rscript
# CAFE 补充图: (1) 全15物种扩张/收缩总结 (2) 扩张/收缩热图Top100
# 数据来源: CAFE5 新结果

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

BASE <- "${PROJECT_ROOT}/comparative_genomics"
CAFE_DIR <- file.path(BASE, "07_cafe/cafe_results_calibrated")
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

palette14 <- c("#00BFAE", "#1F77B4", "#9467BD", "#FF7F0E", "#D62728",
               "#F08080", "#8B4513", "#228B22", "#90EE90", "#00008B",
               "#DDA0DD", "#006400", "#8B0000", "#ADD8E6")

species_order <- c("T01", "T02", "C02", "C03", "C01",
                   "C04", "O01", "C05", "C06", "C08",
                   "C07", "C09", "C10", "C11", "O02")

# 读取CAFE结果
change <- fread(file.path(CAFE_DIR, "Base_change.tab"))
family_res <- fread(file.path(CAFE_DIR, "Base_family_results.txt"))
sig_families <- family_res[pvalue < 0.05]$`#FamilyID`
change_sig <- change[FamilyID %in% sig_families]

# 提取物种列（排除内部节点）
sp_cols <- grep("<", names(change), value = TRUE)
sp_cols <- sp_cols[sp_cols != "FamilyID"]

# 仅保留叶节点（物种）
leaf_cols <- sp_cols[sub("<.*", "", sp_cols) %in% species_order]
leaf_names <- sub("<.*", "", leaf_cols)

# ============================================================
# 补充图1: 全15物种扩张/收缩数量
# ============================================================
cat("生成 CAFE 补充图1: 全物种扩张/收缩...\n")

cafe_summary <- data.table()
for (i in seq_along(leaf_cols)) {
  col <- leaf_cols[i]
  sp <- leaf_names[i]
  vals <- as.numeric(change_sig[[col]])
  cafe_summary <- rbind(cafe_summary, data.table(
    Species = sp,
    Expanded = sum(vals > 0, na.rm = TRUE),
    Contracted = -sum(vals < 0, na.rm = TRUE)
  ))
}

cafe_long <- melt(cafe_summary, id.vars = "Species",
                  variable.name = "Direction", value.name = "Count")
cafe_long[, Species := factor(Species, levels = species_order)]

p_cafe_all <- ggplot(cafe_long, aes(x = Species, y = Count, fill = Direction)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = c(Expanded = palette14[8], Contracted = palette14[5]),
                    labels = c("Expanded", "Contracted")) +
  geom_hline(yintercept = 0, linewidth = 0.3) +
  labs(x = NULL, y = "Number of gene families (contracted shown as negative)",
       title = paste0("Gene family expansion and contraction (", length(sig_families),
                      " significant families, p < 0.05)")) +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(OUT_DIR, "CAFE_expansion_contraction_all_species.pdf"), p_cafe_all,
       width = 12, height = 7, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "CAFE_expansion_contraction_all_species.png"), p_cafe_all,
       width = 12, height = 7, dpi = 300)

# ============================================================
# 补充图2: CAFE变化热图 (Top100家族按变异幅度排序)
# ============================================================
cat("生成 CAFE 补充图2: 变化热图...\n")

# 取BH列作为排序依据（按绝对值最大的家族排序）
bh_col <- leaf_cols[leaf_names == "T01"]
if (length(bh_col) > 0) {
  change_sig[, MaxAbsChange := apply(abs(.SD), 1, max, na.rm = TRUE),
             .SDcols = leaf_cols]
  top100 <- change_sig[order(-MaxAbsChange)][1:min(100, nrow(change_sig))]

  hm_data <- top100[, c("FamilyID", leaf_cols), with = FALSE]
  hm_long <- melt(hm_data, id.vars = "FamilyID", variable.name = "SpNode",
                  value.name = "Delta")
  hm_long[, Species := sub("<.*", "", SpNode)]
  hm_long <- hm_long[Species %in% species_order]
  hm_long[, Species := factor(Species, levels = species_order)]
  hm_long[, FamilyID := factor(FamilyID, levels = rev(unique(top100$FamilyID)))]
  hm_long[, Delta := as.numeric(Delta)]

  p_heatmap <- ggplot(hm_long, aes(x = Species, y = FamilyID, fill = Delta)) +
    geom_tile() +
    scale_fill_gradient2(low = palette14[2], mid = "white", high = palette14[5],
                         midpoint = 0, name = "Change") +
    labs(x = NULL, y = NULL,
         title = "Top 100 significantly changed gene families") +
    theme_pub(8) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          axis.text.y = element_text(size = 4))

  ggsave(file.path(OUT_DIR, "CAFE_change_heatmap_top100.pdf"), p_heatmap,
         width = 10, height = 14, device = cairo_pdf)
  ggsave(file.path(OUT_DIR, "CAFE_change_heatmap_top100.png"), p_heatmap,
         width = 10, height = 14, dpi = 300)
}

cat("CAFE 补充图完成\n")
