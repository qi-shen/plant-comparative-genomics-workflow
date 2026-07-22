#!/usr/bin/env Rscript
# 统一修复7个补充图问题:
# #1-2: 共线性 anchors 条形图/热图 — TCH数据从 tch_fix 目录读取
# #3:   CAFE热图 — 改为Top30, 增大字体
# #4:   Ks汇总图 — 添加Mean/Median图例
# #5-7: 正选择图表 — 过滤 omega=999 极端值

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

BASE <- "${PROJECT_ROOT}/comparative_genomics"
OUT_DIR <- file.path(BASE, "figures_supplement")
DELIVERY <- file.path(BASE, "DELIVERY_PACKAGE_v2")
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
species5 <- c("T01", "T02", "C02", "C03", "C01")

# ============================================================
# FIX #1: 共线性 anchors 条形图 — 合并 jcvi_plots + jcvi_plots_tch_fix
# ============================================================
cat("修复 #1: 共线性 anchors 条形图...\n")

SYN_DIRS <- c(file.path(BASE, "05_synteny/jcvi_plots_tch_fix"),
              file.path(BASE, "05_synteny/jcvi_plots"))

# 从多个目录读取，优先 tch_fix
read_anchors_count <- function(pattern_suffix, dirs) {
  result <- list()
  for (d in dirs) {
    files <- list.files(d, pattern = paste0("\\", pattern_suffix, "$"), full.names = TRUE)
    for (f in files) {
      pair <- gsub(paste0("\\", pattern_suffix, "$"), "", basename(f))
      if (!pair %in% names(result)) {
        lines <- readLines(f)
        lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
        if (length(lines) > 0) {
          result[[pair]] <- length(lines)
        }
      }
    }
  }
  result
}

anchors <- read_anchors_count(".anchors", SYN_DIRS)
lifted <- read_anchors_count(".lifted.anchors", SYN_DIRS)

anc_stats <- data.table(
  Pair = names(anchors),
  Anchors = unlist(anchors)
)
anc_stats[, Lifted := sapply(Pair, function(p) if (p %in% names(lifted)) lifted[[p]] else 0L)]
anc_stats <- anc_stats[order(-Anchors)]
anc_stats[, Pair := factor(Pair, levels = Pair)]

anc_long <- melt(anc_stats, id.vars = "Pair", variable.name = "Type", value.name = "Count")

p_anc_bar <- ggplot(anc_long, aes(x = Pair, y = Count, fill = Type)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_fill_manual(values = c(Anchors = palette14[2], Lifted = palette14[4])) +
  scale_y_continuous(labels = comma) +
  labs(x = NULL, y = "Number of gene pairs",
       title = "Synteny anchors and lifted anchors per species pair") +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(OUT_DIR, "Synteny_anchors_barplot.pdf"), p_anc_bar,
       width = 10, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "Synteny_anchors_barplot.png"), p_anc_bar,
       width = 10, height = 6, dpi = 300)

# ============================================================
# FIX #2: 共线性 anchors 热图 — 使用修复后的数据
# ============================================================
cat("修复 #2: 共线性 anchors 热图...\n")

mat <- data.table(Sp1 = character(), Sp2 = character(), Anchors = integer())
for (i in seq_len(nrow(anc_stats))) {
  pair <- as.character(anc_stats$Pair[i])
  sps <- strsplit(pair, "\\.")[[1]]
  if (length(sps) == 2 && all(sps %in% species5)) {
    mat <- rbind(mat, data.table(Sp1 = sps[1], Sp2 = sps[2], Anchors = anc_stats$Anchors[i]))
    mat <- rbind(mat, data.table(Sp1 = sps[2], Sp2 = sps[1], Anchors = anc_stats$Anchors[i]))
  }
}

# 添加对角线
for (sp in species5) {
  mat <- rbind(mat, data.table(Sp1 = sp, Sp2 = sp, Anchors = NA_integer_))
}

mat[, Sp1 := factor(Sp1, levels = species5)]
mat[, Sp2 := factor(Sp2, levels = rev(species5))]

