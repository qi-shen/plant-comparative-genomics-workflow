#!/usr/bin/env Rscript
# 图5: WGD/Ks分布 + 共线性点图 — 对标 Molecular Horticulture (2026) Fig.5
# 修复: 过滤低Ks噪声, 补全4个点图, Y轴具体物种名, 2x2均匀布局

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(patchwork)
  library(scales)
})

BASE <- "${PROJECT_ROOT}/comparative_genomics"
OUT_DIR <- file.path(BASE, "figures_publication")
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

ks_species <- c("T01", "T02", "C02", "C03", "C01")
ks_colors <- c(
  T01 = "#00BFAE", T02 = "#1F77B4", C02 = "#9467BD",
  C03 = "#FF7F0E", C01 = "#D62728"
)
ks_labels <- c(
  T01 = "T. sp. T01", T02 = "T. sp. T02", C02 = "T. austromongolica",
  C03 = "T. C03", C01 = "R. soongarica"
)

# ============================================================
# Panel A: Ks 核密度曲线叠加 (过滤Ks < 0.05噪声)
# ============================================================
cat("生成 Panel A: Ks 密度曲线...\n")

ks_file <- file.path(BASE, "04_wgd/ks_all_results.tsv")
ks_all <- fread(ks_file, select = c("Species", "Ks"))
# 关键修复: 过滤 Ks < 0.1 (近期串联重复/测序噪声) 和 Ks > 3
ks_all <- ks_all[!is.na(Ks) & Ks >= 0.1 & Ks <= 3.0 & Species %in% ks_species]
ks_all[, Species := factor(Species, levels = ks_species)]

p_ks <- ggplot(ks_all, aes(x = Ks, color = Species)) +
  geom_density(linewidth = 1.0, adjust = 2.0) +
  scale_color_manual(values = ks_colors, labels = ks_labels) +
  scale_x_continuous(breaks = seq(0, 3, 0.5), limits = c(0, 3.0)) +
  labs(
    x = expression(paste("Synonymous nucleotide substitution (", italic(K[s]), ")")),
    y = "Kernel density"
  ) +
  theme_pub(12) +
  theme(
    legend.position = c(0.80, 0.80),
    legend.background = element_rect(fill = alpha("white", 0.9), color = NA),
    legend.text = element_text(face = "italic", size = 10),
    legend.key.width = unit(1.2, "cm")
  )

# ============================================================
# Panel B: 共线性点图 (4个: T01 vs T02/C02/C03/C01, 2x2布局)
# ============================================================
cat("生成 Panel B: 共线性点图...\n")

syn_dir <- file.path(BASE, "05_synteny/jcvi_plots")

read_bed <- function(sp) {
  # 搜索多个目录
  search_dirs <- c(
    file.path(BASE, "05_synteny/jcvi_plots_tch_fix"),
    syn_dir
  )
  for (d in search_dirs) {
    bed_file <- file.path(d, paste0(sp, ".bed"))
    if (file.exists(bed_file) && file.info(bed_file)$size > 0) {
      bed <- fread(bed_file, header = FALSE,
                   col.names = c("chr", "start", "end", "gene", "score", "strand"))
      bed[, midpos := (start + end) / 2]
      return(bed)
    }
  }
  return(NULL)
}

read_anchors <- function(sp1, sp2) {
  # 搜索多个可能的目录（优先修复版）
  search_dirs <- c(
    file.path(BASE, "05_synteny/jcvi_plots_tch_fix"),
    syn_dir
  )
  for (d in search_dirs) {
    anc_file <- file.path(d, paste0(sp1, ".", sp2, ".anchors"))
    if (file.exists(anc_file) && file.info(anc_file)$size > 0) {
      lines <- readLines(anc_file)
      lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
      if (length(lines) > 0) {
        cat("    使用:", anc_file, "(", length(lines), "行)\n")
        return(fread(text = lines, header = FALSE, col.names = c("g1", "g2", "score")))
      }
    }
  }
  return(NULL)
}

# 为BED计算累积坐标
add_cumpos <- function(bed) {
  chr_order <- bed[, .(maxpos = max(end)), by = chr][order(chr)]
  chr_order[, cumstart := cumsum(c(0, head(maxpos, -1)))]
  # 计算每个染色体中点（用于axis标签）
  chr_order[, mid := cumstart + maxpos / 2]
  bed <- merge(bed, chr_order[, .(chr, cumstart)], by = "chr")
  bed[, cumpos := cumstart + midpos]
  list(bed = bed, chr_info = chr_order)
}

