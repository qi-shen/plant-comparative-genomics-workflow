#!/usr/bin/env Rscript
# 图4: 比较基因组概览 — 对标 Molecular Horticulture (2026) Fig.4
# Panel A: 系统发育树 + 分歧时间 + CAFE扩张/收缩（绿色+X / 红色-Y）
# Panel B: 基因类型堆叠条形图（物种顺序与树一致）
# Panel C: 拷贝数分布
# Panel D: 花瓣图（Flower Petal Plot）

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(scales)
  library(ape)
  library(ggtree)
  library(treeio)
  library(patchwork)
  library(grid)
  library(ggforce)
  # ggimage not needed - using annotation_custom for pies
})

BASE <- "/path/to/project_root/comparative_genomics"
OUT_DIR <- file.path(BASE, "figures_publication")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

RESULTS_DIR <- sort(list.dirs(file.path(BASE, "02_orthofinder_results_longest"),
                               recursive = FALSE), decreasing = TRUE)[1]
CAFE_DIR <- file.path(BASE, "07_cafe/cafe_results_calibrated")

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

# 拉丁名映射
species_latin <- c(
  BH = "T. sp. BH", CK = "T. sp. CK", TAU = "T. austromongolica",
  TCH = "T. chinensis", RSO = "R. soongarica",
  APA = "A. palmeri", ATH = "A. thaliana", CQU = "C. C05",
  DCA = "D. caryophyllus", FMU = "F. multiflora",
  GPA = "G. paniculata", HAM = "H. ammodendron", POL = "P. oleracea",
  SMO = "S. monacanthus", VVI = "V. vinifera"
)

# ============================================================
# Panel A: 系统发育树 + 分歧时间 + CAFE扩张/收缩
# ============================================================
cat("生成 Panel A: 系统发育树 + CAFE标注...\n")

tree_file <- file.path(BASE, "07_cafe/species_tree_calibrated.nwk")
tree <- read.tree(tree_file)

# 解析CAFE结果
change_dt <- fread(file.path(CAFE_DIR, "Base_change.tab"))
family_res <- fread(file.path(CAFE_DIR, "Base_family_results.txt"))
sig_families <- family_res[pvalue < 0.05]$`#FamilyID`
change_sig <- change_dt[FamilyID %in% sig_families]

cafe_cols <- grep("<", names(change_dt), value = TRUE)
cafe_cols <- cafe_cols[cafe_cols != "FamilyID"]

# 统计每个节点的扩张/收缩
node_stats <- data.table()
for (col in cafe_cols) {
  sp_name <- sub("<.*", "", col)
  node_id <- as.integer(sub(".*<(\\d+)>", "\\1", col))
  vals <- as.numeric(change_sig[[col]])
  expanded <- sum(vals > 0, na.rm = TRUE)
  contracted <- sum(vals < 0, na.rm = TRUE)
  node_stats <- rbind(node_stats, data.table(
    sp = sp_name, node_id = node_id,
    expanded = expanded, contracted = contracted
  ))
}

# 获取树的tip顺序
tree_plot_order <- rev(get_taxa_name(ggtree(tree)))

# 构建ggtree基本对象
p0 <- ggtree(tree, ladderize = TRUE)
tree_data <- p0$data

# 为tip节点添加拉丁名
tip_df <- data.frame(
  label = tree$tip.label,
  latin_name = species_latin[tree$tip.label],
  stringsAsFactors = FALSE
)

# 合并tip的CAFE数据
tip_stats <- node_stats[sp %in% tree$tip.label]
tip_df <- merge(tip_df, tip_stats[, .(sp, expanded, contracted)],
                by.x = "label", by.y = "sp", all.x = TRUE)
tip_df$expanded[is.na(tip_df$expanded)] <- 0
tip_df$contracted[is.na(tip_df$contracted)] <- 0

# 构建标注数据框: tip + 内部节点
n_tips <- length(tree$tip.label)
annot_data <- data.frame(
  node = integer(0), expanded = integer(0),
  contracted = integer(0), is_tip = logical(0)
)

# tip节点
for (i in seq_len(nrow(tip_df))) {
  tip_node <- which(tree$tip.label == tip_df$label[i])
  annot_data <- rbind(annot_data, data.frame(
    node = tip_node, expanded = tip_df$expanded[i],
    contracted = tip_df$contracted[i], is_tip = TRUE
  ))
}

# 内部节点 (CAFE node_id → ggtree node)
internal_cafe <- node_stats[sp == ""]
if (nrow(internal_cafe) > 0) {
  for (i in seq_len(nrow(internal_cafe))) {
    cafe_nid <- internal_cafe$node_id[i]
    ggtree_node <- cafe_nid + 1
    if (ggtree_node > n_tips && ggtree_node <= (2 * n_tips - 1)) {
      annot_data <- rbind(annot_data, data.frame(
        node = ggtree_node, expanded = internal_cafe$expanded[i],
        contracted = internal_cafe$contracted[i], is_tip = FALSE
      ))
    }
  }
}

