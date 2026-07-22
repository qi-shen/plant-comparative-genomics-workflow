#!/usr/bin/env Rscript
# 生成交付包各模块可视化图表（R/ggplot2）
# 规则：不加背景网格线，不加上/右黑框线；统一配色

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
  library(ape)
})

theme_pub <- function(base_size = 12) {
  theme_classic(base_size = base_size) +
    theme(
      panel.grid = element_blank(),
      axis.line = element_line(color = "black", linewidth = 0.4),
      plot.title = element_text(hjust = 0.5, face = "bold"),
      legend.title = element_blank()
    )
}

palette14 <- c(
  "#00BFAE", "#1F77B4", "#9467BD", "#FF7F0E",
  "#D62728", "#F08080", "#8B4513", "#228B22",
  "#90EE90", "#00008B", "#DDA0DD", "#006400",
  "#8B0000", "#ADD8E6"
)

species_order <- c("BH", "CK", "TAU", "TCH", "RSO",
                   "APA", "ATH", "CQU", "DCA", "FMU", "GPA", "HAM", "POL", "SMO", "VVI")
species_cn <- c(
  BH = "BH(目标种BH)", CK = "CK(目标种CK)", TAU = "TAU(C02)", TCH = "TCH(C03)", RSO = "RSO(C01)",
  APA = "APA(C04)", ATH = "ATH(O01)", CQU = "CQU(C05)", DCA = "DCA(C06)", FMU = "FMU(C08)",
  GPA = "GPA(C07)", HAM = "HAM(C09)", POL = "POL(C10)", SMO = "SMO(C11)", VVI = "VVI(O02)"
)
species_colors <- setNames(rep(palette14, length.out = length(species_order)), species_order)

delivery_dir <- "/path/to/project_root/comparative_genomics/DELIVERY_PACKAGE"
if (!dir.exists(delivery_dir)) stop("DELIVERY_PACKAGE不存在: ", delivery_dir)

fig_dir <- function(...) {
  p <- file.path(delivery_dir, ...)
  dir.create(p, recursive = TRUE, showWarnings = FALSE)
  p
}

save_pdf <- function(p, filename, width = 9, height = 6) {
  ggsave(filename = filename, plot = p, width = width, height = height, units = "in", device = cairo_pdf)
}

save_png <- function(p, filename, width = 9, height = 6, dpi = 300) {
  ggsave(filename = filename, plot = p, width = width, height = height, units = "in", dpi = dpi, device = "png")
}

cat("DELIVERY_PACKAGE:", delivery_dir, "\n")

# ------------------------------------------------------------------------------
# 00 总览：交付指标卡片
# ------------------------------------------------------------------------------
cat("[00] 生成总览指标卡片...\n")
summary_md <- file.path(delivery_dir, "交付摘要.md")
summary_lines <- if (file.exists(summary_md)) readLines(summary_md, warn = FALSE, encoding = "UTF-8") else character()
summary_kv <- summary_lines[grepl("^[-] ", summary_lines)]

card_df <- data.frame(
  label = c(
    "OrthoFinder orthogroups",
    "genes in orthogroups(%)",
    "CAFE显著变化家族",
    "共线性同源基因对(anchors)",
    "WGD Ks有效值汇总",
    "PAML完成家族"
  ),
  value = c(NA, NA, NA, NA, NA, NA),
  stringsAsFactors = FALSE
)

extract_num <- function(key) {
  line <- summary_kv[grepl(key, summary_kv, fixed = TRUE)][1]
  if (is.na(line)) return(NA_character_)
  sub(paste0(".*", key, "[:：] *"), "", line)
}

card_df$value[1] <- extract_num("OrthoFinder orthogroups")
card_df$value[2] <- extract_num("genes in orthogroups")
card_df$value[3] <- extract_num("CAFE显著变化家族")
card_df$value[4] <- extract_num("共线性同源基因对(anchors)")
card_df$value[5] <- extract_num("WGD Ks有效值汇总")
card_df$value[6] <- extract_num("PAML完成家族")

card_df$label <- factor(card_df$label, levels = rev(card_df$label))