p_anc_heat <- ggplot(mat, aes(x = Sp1, y = Sp2, fill = Anchors)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = ifelse(is.na(Anchors), "", comma(Anchors))),
            color = "black", size = 4) +
  scale_fill_gradient(low = "#E8F4FD", high = palette14[2],
                      labels = comma, na.value = "grey90") +
  labs(x = NULL, y = NULL,
       title = "Pairwise synteny anchors among target-clade species") +
  theme_pub(12) +
  coord_fixed() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(OUT_DIR, "Synteny_anchors_heatmap.pdf"), p_anc_heat,
       width = 7, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "Synteny_anchors_heatmap.png"), p_anc_heat,
       width = 7, height = 6, dpi = 300)

# ============================================================
# FIX #3: CAFE热图 — 改为Top30, 增大字体
# ============================================================
cat("修复 #3: CAFE热图 Top30...\n")

CAFE_DIR <- file.path(BASE, "07_cafe/cafe_results_calibrated")
change <- fread(file.path(CAFE_DIR, "Base_change.tab"))
family_res <- fread(file.path(CAFE_DIR, "Base_family_results.txt"))
sig_families <- family_res[pvalue < 0.05]$`#FamilyID`
change_sig <- change[FamilyID %in% sig_families]

species_order <- c("T01", "T02", "C02", "C03", "C01",
                   "C04", "O01", "C05", "C06", "C08",
                   "C07", "C09", "C10", "C11", "O02")
sp_cols <- grep("<", names(change), value = TRUE)
sp_cols <- sp_cols[sp_cols != "FamilyID"]
leaf_cols <- sp_cols[sub("<.*", "", sp_cols) %in% species_order]
leaf_names <- sub("<.*", "", leaf_cols)

change_sig[, MaxAbsChange := apply(abs(.SD), 1, max, na.rm = TRUE),
           .SDcols = leaf_cols]
top30 <- change_sig[order(-MaxAbsChange)][1:min(30, nrow(change_sig))]

hm_data <- top30[, c("FamilyID", leaf_cols), with = FALSE]
hm_long <- melt(hm_data, id.vars = "FamilyID", variable.name = "SpNode",
                value.name = "Delta")
hm_long[, Species := sub("<.*", "", SpNode)]
hm_long <- hm_long[Species %in% species_order]
hm_long[, Species := factor(Species, levels = species_order)]
hm_long[, FamilyID := factor(FamilyID, levels = rev(unique(top30$FamilyID)))]
hm_long[, Delta := as.numeric(Delta)]

p_heatmap <- ggplot(hm_long, aes(x = Species, y = FamilyID, fill = Delta)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = ifelse(abs(Delta) >= 3, Delta, "")),
            size = 2.5, color = "black") +
  scale_fill_gradient2(low = palette14[2], mid = "white", high = palette14[5],
                       midpoint = 0, name = "Change") +
  labs(x = NULL, y = NULL,
       title = "Top 30 significantly changed gene families (CAFE5)") +
  theme_pub(10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
        axis.text.y = element_text(size = 8))

ggsave(file.path(OUT_DIR, "CAFE_change_heatmap_top100.pdf"), p_heatmap,
       width = 10, height = 10, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "CAFE_change_heatmap_top100.png"), p_heatmap,
       width = 10, height = 10, dpi = 300)

# ============================================================
# FIX #4: Ks汇总图 — 添加Mean/Median图例
# ============================================================
cat("修复 #4: Ks汇总图...\n")

ks_colors <- c(T01 = "#00BFAE", T02 = "#1F77B4", C02 = "#9467BD",
               C03 = "#FF7F0E", C01 = "#D62728")
ks_summary <- fread(file.path(BASE, "04_wgd/ks_summary_stats.tsv"))
ks_summary <- ks_summary[Pair %in% c("T01", "T02", "C02", "C03", "C01")]

# 双轴比例
scale_factor <- max(ks_summary$Count) / max(ks_summary$Mean_Ks, ks_summary$Median_Ks)

# 用长格式画 Mean 和 Median 点, 附带图例
point_data <- rbind(
  data.table(Pair = ks_summary$Pair, Metric = "Mean Ks",
             Value = ks_summary$Mean_Ks * scale_factor),
  data.table(Pair = ks_summary$Pair, Metric = "Median Ks",
             Value = ks_summary$Median_Ks * scale_factor)
)