# 获取每个节点在树图中的x,y坐标
pie_data <- data.frame()
for (i in seq_len(nrow(annot_data))) {
  nd <- annot_data$node[i]
  nd_data <- tree_data[tree_data$node == nd, ]
  if (nrow(nd_data) == 0) next
  pie_data <- rbind(pie_data, data.frame(
    x = nd_data$x, y = nd_data$y,
    Expansion = annot_data$expanded[i],
    Contraction = annot_data$contracted[i],
    is_tip = annot_data$is_tip[i]
  ))
}

# 数字标注
annot_data$exp_label <- paste0("+", annot_data$expanded)
annot_data$con_label <- paste0("-", annot_data$contracted)

# 合并坐标
annot_data <- merge(annot_data, tree_data[, c("node", "x", "y")], by = "node")

# 创建单个饼图 grob 的辅助函数
make_pie_grob <- function(exp_val, con_val) {
  df <- data.frame(
    category = factor(c("Expansion", "Contraction"),
                      levels = c("Expansion", "Contraction")),
    value = c(exp_val, con_val)
  )
  p <- ggplot(df, aes(x = "", y = value, fill = category)) +
    geom_col(width = 1, color = "white", linewidth = 0.5) +
    coord_polar("y", start = 0) +
    scale_fill_manual(values = c("Expansion" = "#228B22",
                                  "Contraction" = "#D62728")) +
    theme_void() +
    theme(legend.position = "none",
          plot.background = element_blank(),
          panel.background = element_blank())
  ggplotGrob(p)
}

# 绘制基本树
p_tree <- p0 %<+% tip_df +
  geom_tiplab(aes(label = latin_name), fontface = "italic",
              size = 3.3, offset = 5, align = FALSE) +
  theme_tree2() +
  scale_x_continuous(
    breaks = seq(0, 150, 30),
    labels = seq(150, 0, -30)
  ) +
  labs(x = "Million years ago (MYA)") +
  coord_cartesian(xlim = c(0, 235)) +
  theme(axis.line.y = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank())

# 在每个节点放置饼图 grob (annotation_custom 保持正圆)
# 饼图尺寸 (数据坐标单位)
pie_rx <- 5     # x方向半径 (MYA单位)
pie_ry <- 0.45  # y方向半径 (物种间距单位)

for (i in seq_len(nrow(annot_data))) {
  exp_v <- annot_data$expanded[i]
  con_v <- annot_data$contracted[i]
  if (exp_v == 0 && con_v == 0) next

  cx <- annot_data$x[i]
  cy <- annot_data$y[i]
  grob <- make_pie_grob(exp_v, con_v)

  p_tree <- p_tree +
    annotation_custom(grob,
                      xmin = cx - pie_rx, xmax = cx + pie_rx,
                      ymin = cy - pie_ry, ymax = cy + pie_ry)
}

# 添加数字标注
tip_annot <- annot_data[annot_data$is_tip, ]
int_annot <- annot_data[!annot_data$is_tip, ]

if (nrow(tip_annot) > 0) {
  p_tree <- p_tree +
    geom_text(data = tip_annot,
              aes(x = x + 62, y = y),
              label = paste0(tip_annot$exp_label, "/", tip_annot$con_label),
              size = 2.0, color = "grey30", inherit.aes = FALSE)
}
if (nrow(int_annot) > 0) {
  p_tree <- p_tree +
    geom_text(data = int_annot,
              aes(x = x, y = y + 0.55),
              label = paste0(int_annot$exp_label, "/", int_annot$con_label),
              size = 1.7, color = "grey40", inherit.aes = FALSE)
}

# 手动图例
p_tree <- p_tree +
  annotate("rect", xmin = 2, xmax = 8, ymin = 14.3, ymax = 14.7,
           fill = "#228B22", color = NA) +
  annotate("text", x = 9, y = 14.5, label = "Expansion",
           size = 2.8, hjust = 0, color = "grey20") +
  annotate("rect", xmin = 2, xmax = 8, ymin = 13.5, ymax = 13.9,
           fill = "#D62728", color = NA) +
  annotate("text", x = 9, y = 13.7, label = "Contraction",
           size = 2.8, hjust = 0, color = "grey20")

cat("  Panel A 完成\n")

# ============================================================
# Panel B: 基因类型分布 (物种顺序与树一致)
# ============================================================
cat("生成 Panel B: 基因类型分布...\n")

