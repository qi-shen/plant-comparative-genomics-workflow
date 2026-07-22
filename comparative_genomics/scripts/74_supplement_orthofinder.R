#!/usr/bin/env Rscript
# 基因家族补充图: (1) UpSet图 (2) 物种间共享热图 (3) 单拷贝基因统计
# 数据来源: OrthoFinder 最新结果

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

BASE <- "${PROJECT_ROOT}/comparative_genomics"
OUT_DIR <- file.path(BASE, "figures_supplement")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# 找到最新 OrthoFinder 结果
of_dirs <- list.dirs(file.path(BASE, "02_orthofinder_results_longest"), recursive = FALSE)
of_dirs <- of_dirs[grepl("Results_", of_dirs)]
RESULTS_DIR <- sort(of_dirs, decreasing = TRUE)[1]
cat("使用 OrthoFinder 结果:", RESULTS_DIR, "\n")

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
species_colors <- setNames(rep(palette14, length.out = length(species_order)), species_order)

# ============================================================
# 补充图1: 物种间共享基因家族热图
# ============================================================
cat("生成补充图1: 物种间共享基因家族热图...\n")

overlap_file <- file.path(RESULTS_DIR, "Comparative_Genomics_Statistics/Orthogroups_SpeciesOverlaps.tsv")
if (file.exists(overlap_file)) {
  ov <- fread(overlap_file)
  # 第一列是物种名
  sp_names <- ov[[1]]
  ov_mat <- as.matrix(ov[, -1, with = FALSE])
  rownames(ov_mat) <- sp_names

  # 转为长格式
  ov_long <- data.table()
  for (i in seq_along(sp_names)) {
    for (j in seq_along(sp_names)) {
      if (i != j) {
        ov_long <- rbind(ov_long, data.table(
          Sp1 = sp_names[i], Sp2 = sp_names[j], Shared = ov_mat[i, j]
        ))
      }
    }
  }
  ov_long[, Sp1 := factor(Sp1, levels = species_order)]
  ov_long[, Sp2 := factor(Sp2, levels = rev(species_order))]

  p_overlap <- ggplot(ov_long, aes(x = Sp1, y = Sp2, fill = Shared)) +
    geom_tile(color = "white", linewidth = 0.2) +
    scale_fill_gradient(low = "white", high = palette14[2], labels = comma) +
    labs(x = NULL, y = NULL, fill = "Shared\northogroups",
         title = "Pairwise shared orthogroups between species") +
    theme_pub(10) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  ggsave(file.path(OUT_DIR, "OrthoFinder_species_overlap_heatmap.pdf"), p_overlap,
         width = 10, height = 9, device = cairo_pdf)
  ggsave(file.path(OUT_DIR, "OrthoFinder_species_overlap_heatmap.png"), p_overlap,
         width = 10, height = 9, dpi = 300)
}

# ============================================================
# 补充图2: 基因类型分布堆叠条形图
# ============================================================
cat("生成补充图2: 基因类型分布...\n")

stats_file <- file.path(RESULTS_DIR, "Comparative_Genomics_Statistics/Statistics_PerSpecies.tsv")
gc_file <- file.path(RESULTS_DIR, "Orthogroups/Orthogroups.GeneCount.tsv")