p_ks_stats <- ggplot() +
  geom_col(data = ks_summary, aes(x = Pair, y = Count, fill = Pair),
           width = 0.6, show.legend = FALSE) +
  geom_point(data = point_data,
             aes(x = Pair, y = Value, shape = Metric, color = Metric),
             size = 4) +
  scale_fill_manual(values = ks_colors) +
  scale_shape_manual(values = c("Mean Ks" = 16, "Median Ks" = 17)) +
  scale_color_manual(values = c("Mean Ks" = "black", "Median Ks" = "#D62728")) +
  scale_y_continuous(
    name = "Number of gene pairs",
    labels = comma,
    sec.axis = sec_axis(~ . / scale_factor,
                        name = expression(paste(italic(K[s]), " value")))
  ) +
  labs(x = NULL,
       title = expression(paste(italic(K[s]), " summary statistics by species"))) +
  theme_pub(11) +
  theme(legend.position = c(0.85, 0.85),
        legend.background = element_rect(fill = alpha("white", 0.9), color = "grey80"),
        legend.title = element_blank(),
        legend.text = element_text(size = 10))

ggsave(file.path(OUT_DIR, "WGD_Ks_summary_stats.pdf"), p_ks_stats,
       width = 8, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "WGD_Ks_summary_stats.png"), p_ks_stats,
       width = 8, height = 6, dpi = 300)

# ============================================================
# FIX #5-7: 正选择图表 — 过滤 omega=999 极端值
# ============================================================
cat("修复 #5-7: 正选择图表...\n")

paml_file <- file.path(DELIVERY, "06_正选择分析/data/paml_results_summary.tsv")
paml <- fread(paml_file)

# 获取omega列名
omega_col <- grep("omega|dN.dS|w$", names(paml), value = TRUE, ignore.case = TRUE)
if (length(omega_col) == 0) omega_col <- names(paml)[grep("omega", names(paml), ignore.case = TRUE)]
if (length(omega_col) == 0) {
  # 尝试读取列
  cat("  PAML列名:", paste(names(paml), collapse=", "), "\n")
  omega_col <- "omega"
}
omega_col <- omega_col[1]
cat("  使用omega列:", omega_col, "\n")

lnL_col <- grep("lnL|logL", names(paml), value = TRUE, ignore.case = TRUE)
if (length(lnL_col) > 0) lnL_col <- lnL_col[1] else lnL_col <- NULL

sites_col <- grep("sites|positive.*sites|num.*sites", names(paml), value = TRUE, ignore.case = TRUE)
if (length(sites_col) > 0) sites_col <- sites_col[1] else sites_col <- NULL

sig_col <- grep("signif|p.value|pval|significant", names(paml), value = TRUE, ignore.case = TRUE)
if (length(sig_col) > 0) sig_col <- sig_col[1] else sig_col <- NULL

# 过滤掉 omega >= 10 的极端值
paml_clean <- paml[get(omega_col) < 10 & get(omega_col) > 0]
cat("  过滤前:", nrow(paml), "行, 过滤后:", nrow(paml_clean), "行 (移除omega>=10)\n")

OUT_SEL <- file.path(DELIVERY, "06_正选择分析/figures")
dir.create(OUT_SEL, showWarnings = FALSE, recursive = TRUE)

# FIX #5: omega分布图 — 过滤极端值
p_omega <- ggplot(paml_clean, aes(x = get(omega_col))) +
  geom_histogram(bins = 30, fill = palette14[2], color = "white", linewidth = 0.3) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "#D62728", linewidth = 0.5) +
  annotate("text", x = 1.05, y = Inf, label = expression(omega == 1),
           hjust = 0, vjust = 1.5, color = "#D62728", size = 4) +
  labs(x = expression(omega~"(dN/dS)"),
       y = "Number of gene families",
       title = expression(paste("Distribution of ", omega, " values (filtered ", omega < 10, ")"))) +
  theme_pub(11)