stats_file <- file.path(RESULTS_DIR, "Comparative_Genomics_Statistics/Statistics_PerSpecies.tsv")
gc_file <- file.path(RESULTS_DIR, "Orthogroups/Orthogroups.GeneCount.tsv")

stats <- fread(stats_file, header = TRUE, fill = TRUE, nrows = 10)
gc <- fread(gc_file)
sp_cols_og <- setdiff(names(gc), c("Orthogroup", "Total"))

gene_types <- data.table()
for (sp in sp_cols_og) {
  total_genes <- as.numeric(stats[1, ..sp])
  unassigned <- as.numeric(stats[3, ..sp])
  in_og <- as.numeric(stats[2, ..sp])
  sp_specific_genes <- as.numeric(stats[9, ..sp])
  sc_count <- sum(gc[[sp]] == 1 & apply(gc[, ..sp_cols_og, with = FALSE] == 1, 1, all))
  mc_genes <- sum(gc[gc[[sp]] > 1, ..sp])
  other <- max(0, in_og - sc_count - mc_genes - sp_specific_genes)

  gene_types <- rbind(gene_types, data.table(
    Species = sp,
    `Single-copy orthologs` = as.double(sc_count),
    `Multiple-copy orthologs` = as.double(mc_genes),
    `Other orthologs` = as.double(other),
    `Unique paralogs` = as.double(sp_specific_genes),
    `Unclustered genes` = as.double(unassigned)
  ))
}

gt_long <- melt(gene_types, id.vars = "Species", variable.name = "Type", value.name = "Count")
gt_long[, Species := factor(Species, levels = rev(tree_plot_order))]
gt_long[, Type := factor(Type, levels = c("Single-copy orthologs", "Multiple-copy orthologs",
                                           "Other orthologs", "Unique paralogs",
                                           "Unclustered genes"))]
type_colors <- c(
  "Single-copy orthologs" = palette14[1],
  "Multiple-copy orthologs" = palette14[2],
  "Other orthologs" = palette14[3],
  "Unique paralogs" = palette14[4],
  "Unclustered genes" = palette14[14]
)

p_genetype <- ggplot(gt_long, aes(x = Count, y = Species, fill = Type)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = type_colors) +
  scale_x_continuous(labels = comma) +
  labs(x = "Number of genes", y = NULL) +
  theme_pub(10) +
  theme(legend.position = "bottom",
        legend.text = element_text(size = 7),
        legend.key.size = unit(0.35, "cm"))

cat("  Panel B 完成\n")

# ============================================================
# Panel C: 基因家族拷贝数分布
# ============================================================
cat("生成 Panel C: 拷贝数分布...\n")

copy_dist <- data.table()
for (sp in sp_cols_og) {
  vals <- gc[[sp]]
  copy_dist <- rbind(copy_dist, data.table(
    Species = sp,
    `0` = sum(vals == 0), `1` = sum(vals == 1), `2` = sum(vals == 2),
    `3` = sum(vals == 3), `4` = sum(vals == 4), `>4` = sum(vals > 4)
  ))
}
cd_long <- melt(copy_dist, id.vars = "Species", variable.name = "Copies", value.name = "Count")
cd_long[, Species := factor(Species, levels = tree_plot_order)]
cd_long[, Copies := factor(Copies, levels = c(">4", "4", "3", "2", "1", "0"))]
cd_long[, Pct := Count / sum(Count) * 100, by = Species]

copy_colors <- c("0" = "#E0E0E0", "1" = palette14[14], "2" = palette14[1],
                 "3" = palette14[2], "4" = palette14[3], ">4" = palette14[4])

