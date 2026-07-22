#!/usr/bin/env Rscript
# 共线性补充图表：(1) 补全配对点图 (2) 共线性block长度分布 (3) anchors统计热图
# 数据来源: 现有 05_synteny/ 结果

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

BASE <- "/path/to/project_root/comparative_genomics"
SYN_DIR <- file.path(BASE, "05_synteny/jcvi_plots")
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

species5 <- c("BH", "CK", "TAU", "TCH", "RSO")

# ============================================================
# 补充图1: Anchors数量统计条形图（所有配对）
# ============================================================
cat("生成共线性补充图1: anchors统计...\n")

anc_files <- list.files(SYN_DIR, pattern = "\\.anchors$", full.names = TRUE)
anc_files <- anc_files[!grepl("lifted", anc_files)]

anc_stats <- data.table()
for (f in anc_files) {
  pair <- gsub("\\.anchors$", "", basename(f))
  lines <- readLines(f)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  anc_stats <- rbind(anc_stats, data.table(Pair = pair, Anchors = length(lines)))
}

# 对应的lifted anchors
lifted_files <- list.files(SYN_DIR, pattern = "\\.lifted\\.anchors$", full.names = TRUE)
for (f in lifted_files) {
  pair <- gsub("\\.lifted\\.anchors$", "", basename(f))
  lines <- readLines(f)
  lines <- lines[!grepl("^#", lines) & nchar(trimws(lines)) > 0]
  if (pair %in% anc_stats$Pair) {
    anc_stats[Pair == pair, Lifted := length(lines)]
  }
}

if (!"Lifted" %in% names(anc_stats)) anc_stats[, Lifted := 0]
anc_stats[is.na(Lifted), Lifted := 0]
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
# 补充图2: Anchors数量热图矩阵
# ============================================================
cat("生成共线性补充图2: anchors热图矩阵...\n")

# 构建对称矩阵
mat <- data.table(Sp1 = character(), Sp2 = character(), Anchors = integer())
for (i in seq_len(nrow(anc_stats))) {
  pair <- as.character(anc_stats$Pair[i])
  sps <- strsplit(pair, "\\.")[[1]]
  if (length(sps) == 2 && all(sps %in% species5)) {
    mat <- rbind(mat, data.table(Sp1 = sps[1], Sp2 = sps[2], Anchors = anc_stats$Anchors[i]))
    mat <- rbind(mat, data.table(Sp1 = sps[2], Sp2 = sps[1], Anchors = anc_stats$Anchors[i]))
  }
}

if (nrow(mat) > 0) {
  mat[, Sp1 := factor(Sp1, levels = species5)]
  mat[, Sp2 := factor(Sp2, levels = rev(species5))]

  p_anc_heat <- ggplot(mat, aes(x = Sp1, y = Sp2, fill = Anchors)) +
    geom_tile(color = "white", linewidth = 0.3) +
    geom_text(aes(label = comma(Anchors)), color = "black", size = 3.5) +
    scale_fill_gradient(low = "white", high = palette14[2], labels = comma) +
    labs(x = NULL, y = NULL,
         title = "Pairwise synteny anchors among target-clade species") +
    theme_pub(11) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  ggsave(file.path(OUT_DIR, "Synteny_anchors_heatmap.pdf"), p_anc_heat,
         width = 7, height = 6, device = cairo_pdf)
  ggsave(file.path(OUT_DIR, "Synteny_anchors_heatmap.png"), p_anc_heat,
         width = 7, height = 6, dpi = 300)
}

# ============================================================
# 补充图3: 共线性 block 大小分布
# ============================================================
cat("生成共线性补充图3: block大小分布...\n")

read_bed_simple <- function(sp) {
  bed_file <- file.path(SYN_DIR, paste0(sp, ".bed"))
  if (!file.exists(bed_file)) return(NULL)
  fread(bed_file, header = FALSE,
        col.names = c("chr", "start", "end", "gene", "score", "strand"))
}

block_sizes <- data.table()
for (f in anc_files) {
  pair <- gsub("\\.anchors$", "", basename(f))
  sps <- strsplit(pair, "\\.")[[1]]
  if (length(sps) != 2) next

  lines <- readLines(f)
  # 根据 ### 分隔符统计每个block的基因对数
  block_id <- 0
  block_count <- 0
  for (l in lines) {
    if (grepl("^###", l)) {
      if (block_count > 0) {
        block_sizes <- rbind(block_sizes,
                             data.table(Pair = pair, BlockID = block_id, GenesPairs = block_count))
      }
      block_id <- block_id + 1
      block_count <- 0
    } else if (nchar(trimws(l)) > 0) {
      block_count <- block_count + 1
    }
  }
  if (block_count > 0) {
    block_sizes <- rbind(block_sizes,
                         data.table(Pair = pair, BlockID = block_id, GenesPairs = block_count))
  }
}

if (nrow(block_sizes) > 0) {
  # 只展示近缘类群配对
  tam_pairs <- paste0(rep(species5, each = length(species5)), ".",
                      rep(species5, times = length(species5)))
  block_sizes_tam <- block_sizes[Pair %in% tam_pairs]

  if (nrow(block_sizes_tam) > 0) {
    p_blocks <- ggplot(block_sizes_tam, aes(x = Pair, y = GenesPairs, fill = Pair)) +
      geom_violin(alpha = 0.6, show.legend = FALSE) +
      geom_boxplot(width = 0.15, outlier.size = 0.5, show.legend = FALSE) +
      scale_y_log10() +
      labs(x = NULL, y = "Gene pairs per synteny block (log10)",
           title = "Synteny block size distribution") +
      theme_pub(11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggsave(file.path(OUT_DIR, "Synteny_block_size_distribution.pdf"), p_blocks,
           width = 10, height = 6, device = cairo_pdf)
    ggsave(file.path(OUT_DIR, "Synteny_block_size_distribution.png"), p_blocks,
           width = 10, height = 6, dpi = 300)
  }
}

cat("共线性补充图完成\n")