ggsave(file.path(OUT_SEL, "01_omega分布.pdf"), p_omega,
       width = 8, height = 6, device = cairo_pdf)
ggsave(file.path(OUT_SEL, "01_omega分布.png"), p_omega,
       width = 8, height = 6, dpi = 300)

# FIX #6: lnL vs omega — 过滤极端值, 不截断
if (!is.null(lnL_col)) {
  paml_lnl <- paml_clean[!is.na(get(lnL_col))]
  if (!is.null(sig_col)) {
    paml_lnl[, Significant := ifelse(get(sig_col) == TRUE | get(sig_col) == "TRUE",
                                      "Positive selection", "Not significant")]
  } else {
    paml_lnl[, Significant := ifelse(get(omega_col) > 1, "Positive selection", "Not significant")]
  }

  p_lnl <- ggplot(paml_lnl, aes(x = get(lnL_col), y = get(omega_col), color = Significant)) +
    geom_point(size = 2, alpha = 0.7) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
    scale_color_manual(values = c("Positive selection" = palette14[5],
                                   "Not significant" = palette14[14])) +
    labs(x = "Log-likelihood (lnL)",
         y = expression(omega~"(dN/dS)"),
         title = expression(paste("lnL vs ", omega, " (filtered ", omega < 10, ")"))) +
    theme_pub(11) +
    theme(legend.position = c(0.20, 0.85),
          legend.background = element_rect(fill = alpha("white", 0.9), color = NA))

  ggsave(file.path(OUT_SEL, "02_lnL_vs_omega.pdf"), p_lnl,
         width = 8, height = 6, device = cairo_pdf)
  ggsave(file.path(OUT_SEL, "02_lnL_vs_omega.png"), p_lnl,
         width = 8, height = 6, dpi = 300)
}

# FIX #7: Top20 omega — 使用过滤后的数据, 排除999
top20_omega <- paml_clean[order(-get(omega_col))][1:min(20, nrow(paml_clean))]
id_col <- names(top20_omega)[1]  # 通常第一列是family/gene ID
top20_omega[, PlotID := factor(get(id_col), levels = rev(get(id_col)))]

p_top20 <- ggplot(top20_omega, aes(x = PlotID, y = get(omega_col))) +
  geom_col(fill = palette14[5], width = 0.7) +
  geom_hline(yintercept = 1, linetype = "dashed", color = "grey50") +
  geom_text(aes(label = sprintf("%.2f", get(omega_col))),
            hjust = -0.1, size = 3) +
  coord_flip() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(x = NULL, y = expression(omega~"(dN/dS)"),
       title = expression(paste("Top 20 gene families by ", omega, " (filtered ", omega < 10, ")"))) +
  theme_pub(10)

ggsave(file.path(OUT_SEL, "04_Top20_omega正选择.pdf"), p_top20,
       width = 10, height = 7, device = cairo_pdf)
ggsave(file.path(OUT_SEL, "04_Top20_omega正选择.png"), p_top20,
       width = 10, height = 7, dpi = 300)

# 复制修复后的图到交付包
cat("复制图表到交付包...\n")

# 共线性
for (f in c("Synteny_anchors_barplot", "Synteny_anchors_heatmap")) {
  for (ext in c(".pdf", ".png")) {
    file.copy(file.path(OUT_DIR, paste0(f, ext)),
              file.path(DELIVERY, "03_共线性分析/figures", paste0(f, ext)),
              overwrite = TRUE)
  }
}

# CAFE
for (f in c("CAFE_change_heatmap_top100")) {
  for (ext in c(".pdf", ".png")) {
    file.copy(file.path(OUT_DIR, paste0(f, ext)),
              file.path(DELIVERY, "04_基因家族动态分析/figures", paste0(f, ext)),
              overwrite = TRUE)
  }
}

# WGD
for (f in c("WGD_Ks_summary_stats")) {
  for (ext in c(".pdf", ".png")) {
    file.copy(file.path(OUT_DIR, paste0(f, ext)),
              file.path(DELIVERY, "05_全基因组复制分析/figures", paste0(f, ext)),
              overwrite = TRUE)
  }
}

cat("✓ 全部7个图表修复完成\n")