# 染色体配色（交替着色）
chr_palette <- c("#1F77B4", "#FF7F0E", "#2CA02C", "#D62728",
                 "#9467BD", "#8C564B", "#E377C2", "#7F7F7F",
                 "#BCBD22", "#17BECF", "#AEC7E8", "#FFBB78",
                 "#98DF8A", "#FF9896")

# 4个配对
pairs <- list(c("T01", "T02"), c("T01", "C02"), c("T01", "C03"), c("T01", "C01"))
dot_plots <- list()

bed_bh_data <- read_bed("T01")
bh_cum <- add_cumpos(bed_bh_data)

for (pr in pairs) {
  sp1 <- pr[1]; sp2 <- pr[2]
  bed2_raw <- read_bed(sp2)
  anc <- read_anchors(sp1, sp2)
  if (is.null(bed2_raw) || is.null(anc)) {
    cat("  跳过:", sp1, "vs", sp2, "(数据缺失)\n")
    next
  }

  sp2_cum <- add_cumpos(bed2_raw)

  # 合并anchors与坐标
  bed1 <- bh_cum$bed
  bed2 <- sp2_cum$bed
  setkey(bed1, gene); setkey(bed2, gene)

  merged <- merge(anc, bed1[, .(gene, cumpos, chr)], by.x = "g1", by.y = "gene")
  setnames(merged, c("cumpos", "chr"), c("x", "chr1"))
  merged <- merge(merged, bed2[, .(gene, cumpos, chr)], by.x = "g2", by.y = "gene")
  setnames(merged, c("cumpos", "chr"), c("y", "chr2"))

  # 染色体颜色映射
  chr1_levels <- sort(unique(merged$chr1))
  chr1_colors <- setNames(rep(chr_palette, length.out = length(chr1_levels)), chr1_levels)

  # 染色体刻度
  chr_breaks_x <- bh_cum$chr_info[, .(label = chr, pos = mid)]
  chr_breaks_y <- sp2_cum$chr_info[, .(label = chr, pos = mid)]

  p <- ggplot(merged, aes(x = x / 1e6, y = y / 1e6, color = chr1)) +
    geom_point(size = 0.2, alpha = 0.5) +
    scale_color_manual(values = chr1_colors, guide = "none") +
    scale_x_continuous(breaks = chr_breaks_x$pos / 1e6,
                       labels = sub("Chr0?", "", chr_breaks_x$label),
                       expand = c(0.02, 0)) +
    scale_y_continuous(breaks = chr_breaks_y$pos / 1e6,
                       labels = sub("Chr0?", "", chr_breaks_y$label),
                       expand = c(0.02, 0)) +
    labs(x = paste0("T01 (", "T. sp. T01", ") chromosome"),
         y = paste0(ks_labels[sp2], " chromosome"),
         title = paste0("T01 vs ", ks_labels[sp2])) +
    theme_pub(9) +
    theme(
      plot.title = element_text(size = 10, face = "italic"),
      axis.text = element_text(size = 7),
      axis.title = element_text(size = 8)
    )

  dot_plots[[paste0(sp1, "_", sp2)]] <- p
  cat("  完成:", sp1, "vs", sp2, "\n")
}

# 2x2 网格组装点图
if (length(dot_plots) >= 4) {
  p_dots <- (dot_plots[[1]] | dot_plots[[2]]) / (dot_plots[[3]] | dot_plots[[4]])
} else if (length(dot_plots) >= 2) {
  p_dots <- wrap_plots(dot_plots, ncol = 2)
} else {
  p_dots <- ggplot() + theme_void() + labs(title = "Insufficient synteny data")
}

# ============================================================
# 组装 Figure 5
# ============================================================
cat("组装 Figure 5...\n")

fig5 <- p_ks / p_dots +
  plot_annotation(tag_levels = "A") +
  plot_layout(heights = c(1, 2.2))

ggsave(file.path(OUT_DIR, "Figure5_WGD_Synteny.pdf"), fig5,
       width = 12, height = 16, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "Figure5_WGD_Synteny.png"), fig5,
       width = 12, height = 16, dpi = 300)

cat("Figure 5 已保存:", OUT_DIR, "\n")