if (file.exists(stats_file) && file.exists(gc_file)) {
  stats <- fread(stats_file, header = TRUE)
  gc <- fread(gc_file)
  sp_cols <- setdiff(names(gc), c("Orthogroup", "Total"))

  # 分类每个物种的基因
  gene_types <- data.table()
  for (sp in sp_cols) {
    total_genes <- as.numeric(stats[1, ..sp])
    unassigned <- as.numeric(stats[3, ..sp])

    # 单拷贝: 该物种在orthogroup中只有1个基因，且所有物种都有恰好1个
    sc_count <- sum(gc[, ..sp] == 1 & apply(gc[, ..sp_cols, with = FALSE], 1, function(x) all(x == 1)))
    # 多拷贝: 该物种在orthogroup中有>1个基因
    mc_genes <- sum(gc[gc[[sp]] > 1, ..sp])
    # 其他直系同源: 在orthogroup中有1个基因但不是严格单拷贝
    in_og <- as.numeric(stats[2, ..sp])
    other_ortho <- in_og - sc_count - mc_genes

    # 物种特有旁系同源
    sp_specific_genes <- as.numeric(stats[9, ..sp])

    gene_types <- rbind(gene_types, data.table(
      Species = sp,
      `Single-copy orthologs` = sc_count,
      `Multiple-copy orthologs` = mc_genes,
      `Species-specific paralogs` = sp_specific_genes,
      `Other orthologs` = max(0, other_ortho - sp_specific_genes),
      `Unclustered genes` = unassigned
    ))
  }

  gt_long <- melt(gene_types, id.vars = "Species", variable.name = "Type", value.name = "Count")
  gt_long[, Species := factor(Species, levels = rev(species_order))]
  gt_long[, Type := factor(Type, levels = c("Single-copy orthologs", "Multiple-copy orthologs",
                                             "Other orthologs", "Species-specific paralogs",
                                             "Unclustered genes"))]

  type_colors <- c(
    "Single-copy orthologs" = palette14[1],
    "Multiple-copy orthologs" = palette14[2],
    "Other orthologs" = palette14[3],
    "Species-specific paralogs" = palette14[4],
    "Unclustered genes" = palette14[14]
  )

  p_genetypes <- ggplot(gt_long, aes(x = Count, y = Species, fill = Type)) +
    geom_col(width = 0.7) +
    scale_fill_manual(values = type_colors) +
    scale_x_continuous(labels = comma) +
    labs(x = "Number of genes", y = NULL,
         title = "Distribution of gene types across species") +
    theme_pub(11) +
    theme(legend.position = "bottom",
          legend.text = element_text(size = 8))

  ggsave(file.path(OUT_DIR, "OrthoFinder_gene_type_distribution.pdf"), p_genetypes,
         width = 12, height = 8, device = cairo_pdf)
  ggsave(file.path(OUT_DIR, "OrthoFinder_gene_type_distribution.png"), p_genetypes,
         width = 12, height = 8, dpi = 300)
}

# ============================================================
# 补充图3: 基因家族拷贝数分布（百分比堆叠）
# ============================================================
cat("生成补充图3: 基因家族拷贝数分布...\n")

if (file.exists(gc_file)) {
  gc <- fread(gc_file)
  sp_cols <- setdiff(names(gc), c("Orthogroup", "Total"))

  copy_dist <- data.table()
  for (sp in sp_cols) {
    vals <- gc[[sp]]
    copy_dist <- rbind(copy_dist, data.table(
      Species = sp,
      `0` = sum(vals == 0),
      `1` = sum(vals == 1),
      `2` = sum(vals == 2),
      `3` = sum(vals == 3),
      `4` = sum(vals == 4),
      `>4` = sum(vals > 4)
    ))
  }

  cd_long <- melt(copy_dist, id.vars = "Species", variable.name = "Copies", value.name = "Count")
  cd_long[, Species := factor(Species, levels = species_order)]
  cd_long[, Copies := factor(Copies, levels = c(">4", "4", "3", "2", "1", "0"))]

  # 计算百分比
  cd_long[, Pct := Count / sum(Count) * 100, by = Species]

  copy_colors <- c("0" = "#E0E0E0", "1" = palette14[14], "2" = palette14[1],
                   "3" = palette14[2], "4" = palette14[3], ">4" = palette14[4])

  p_copydist <- ggplot(cd_long, aes(x = Species, y = Pct, fill = Copies)) +
    geom_col(width = 0.7) +
    scale_fill_manual(values = copy_colors) +
    labs(x = NULL, y = "Relative abundance (%)",
         title = "Distribution of gene family copy numbers across species") +
    theme_pub(11) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  ggsave(file.path(OUT_DIR, "OrthoFinder_copy_number_distribution.pdf"), p_copydist,
         width = 12, height = 7, device = cairo_pdf)
  ggsave(file.path(OUT_DIR, "OrthoFinder_copy_number_distribution.png"), p_copydist,
         width = 12, height = 7, dpi = 300)
}

cat("基因家族补充图完成\n")