p_copydist <- ggplot(cd_long, aes(x = Species, y = Pct, fill = Copies)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = copy_colors) +
  labs(x = NULL, y = "Relative abundance (%)") +
  theme_pub(10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

cat("  Panel C 完成\n")

# ============================================================
# Panel D: 花瓣图 (Flower Petal Plot)
# ============================================================
cat("生成 Panel D: 花瓣图...\n")

petal_sp <- c("BH", "CK", "TAU", "TCH", "RSO", "FMU")
petal_labels <- c(
  BH = "T. sp. BH", CK = "T. sp. CK",
  TAU = "T. austromongolica", TCH = "T. chinensis",
  RSO = "R. soongarica", FMU = "F. multiflora"
)

# 计算各组合
pa_mat <- as.data.frame(gc[, ..petal_sp, with = FALSE] > 0)

# 核心基因家族（所有6物种共有）
core_count <- sum(apply(pa_mat, 1, all))

# 每个物种独有的基因家族
unique_counts <- sapply(petal_sp, function(sp) {
  sum(pa_mat[[sp]] & rowSums(pa_mat) == 1)
})

# 每个物种参与的总基因家族数（用于花瓣大小参考）
total_counts <- colSums(pa_mat)

# 花瓣图参数
n_petals <- length(petal_sp)
angles <- seq(0, 2 * pi, length.out = n_petals + 1)[1:n_petals] - pi/2

# 花瓣颜色
petal_colors <- c(
  BH = palette14[1], CK = palette14[2], TAU = palette14[3],
  TCH = palette14[4], RSO = palette14[5], FMU = palette14[8]
)

# 中心圆半径和花瓣参数
center_r <- 1.2
petal_length <- 2.8
petal_width <- 0.7
label_r <- petal_length + center_r + 0.8
count_r <- petal_length * 0.55 + center_r

# 构建花瓣数据: 用椭圆
petal_data <- data.frame()
for (i in 1:n_petals) {
  sp <- petal_sp[i]
  angle <- angles[i]
  cx <- cos(angle) * (center_r + petal_length/2)
  cy <- sin(angle) * (center_r + petal_length/2)

  petal_data <- rbind(petal_data, data.frame(
    sp = sp,
    x0 = cx, y0 = cy,
    a = petal_length / 2,
    b = petal_width,
    angle = angle,
    unique_count = unique_counts[sp],
    total_count = total_counts[sp],
    label = petal_labels[sp],
    color = petal_colors[sp],
    stringsAsFactors = FALSE
  ))
}

# 物种名标签位置
label_data <- data.frame(
  x = cos(angles) * (label_r + 0.6),
  y = sin(angles) * (label_r + 0.6),
  label = petal_labels[petal_sp],
  angle_deg = angles * 180 / pi,
  stringsAsFactors = FALSE
)
# 调整标签角度使其可读
label_data$text_angle <- ifelse(
  abs(label_data$angle_deg) > 90 & abs(label_data$angle_deg) < 270,
  label_data$angle_deg + 180,
  label_data$angle_deg
)
# 简单起见, 固定0度（水平）
label_data$text_angle <- 0

# 计数标签位置（花瓣中间）
count_label_data <- data.frame(
  x = cos(angles) * count_r,
  y = sin(angles) * count_r,
  label = unique_counts[petal_sp],
  stringsAsFactors = FALSE
)

# 绘制花瓣图
p_flower <- ggplot() +
  # 花瓣（椭圆）
  geom_ellipse(data = petal_data,
               aes(x0 = x0, y0 = y0, a = a, b = b, angle = angle, fill = sp),
               alpha = 0.75, color = "white", linewidth = 0.8) +
  scale_fill_manual(values = petal_colors) +
  # 中心圆
  geom_circle(aes(x0 = 0, y0 = 0, r = center_r),
              fill = "#FFD700", color = "white", linewidth = 1.2, alpha = 0.9) +
  # 中心数字（核心基因家族数）
  annotate("text", x = 0, y = 0.2, label = comma(core_count),
           size = 5.5, fontface = "bold", color = "black") +
  annotate("text", x = 0, y = -0.35, label = "Core",
           size = 3.5, color = "grey30") +
  # 花瓣上的独有基因家族数
  geom_text(data = count_label_data,
            aes(x = x, y = y, label = comma(label)),
            size = 3.5, fontface = "bold", color = "white") +
  # 物种名标签
  geom_text(data = label_data,
            aes(x = x, y = y, label = label),
            size = 3, fontface = "italic", color = "grey20") +
  coord_fixed() +
  theme_void() +
  theme(legend.position = "none",
        plot.margin = margin(5, 5, 5, 5))

cat("  Panel D 完成\n")

# ============================================================
# 组装 Figure 4
# ============================================================
cat("组装 Figure 4...\n")

fig4 <- (p_tree | p_genetype) / (p_copydist | p_flower) +
  plot_annotation(tag_levels = "A") +
  plot_layout(heights = c(1.3, 1))

ggsave(file.path(OUT_DIR, "Figure4_Comparative_Genomics.pdf"), fig4,
       width = 16, height = 13, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "Figure4_Comparative_Genomics.png"), fig4,
       width = 16, height = 13, dpi = 300)

# 同时保存到交付包
DELIVERY_DIR <- file.path(BASE, "DELIVERY_PACKAGE_v2")
dir.create(DELIVERY_DIR, showWarnings = FALSE, recursive = TRUE)
file.copy(file.path(OUT_DIR, "Figure4_Comparative_Genomics.pdf"),
          file.path(DELIVERY_DIR, "Figure4_Comparative_Genomics.pdf"), overwrite = TRUE)
file.copy(file.path(OUT_DIR, "Figure4_Comparative_Genomics.png"),
          file.path(DELIVERY_DIR, "Figure4_Comparative_Genomics.png"), overwrite = TRUE)

cat("✓ Figure 4 已保存:", OUT_DIR, "\n")