p_card <- ggplot(card_df, aes(x = 1, y = label)) +
  geom_tile(aes(fill = label), width = 0.8, height = 0.8, show.legend = FALSE) +
  geom_text(aes(label = paste0(label, "  =  ", value)), color = "white", size = 4, fontface = "bold") +
  scale_fill_manual(values = setNames(rep(palette14, length.out = nrow(card_df)), levels(card_df$label))) +
  scale_x_continuous(expand = expansion(mult = c(0, 0))) +
  labs(title = "交付包核心指标（概览）", x = NULL, y = NULL) +
  theme_pub(12) +
  theme(
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    axis.line = element_blank(),
    plot.margin = margin(10, 10, 10, 10)
  )

out00 <- fig_dir("00_分析报告", "figures")
save_pdf(p_card, file.path(out00, "00_交付核心指标卡片.pdf"), width = 10, height = 5)

# ------------------------------------------------------------------------------
# 01 OrthoFinder：每物种统计 + orthogroup大小分布 + Top家族热图
# ------------------------------------------------------------------------------
cat("[01] 生成基因家族分析可视化...\n")
stats_per_file <- file.path(delivery_dir, "01_基因家族分析", "OrthoFinder_Statistics_PerSpecies.tsv")
og_counts_file <- file.path(delivery_dir, "01_基因家族分析", "Orthogroups.GeneCount.tsv")
out01 <- fig_dir("01_基因家族分析", "figures")

stats_dt <- fread(stats_per_file, sep = "\t", header = TRUE, fill = TRUE)
setnames(stats_dt, 1, "Metric")
keep_metrics <- c(
  "Number of genes",
  "Number of genes in orthogroups",
  "Number of unassigned genes",
  "Percentage of genes in orthogroups",
  "Percentage of unassigned genes",
  "Number of species-specific orthogroups"
)
stats_dt <- stats_dt[Metric %in% keep_metrics]
stats_long <- melt(stats_dt, id.vars = "Metric", variable.name = "Species", value.name = "Value")
stats_long[, Value := as.numeric(Value)]
stats_long[, Species := factor(Species, levels = species_order)]

genes_df <- stats_long[Metric == "Number of genes"] %>% as.data.frame()
genes_df$SpeciesLabel <- species_cn[as.character(genes_df$Species)]
p_genes <- ggplot(genes_df, aes(x = Species, y = Value, fill = Species)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = species_colors) +
  scale_x_discrete(labels = species_cn) +
  scale_y_continuous(labels = comma) +
  labs(title = "各物种基因数（蛋白基因数）", x = NULL, y = "基因数") +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pdf(p_genes, file.path(out01, "01_各物种基因数.pdf"), width = 10.5, height = 6)

assign_df <- stats_long[Metric %in% c("Number of genes in orthogroups", "Number of unassigned genes")] %>%
  as.data.frame() %>%
  mutate(Group = ifelse(Metric == "Number of genes in orthogroups", "In_orthogroups", "Unassigned")) %>%
  select(Species, Group, Value)
p_assign <- ggplot(assign_df, aes(x = Species, y = Value, fill = Group)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = c(In_orthogroups = palette14[2], Unassigned = palette14[5])) +
  scale_x_discrete(labels = species_cn) +
  scale_y_continuous(labels = comma) +
  labs(title = "各物种基因分配情况（OrthoFinder）", x = NULL, y = "基因数") +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pdf(p_assign, file.path(out01, "02_各物种基因分配_orthogroups_vs_unassigned.pdf"), width = 10.5, height = 6)

spec_df <- stats_long[Metric == "Number of species-specific orthogroups"] %>% as.data.frame()
p_spec <- ggplot(spec_df, aes(x = Species, y = Value, fill = Species)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = species_colors) +
  scale_x_discrete(labels = species_cn) +
  scale_y_continuous(labels = comma) +
  labs(title = "各物种特异 orthogroups 数量", x = NULL, y = "species-specific orthogroups") +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pdf(p_spec, file.path(out01, "03_各物种特异家族数.pdf"), width = 10.5, height = 6)

