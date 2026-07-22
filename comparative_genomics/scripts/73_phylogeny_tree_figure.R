#!/usr/bin/env Rscript
# 系统发育树独立图 — 带bootstrap支持率、分歧时间、物种分类着色

suppressPackageStartupMessages({
  library(ape)
  library(ggtree)
  library(treeio)
  library(ggplot2)
  library(data.table)
})

BASE <- "${PROJECT_ROOT}/comparative_genomics"
OUT_DIR <- file.path(BASE, "DELIVERY_PACKAGE_v2/02_系统发育分析/figures")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

palette14 <- c("#00BFAE", "#1F77B4", "#9467BD", "#FF7F0E", "#D62728",
               "#F08080", "#8B4513", "#228B22", "#90EE90", "#00008B",
               "#DDA0DD", "#006400", "#8B0000", "#ADD8E6")

# 读取时间校准树
tree <- read.tree(file.path(BASE, "07_cafe/species_tree_calibrated.nwk"))

# 拉丁名 + 中文名
species_info <- data.frame(
  label = c("T01", "T02", "C02", "C03", "C01", "C08",
            "C04", "O01", "C05", "C06", "C07", "C09",
            "C10", "C11", "O02"),
  latin = c("T. sp. T01", "T. sp. T02", "T. austromongolica",
            "T. C03", "R. soongarica", "F. multiflora",
            "A. palmeri", "A. thaliana", "C. C05",
            "D. caryophyllus", "G. paniculata", "H. ammodendron",
            "P. oleracea", "S. monacanthus", "V. vinifera"),
  family = c("Family_T", "Family_T", "Family_T",
             "Family_T", "Family_T", "Family_P",
             "Family_A", "Family_B", "Family_A",
             "Family_C", "Family_C", "Family_A",
             "Family_O", "Family_K", "Family_V"),
  stringsAsFactors = FALSE
)

# 科的颜色
family_colors <- c(
  Family_T = palette14[1],
  Family_P = palette14[4],
  Family_A = palette14[2],
  Family_C = palette14[5],
  Family_O = palette14[8],
  Family_K = palette14[3],
  Family_B = palette14[10],
  Family_V = palette14[14]
)

# 获取bootstrap值 (node.label)
# 时间校准树中的node.label是支持率
boot_vals <- tree$node.label
n_tips <- length(tree$tip.label)

# 构建内部节点标注数据
boot_df <- data.frame(
  node = (n_tips + 1):(n_tips + tree$Nnode),
  bootstrap = as.numeric(boot_vals),
  stringsAsFactors = FALSE
)
boot_df$bootstrap[is.na(boot_df$bootstrap)] <- 1.0
# 将0-1范围转为百分比
boot_df$boot_pct <- ifelse(boot_df$bootstrap <= 1,
                            round(boot_df$bootstrap * 100),
                            round(boot_df$bootstrap))
boot_df$boot_label <- paste0(boot_df$boot_pct, "%")
# 只显示非100%的（100%太多不需要标）
boot_df$boot_label[boot_df$boot_pct >= 100] <- ""

# 绘制树
p <- ggtree(tree, ladderize = TRUE, linewidth = 0.8) %<+% species_info +
  # tip 标签: 斜体拉丁名, 按科着色
  geom_tiplab(aes(label = latin, color = family),
              fontface = "italic", size = 4.2, offset = 2) +
  geom_tippoint(aes(color = family), size = 2.5) +
  scale_color_manual(values = family_colors, name = "Family") +
  # bootstrap 支持率 (仅显示<100%的节点)
  geom_nodelab(aes(label = ifelse(
    !is.na(suppressWarnings(as.numeric(label))) &
    suppressWarnings(as.numeric(label)) < 1 &
    suppressWarnings(as.numeric(label)) > 0,
    paste0(round(as.numeric(label)*100), "%"), "")),
    size = 3.0, color = "#D62728", hjust = 1.3, vjust = -0.4) +
  # 时间轴
  theme_tree2() +
  scale_x_continuous(
    breaks = seq(0, 150, 30),
    labels = seq(150, 0, -30)
  ) +
  labs(x = "Million years ago (MYA)") +
  coord_cartesian(xlim = c(0, 300)) +
  theme(
    axis.line.y = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    legend.position = c(0.15, 0.55),
    legend.background = element_rect(fill = alpha("white", 0.9),
                                      color = "grey80", linewidth = 0.3),
    legend.text = element_text(size = 9),
    legend.title = element_text(size = 10, face = "bold"),
    legend.key.size = unit(0.5, "cm"),
    plot.margin = margin(10, 10, 10, 10)
  )

# 保存
ggsave(file.path(OUT_DIR, "Species_phylogenetic_tree.pdf"), p,
       width = 12, height = 9, device = cairo_pdf)
ggsave(file.path(OUT_DIR, "Species_phylogenetic_tree.png"), p,
       width = 12, height = 9, dpi = 300)

# 同时保存到 figures_publication
pub_dir <- file.path(BASE, "figures_publication")
ggsave(file.path(pub_dir, "Species_phylogenetic_tree.pdf"), p,
       width = 12, height = 9, device = cairo_pdf)
ggsave(file.path(pub_dir, "Species_phylogenetic_tree.png"), p,
       width = 12, height = 9, dpi = 300)

cat("✓ 系统发育树图已保存\n")