og_dt <- fread(og_counts_file, sep = "\t", header = TRUE, select = c("Orthogroup", "Total"))
og_dt[, Total := as.numeric(Total)]
p_ogsize <- ggplot(as.data.frame(og_dt), aes(x = Total)) +
  geom_histogram(bins = 60, fill = palette14[2], color = "white") +
  scale_x_continuous(trans = "log10", breaks = c(1, 2, 5, 10, 20, 50, 100, 500, 1000),
                     labels = c(1, 2, 5, 10, 20, 50, 100, 500, 1000)) +
  labs(title = "orthogroup 大小分布（Total，log10刻度）", x = "orthogroup大小（Total）", y = "数量") +
  theme_pub(11)
save_pdf(p_ogsize, file.path(out01, "04_orthogroup大小分布_log10.pdf"), width = 10, height = 6)

# Top 50 最大家族热图（log1p）
og_full <- fread(og_counts_file, sep = "\t", header = TRUE)
setDT(og_full)
setorder(og_full, -Total)
topN <- og_full[1:50]
top_long <- melt(topN, id.vars = c("Orthogroup", "Total"),
                 variable.name = "Species", value.name = "Count")
top_long <- top_long[Species %in% species_order]
top_long[, Species := factor(Species, levels = species_order)]
top_long[, Orthogroup := factor(Orthogroup, levels = rev(unique(Orthogroup)))]
top_long[, logCount := log1p(as.numeric(Count))]
p_top_heat <- ggplot(as.data.frame(top_long), aes(x = Species, y = Orthogroup, fill = logCount)) +
  geom_tile(color = NA) +
  scale_fill_gradient(low = "white", high = palette14[5]) +
  scale_x_discrete(breaks = levels(top_long$Species),
                   labels = species_cn[levels(top_long$Species)]) +
  labs(title = "Top50 最大 orthogroups 的基因计数热图（log1p）", x = NULL, y = NULL, fill = "log1p(count)") +
  theme_pub(10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pdf(p_top_heat, file.path(out01, "05_Top50最大家族_热图_log1p.pdf"), width = 12, height = 10)

# ------------------------------------------------------------------------------
# 02 系统发育：物种树绘图（ape）
# ------------------------------------------------------------------------------
cat("[02] 生成系统发育树可视化...\n")
tree_file <- file.path(delivery_dir, "02_系统发育分析", "物种树.newick")
out02 <- fig_dir("02_系统发育分析", "figures")

tr <- read.tree(tree_file)
tip_cols <- rep("black", length(tr$tip.label))
names(tip_cols) <- tr$tip.label
tip_cols[names(tip_cols) == "BH"] <- palette14[5]
tip_cols[names(tip_cols) == "CK"] <- palette14[2]

pdf(file.path(out02, "01_物种树_标注BH_CK.pdf"), width = 10, height = 6)
par(mar = c(1, 1, 3, 1))
plot(tr, cex = 0.8, tip.color = tip_cols, main = "物种系统发育树（BH红 / CK蓝）")
add.scale.bar(length = 0.05, lwd = 2, col = "black")
dev.off()

# ------------------------------------------------------------------------------
# 03 共线性：anchors统计柱状图 + pairs热图
# ------------------------------------------------------------------------------
cat("[03] 生成共线性统计可视化...\n")
syn_stat <- file.path(delivery_dir, "03_共线性分析", "同源基因对统计.tsv")
out03 <- fig_dir("03_共线性分析", "figures")

syn_dt <- fread(syn_stat, sep = "\t", header = TRUE)
syn_dt <- syn_dt[File != "TOTAL"]
syn_dt[, Type := ifelse(grepl("lifted", File), "lifted", "anchors")]
syn_dt[, Pair := sub("\\.(lifted\\.)?anchors$", "", File)]
syn_dt[, c("Sp1", "Sp2") := tstrsplit(Pair, "\\.", fixed = FALSE)]

p_syn_bar <- ggplot(as.data.frame(syn_dt), aes(x = Pair, y = Pairs, fill = Type)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = c(anchors = palette14[2], lifted = palette14[4])) +
  scale_y_continuous(labels = comma) +
  labs(title = "共线性同源基因对统计（anchors vs lifted）", x = NULL, y = "Pairs") +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pdf(p_syn_bar, file.path(out03, "01_共线性同源对统计_anchors_vs_lifted.pdf"), width = 10, height = 6)

# pairs热图（仅 anchors 类型）
syn_a <- syn_dt[Type == "anchors", .(Sp1, Sp2, Pairs)]
all_sp <- sort(unique(c(syn_a$Sp1, syn_a$Sp2)))
grid <- CJ(Sp1 = all_sp, Sp2 = all_sp)
syn_mat <- merge(grid, syn_a, by = c("Sp1", "Sp2"), all.x = TRUE)
syn_mat[is.na(Pairs), Pairs := 0]
syn_mat[, Sp1 := factor(Sp1, levels = all_sp)]
syn_mat[, Sp2 := factor(Sp2, levels = all_sp)]
p_syn_heat <- ggplot(as.data.frame(syn_mat), aes(x = Sp1, y = Sp2, fill = Pairs)) +
  geom_tile(color = "white", linewidth = 0.2) +
  scale_fill_gradient(low = "white", high = palette14[5], labels = comma) +
  labs(title = "共线性 anchors 同源对热图（缺失=0）", x = NULL, y = NULL) +
  theme_pub(11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_pdf(p_syn_heat, file.path(out03, "02_共线性anchors_热图.pdf"), width = 8, height = 7)

# ------------------------------------------------------------------------------
# 04 CAFE：扩张/收缩统计 + 热图 + TCH变化分布
# ------------------------------------------------------------------------------
cat("[04] 生成CAFE可视化...\n")
cafe_sig <- file.path(delivery_dir, "04_基因家族动态分析", "显著变化家族.tsv")
out04 <- fig_dir("04_基因家族动态分析", "figures")

cafe_dt <- fread(cafe_sig, sep = "\t", header = TRUE)
sp5 <- c("BH", "CK", "TAU", "TCH", "RSO")
sp_cols <- sapply(sp5, function(sp) {
  x <- grep(paste0("^", sp, "<"), names(cafe_dt), value = TRUE)
  if (length(x) == 0) NA_character_ else x[1]
})
names(sp_cols) <- sp5
if (any(is.na(sp_cols))) {
  warning("CAFE显著表中缺少物种列：", paste(names(sp_cols)[is.na(sp_cols)], collapse = ","))
}

stat_list <- lapply(sp5, function(sp) {
  col <- sp_cols[[sp]]
  v <- cafe_dt[[col]]
  data.frame(
    Species = sp,
    Expanded = sum(v > 0, na.rm = TRUE),
    Contracted = sum(v < 0, na.rm = TRUE),
    Net = sum(v, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
})
cafe_stat <- bind_rows(stat_list)
cafe_stat$Species <- factor(cafe_stat$Species, levels = sp5)

cafe_long <- cafe_stat %>%
  tidyr::pivot_longer(cols = c(Expanded, Contracted), names_to = "Direction", values_to = "Count") %>%
  mutate(CountSigned = ifelse(Direction == "Contracted", -Count, Count))

p_cafe_ec <- ggplot(cafe_long, aes(x = Species, y = CountSigned, fill = Direction)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = c(Expanded = palette14[8], Contracted = palette14[5])) +
  labs(title = "CAFE显著家族：扩张/收缩数量（近缘类群5物种）", x = NULL, y = "家族数（收缩为负）") +
  theme_pub(11)
save_pdf(p_cafe_ec, file.path(out04, "01_CAFE_扩张收缩数量_近缘类群5物种.pdf"), width = 8, height = 6)

p_cafe_net <- ggplot(cafe_stat, aes(x = Species, y = Net, fill = Species)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = species_colors[sp5]) +
  labs(title = "CAFE显著家族：净变化（sum，近缘类群5物种）", x = NULL, y = "净变化（sum）") +
  theme_pub(11)
save_pdf(p_cafe_net, file.path(out04, "02_CAFE_净变化sum_近缘类群5物种.pdf"), width = 8, height = 6)

# TCH变化分布
tch_col <- sp_cols[["TCH"]]
p_tch_hist <- ggplot(data.frame(v = cafe_dt[[tch_col]]), aes(x = v)) +
  geom_histogram(bins = 60, fill = palette14[4], color = "white") +
  labs(title = "TCH 节点变化值分布（CAFE显著家族）", x = "变化值（扩张为正，收缩为负）", y = "家族数") +
  theme_pub(11)
save_pdf(p_tch_hist, file.path(out04, "03_TCH变化值分布.pdf"), width = 9, height = 6)

# 热图：按TCH绝对变化Top100
abs_order <- order(abs(cafe_dt[[tch_col]]), decreasing = TRUE)
topm <- cafe_dt[abs_order[1:min(100, nrow(cafe_dt))]]
hm <- as.data.frame(topm[, ..sp_cols])
colnames(hm) <- names(sp_cols)
hm$FamilyID <- topm$FamilyID
hm_long <- hm %>%
  tidyr::pivot_longer(cols = all_of(names(sp_cols)), names_to = "Species", values_to = "Delta") %>%
  mutate(Species = factor(Species, levels = sp5),
         FamilyID = factor(FamilyID, levels = rev(unique(FamilyID))))
p_cafe_hm <- ggplot(hm_long, aes(x = Species, y = FamilyID, fill = Delta)) +
  geom_tile() +
  scale_fill_gradient2(low = palette14[2], mid = "white", high = palette14[5], midpoint = 0) +
  labs(title = "CAFE显著家族变化热图（按TCH绝对变化Top100）", x = NULL, y = NULL) +
  theme_pub(9)
save_pdf(p_cafe_hm, file.path(out04, "04_CAFE变化热图_TCH_top100.pdf"), width = 8, height = 11)

# ------------------------------------------------------------------------------
# 05 WGD：Ks统计 + Ks密度对比（使用完整ks_all_results.tsv）
# ------------------------------------------------------------------------------
cat("[05] 生成WGD/Ks可视化...\n")
ks_sum <- file.path(delivery_dir, "05_全基因组复制分析", "Ks统计汇总.tsv")
out05 <- fig_dir("05_全基因组复制分析", "figures")
ks_df <- fread(ks_sum, sep = "\t", header = TRUE)
ks_df[, Pair := factor(Pair, levels = sp5)]

p_ks_count <- ggplot(as.data.frame(ks_df), aes(x = Pair, y = Count, fill = Pair)) +
  geom_col(width = 0.75) +
  scale_fill_manual(values = species_colors[sp5]) +
  scale_y_continuous(labels = comma) +
  labs(title = "Ks有效值数量（Count）", x = NULL, y = "Count") +
  theme_pub(11)
save_pdf(p_ks_count, file.path(out05, "01_Ks有效值数量_Count.pdf"), width = 8, height = 6)

ks_long <- as.data.frame(ks_df) %>%
  tidyr::pivot_longer(cols = c("Mean_Ks", "Median_Ks"), names_to = "Stat", values_to = "Ks")
p_ks_mm <- ggplot(ks_long, aes(x = Pair, y = Ks, color = Stat, group = Stat)) +
  geom_point(size = 3) +
  geom_line(linewidth = 0.6) +
  scale_color_manual(values = c(Mean_Ks = palette14[2], Median_Ks = palette14[5])) +
  labs(title = "Ks均值/中位数对比", x = NULL, y = "Ks") +
  theme_pub(11)
save_pdf(p_ks_mm, file.path(out05, "02_Ks均值_中位数对比.pdf"), width = 8, height = 6)

# 从全量Ks文件生成密度（如读取失败则跳过）
ks_all_file <- "/path/to/project_root/comparative_genomics/04_wgd/ks_all_results.tsv"
if (file.exists(ks_all_file)) {
  ks_all <- fread(ks_all_file, sep = "\t", header = TRUE, select = c("Species", "Ks"), showProgress = FALSE)
  ks_all[, Ks := suppressWarnings(as.numeric(Ks))]
  ks_all <- ks_all[!is.na(Ks) & Ks >= 0 & Ks <= 5]
  ks_all <- ks_all[Species %in% sp5]
  ks_all[, Species := factor(Species, levels = sp5)]
  p_ks_den <- ggplot(as.data.frame(ks_all), aes(x = Ks, color = Species)) +
    geom_density(linewidth = 0.8, adjust = 1.0) +
    scale_color_manual(values = species_colors[sp5]) +
    labs(title = "Ks密度分布对比（0-5，近缘类群5物种）", x = "Ks", y = "Density") +
    theme_pub(11)
  save_pdf(p_ks_den, file.path(out05, "03_Ks密度分布_近缘类群5物种.pdf"), width = 8, height = 6)
}

# ------------------------------------------------------------------------------
# 06 正选择：omega分布/散点/Top
# ------------------------------------------------------------------------------
cat("[06] 生成正选择可视化...\n")
paml_file <- file.path(delivery_dir, "06_正选择分析", "PAML结果汇总.tsv")
pos_file <- file.path(delivery_dir, "06_正选择分析", "正选择基因列表.tsv")
out06 <- fig_dir("06_正选择分析", "figures")

paml <- fread(paml_file, sep = "\t", header = TRUE)
paml[, omega := as.numeric(omega)]
paml[, lnL := as.numeric(lnL)]
paml[, positive_sites := as.numeric(positive_sites)]
paml[, is_pos := omega > 1]

p_omega_hist <- ggplot(as.data.frame(paml), aes(x = omega)) +
  geom_histogram(bins = 50, fill = palette14[2], color = "white") +
  scale_x_continuous(trans = "log10", breaks = c(1, 2, 5, 10, 50, 100, 500, 1000)) +
  labs(title = "omega 分布（log10刻度）", x = "omega", y = "家族数") +
  theme_pub(11)
save_pdf(p_omega_hist, file.path(out06, "01_omega分布_log10.pdf"), width = 8, height = 6)

paml2 <- paml
paml2[, omega_clip := pmin(omega, 50)]
p_scatter <- ggplot(as.data.frame(paml2), aes(x = lnL, y = omega_clip, color = is_pos)) +
  geom_point(alpha = 0.8, size = 2) +
  scale_color_manual(values = c(`FALSE` = "grey50", `TRUE` = palette14[5])) +
  labs(title = "lnL vs omega（omega截断到50）", x = "lnL", y = "omega(clip≤50)") +
  theme_pub(11)
save_pdf(p_scatter, file.path(out06, "02_lnL_vs_omega_scatter.pdf"), width = 8, height = 6)

top_sites <- paml[order(-positive_sites)][1:min(20, nrow(paml))]
top_sites[, FamilyID := factor(FamilyID, levels = rev(FamilyID))]
p_sites <- ggplot(as.data.frame(top_sites), aes(x = FamilyID, y = positive_sites)) +
  geom_col(fill = palette14[4], width = 0.75) +
  coord_flip() +
  labs(title = "Top20 正选择位点数（positive_sites）", x = NULL, y = "positive_sites") +
  theme_pub(10)
save_pdf(p_sites, file.path(out06, "03_Top20_positive_sites.pdf"), width = 8, height = 7)

if (file.exists(pos_file)) {
  pos <- fread(pos_file, sep = "\t", header = TRUE)
  pos[, omega := as.numeric(omega)]
  pos <- pos[order(-omega)][1:min(20, nrow(pos))]
  pos[, FamilyID := factor(FamilyID, levels = rev(FamilyID))]
  p_pos_top <- ggplot(as.data.frame(pos), aes(x = FamilyID, y = omega)) +
    geom_col(fill = palette14[5], width = 0.75) +
    coord_flip() +
    labs(title = "Top omega 家族（来自正选择列表）", x = NULL, y = "omega") +
    theme_pub(10)
  save_pdf(p_pos_top, file.path(out06, "04_Top20_omega_正选择列表.pdf"), width = 8, height = 7)
}

cat("完成：已在DELIVERY_PACKAGE各模块下创建 figures/ 目录并输出PDF。\n")
