#!/usr/bin/env Rscript
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
      panel.grid       = element_blank(),
      axis.line        = element_line(color = "black", linewidth = 0.4),
      plot.title       = element_text(hjust = 0.5, face = "bold"),
      legend.title     = element_blank()
    )
}

palette14 <- c("#00BFAE","#1F77B4","#9467BD","#FF7F0E",
               "#D62728","#F08080","#8B4513","#228B22",
               "#90EE90","#00008B","#DDA0DD","#006400",
               "#8B0000","#ADD8E6")

species_order <- c("BH","CK","TAU","TCH","RSO",
                   "APA","ATH","CQU","DCA","FMU","GPA","HAM","POL","SMO","VVI")
species_cn <- c(
  BH="T01BH", CK="T02CK", TAU="TAUC02", TCH="TCHC03", RSO="RSOC01",
  APA="APAC04", ATH="ATHO01", CQU="CQUC05", DCA="DCAC06", FMU="FMUC08",
  GPA="GPAC07", HAM="HAMC09", POL="POLC10", SMO="SMOC11", VVI="VVIO02")
species_colors <- setNames(rep(palette14, length.out=15), species_order)

D <- "/path/to/project_root/comparative_genomics/Comparative_Genomics_Results"

save_fig <- function(p, path, w=9, h=6) {
  dir.create(dirname(path), recursive=TRUE, showWarnings=FALSE)
  ggsave(path, p, width=w, height=h, units="in", device=cairo_pdf)
  ggsave(sub("\\.pdf$",".png",path), p, width=w, height=h, units="in", dpi=300, device="png")
}

cat("[01] Gene family figures\n")
stats_dt <- fread(file.path(D,"01_基因家族鉴定/OrthoFinder统计/Statistics_PerSpecies.tsv"),
                  sep="\t", header=TRUE, fill=TRUE)
setnames(stats_dt, 1, "Metric")
stats_long <- melt(stats_dt[Metric %in% c("Number of genes","Number of genes in orthogroups",
                                           "Number of unassigned genes",
                                           "Number of species-specific orthogroups")],
                   id.vars="Metric", variable.name="Species", value.name="Value")
stats_long[, Value := as.numeric(Value)]
stats_long[, Species := factor(Species, levels=species_order)]

genes_df <- stats_long[Metric=="Number of genes"]
p1 <- ggplot(genes_df, aes(x=Species, y=Value, fill=Species)) +
  geom_col(width=0.75) + scale_fill_manual(values=species_colors) +
  scale_x_discrete(labels=species_cn) + scale_y_continuous(labels=comma) +
  labs(title="各物种基因数（longest transcript）", x=NULL, y="基因数") +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p1, file.path(D,"01_基因家族鉴定/figures/01_各物种基因数.pdf"), 10.5, 6)

assign_df <- stats_long[Metric %in% c("Number of genes in orthogroups","Number of unassigned genes")] %>%
  as.data.frame() %>% mutate(Group=ifelse(Metric=="Number of genes in orthogroups","已分配","未分配"))
p2 <- ggplot(assign_df, aes(x=Species, y=Value, fill=Group)) +
  geom_col(width=0.75) +
  scale_fill_manual(values=c("已分配"=palette14[2],"未分配"=palette14[5])) +
  scale_x_discrete(labels=species_cn) + scale_y_continuous(labels=comma) +
  labs(title="各物种基因分配情况", x=NULL, y="基因数") +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p2, file.path(D,"01_基因家族鉴定/figures/02_基因分配_已分配vs未分配.pdf"), 10.5, 6)

spec_df <- stats_long[Metric=="Number of species-specific orthogroups"]
p3 <- ggplot(spec_df, aes(x=Species, y=Value, fill=Species)) +
  geom_col(width=0.75) + scale_fill_manual(values=species_colors) +
  scale_x_discrete(labels=species_cn) + scale_y_continuous(labels=comma) +
  labs(title="各物种特异基因家族数", x=NULL, y="Species-specific orthogroups") +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p3, file.path(D,"01_基因家族鉴定/figures/03_各物种特异家族数.pdf"), 10.5, 6)

og_dt <- fread(file.path(D,"01_基因家族鉴定/Orthogroups/Orthogroups.GeneCount.tsv"),
               sep="\t", header=TRUE, select=c("Orthogroup","Total"))
p4 <- ggplot(as.data.frame(og_dt), aes(x=as.numeric(Total))) +
  geom_histogram(bins=60, fill=palette14[2], color="white") +
  scale_x_continuous(trans="log10", breaks=c(1,2,5,10,20,50,100,500,1000)) +
  labs(title="Orthogroup大小分布（log10）", x="Orthogroup大小", y="数量") +
  theme_pub(11)
save_fig(p4, file.path(D,"01_基因家族鉴定/figures/04_orthogroup大小分布.pdf"), 10, 6)

og_full <- fread(file.path(D,"01_基因家族鉴定/Orthogroups/Orthogroups.GeneCount.tsv"),
                 sep="\t", header=TRUE)
setDT(og_full); setorder(og_full, -Total)
topN <- og_full[1:50]
top_long <- melt(topN, id.vars=c("Orthogroup","Total"), variable.name="Species", value.name="Count")
top_long <- top_long[Species %in% species_order]
top_long[, Species := factor(Species, levels=species_order)]
top_long[, Orthogroup := factor(Orthogroup, levels=rev(unique(Orthogroup)))]
top_long[, logCount := log1p(as.numeric(Count))]
p5 <- ggplot(as.data.frame(top_long), aes(x=Species, y=Orthogroup, fill=logCount)) +
  geom_tile(color=NA) + scale_fill_gradient(low="white", high=palette14[5]) +
  scale_x_discrete(breaks=levels(top_long$Species), labels=species_cn[levels(top_long$Species)]) +
  labs(title="Top50最大基因家族热图（log1p）", x=NULL, y=NULL, fill="log1p(count)") +
  theme_pub(10) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p5, file.path(D,"01_基因家族鉴定/figures/05_Top50家族热图.pdf"), 12, 10)

cat("[02] Phylogeny figures\n")
tr <- read.tree(file.path(D,"02_系统发育分析/SpeciesTree_rooted.nwk"))
tip_cols <- setNames(rep("black",length(tr$tip.label)), tr$tip.label)
tip_cols["BH"] <- palette14[5]; tip_cols["CK"] <- palette14[2]
pdf(file.path(D,"02_系统发育分析/figures/01_物种系统发育树.pdf"), width=10, height=6)
par(mar=c(1,1,3,1))
plot(tr, cex=0.8, tip.color=tip_cols, main="物种系统发育树（BH红 / CK蓝）")
add.scale.bar(length=0.05, lwd=2)
dev.off()
png(file.path(D,"02_系统发育分析/figures/01_物种系统发育树.png"), width=3000, height=1800, res=300)
par(mar=c(1,1,3,1))
plot(tr, cex=0.8, tip.color=tip_cols, main="物种系统发育树（BH红 / CK蓝）")
add.scale.bar(length=0.05, lwd=2)
dev.off()

cat("[03] Synteny figures\n")
syn_dt <- fread(file.path(D,"03_共线性分析/同源基因对统计.tsv"), sep="\t", header=TRUE)
syn_dt <- syn_dt[File != "TOTAL"]
syn_dt[, Type := ifelse(grepl("lifted", File), "lifted", "anchors")]
syn_dt[, Pair := sub("\\.(lifted\\.)?anchors$", "", File)]
p6 <- ggplot(as.data.frame(syn_dt), aes(x=Pair, y=Pairs, fill=Type)) +
  geom_col(position=position_dodge(width=0.8), width=0.75) +
  scale_fill_manual(values=c(anchors=palette14[2], lifted=palette14[4])) +
  scale_y_continuous(labels=comma) +
  labs(title="共线性同源基因对统计", x=NULL, y="Pairs") +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p6, file.path(D,"03_共线性分析/figures/01_共线性同源对统计.pdf"), 10, 6)

syn_a <- syn_dt[Type=="anchors", .(Sp1=sub("\\..*","",Pair), Sp2=sub(".*\\.","",Pair), Pairs)]
all_sp <- sort(unique(c(syn_a$Sp1, syn_a$Sp2)))
grid <- CJ(Sp1=all_sp, Sp2=all_sp)
syn_mat <- merge(grid, syn_a, by=c("Sp1","Sp2"), all.x=TRUE)
syn_mat[is.na(Pairs), Pairs := 0]
p7 <- ggplot(as.data.frame(syn_mat), aes(x=Sp1, y=Sp2, fill=Pairs)) +
  geom_tile(color="white", linewidth=0.2) +
  geom_text(aes(label=ifelse(Pairs>0, comma(Pairs), "")), size=3) +
  scale_fill_gradient(low="white", high=palette14[5], labels=comma) +
  labs(title="共线性anchors同源对热图", x=NULL, y=NULL) +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p7, file.path(D,"03_共线性分析/figures/02_共线性anchors热图.pdf"), 8, 7)

cat("[04] CAFE figures\n")
cafe_dt <- fread(file.path(D,"04_基因家族扩张收缩/显著变化家族.tsv"), sep="\t", header=TRUE)
sp_cols <- sapply(species_order, function(sp) {
  x <- grep(paste0("^",sp,"<"), names(cafe_dt), value=TRUE)
  if(length(x)==0) NA_character_ else x[1]
})
names(sp_cols) <- species_order
valid_sp <- names(sp_cols)[!is.na(sp_cols)]

stat_list <- lapply(valid_sp, function(sp) {
  v <- cafe_dt[[sp_cols[[sp]]]]
  data.frame(Species=sp, Expanded=sum(v>0,na.rm=T), Contracted=sum(v<0,na.rm=T), Net=sum(v,na.rm=T))
})
cafe_stat <- bind_rows(stat_list)
cafe_stat$Species <- factor(cafe_stat$Species, levels=valid_sp)
cafe_long <- cafe_stat %>%
  pivot_longer(c(Expanded,Contracted), names_to="Direction", values_to="Count") %>%
  mutate(CountSigned=ifelse(Direction=="Contracted",-Count,Count))

p8 <- ggplot(cafe_long, aes(x=Species, y=CountSigned, fill=Direction)) +
  geom_col(width=0.75) +
  scale_fill_manual(values=c(Expanded=palette14[8], Contracted=palette14[5]),
                    labels=c(Expanded="扩张", Contracted="收缩")) +
  labs(title="CAFE显著家族扩张/收缩数量", x=NULL, y="家族数（收缩为负）") +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p8, file.path(D,"04_基因家族扩张收缩/figures/01_扩张收缩数量.pdf"), 10, 6)

p9 <- ggplot(cafe_stat, aes(x=Species, y=Net, fill=Species)) +
  geom_col(width=0.75) + scale_fill_manual(values=species_colors[valid_sp]) +
  labs(title="CAFE显著家族净变化", x=NULL, y="净变化（基因数sum）") +
  theme_pub(11) + theme(axis.text.x=element_text(angle=45,hjust=1))
save_fig(p9, file.path(D,"04_基因家族扩张收缩/figures/02_净变化.pdf"), 10, 6)

sp5 <- c("BH","CK","TAU","TCH","RSO")
sp5_cols <- sp_cols[sp5]; sp5_cols <- sp5_cols[!is.na(sp5_cols)]
if(length(sp5_cols) > 0 && "TCH" %in% names(sp5_cols)) {
  tch_col <- sp5_cols[["TCH"]]
  abs_order <- order(abs(cafe_dt[[tch_col]]), decreasing=TRUE)
  topm <- cafe_dt[abs_order[1:min(100,nrow(cafe_dt))]]
  hm <- as.data.frame(topm[, ..sp5_cols])
  colnames(hm) <- names(sp5_cols)
  hm$FamilyID <- topm$FamilyID
  hm_long <- hm %>%
    pivot_longer(cols=all_of(names(sp5_cols)), names_to="Species", values_to="Delta") %>%
    mutate(Species=factor(Species, levels=names(sp5_cols)),
           FamilyID=factor(FamilyID, levels=rev(unique(FamilyID))))
  p10 <- ggplot(hm_long, aes(x=Species, y=FamilyID, fill=Delta)) +
    geom_tile() + scale_fill_gradient2(low=palette14[2], mid="white", high=palette14[5], midpoint=0) +
    labs(title="CAFE变化热图（近缘类群Top100）", x=NULL, y=NULL) + theme_pub(9)
  save_fig(p10, file.path(D,"04_基因家族扩张收缩/figures/03_CAFE变化热图_近缘类群Top100.pdf"), 8, 11)
}

cat("[05] WGD/Ks figures\n")
ks_df <- fread(file.path(D,"05_WGD全基因组复制/Ks统计汇总.tsv"), sep="\t", header=TRUE)
ks_sp5 <- c("BH","CK","TAU","TCH","RSO")
ks_df[, Pair := factor(Pair, levels=ks_sp5)]
p11 <- ggplot(as.data.frame(ks_df), aes(x=Pair, y=Count, fill=Pair)) +
  geom_col(width=0.75) + scale_fill_manual(values=species_colors[ks_sp5]) +
  scale_y_continuous(labels=comma) +
  labs(title="Ks有效值数量", x=NULL, y="Count") + theme_pub(11)
save_fig(p11, file.path(D,"05_WGD全基因组复制/figures/01_Ks有效值数量.pdf"), 8, 6)

ks_long <- as.data.frame(ks_df) %>%
  pivot_longer(cols=c("Mean_Ks","Median_Ks"), names_to="Stat", values_to="Ks")
p12 <- ggplot(ks_long, aes(x=Pair, y=Ks, color=Stat, group=Stat)) +
  geom_point(size=3) + geom_line(linewidth=0.6) +
  scale_color_manual(values=c(Mean_Ks=palette14[2], Median_Ks=palette14[5])) +
  labs(title="Ks均值/中位数对比", x=NULL, y="Ks") + theme_pub(11)
save_fig(p12, file.path(D,"05_WGD全基因组复制/figures/02_Ks均值中位数对比.pdf"), 8, 6)

ks_all_file <- file.path(D,"05_WGD全基因组复制/Ks原始数据/ks_all_results.tsv")
if(file.exists(ks_all_file)) {
  ks_all <- fread(ks_all_file, sep="\t", header=TRUE, select=c("Species","Ks"), showProgress=FALSE)
  ks_all[, Ks := suppressWarnings(as.numeric(Ks))]
  ks_all <- ks_all[!is.na(Ks) & Ks>=0 & Ks<=5 & Species %in% ks_sp5]
  ks_all[, Species := factor(Species, levels=ks_sp5)]
  p13 <- ggplot(as.data.frame(ks_all), aes(x=Ks, color=Species)) +
    geom_density(linewidth=0.8, adjust=1.0) +
    scale_color_manual(values=species_colors[ks_sp5]) +
    labs(title="Ks密度分布对比（近缘类群5物种）", x="Ks", y="Density") + theme_pub(11)
  save_fig(p13, file.path(D,"05_WGD全基因组复制/figures/03_Ks密度分布.pdf"), 8, 6)
}

cat("[06] Positive selection figures\n")
paml <- fread(file.path(D,"06_正选择分析/paml_results_summary.tsv"), sep="\t", header=TRUE)
paml[, omega := as.numeric(omega)]
paml[, lnL := as.numeric(lnL)]
paml[, positive_sites := as.numeric(positive_sites)]
paml[, is_pos := omega > 1]

p14 <- ggplot(as.data.frame(paml), aes(x=omega)) +
  geom_histogram(bins=50, fill=palette14[2], color="white") +
  scale_x_continuous(trans="log10") +
  labs(title="omega分布（log10）", x="omega", y="家族数") + theme_pub(11)
save_fig(p14, file.path(D,"06_正选择分析/figures/01_omega分布.pdf"), 8, 6)

paml2 <- copy(paml); paml2[, omega_clip := pmin(omega, 50)]
p15 <- ggplot(as.data.frame(paml2), aes(x=lnL, y=omega_clip, color=is_pos)) +
  geom_point(alpha=0.8, size=2) +
  scale_color_manual(values=c(`FALSE`="grey50",`TRUE`=palette14[5])) +
  labs(title="lnL vs omega", x="lnL", y="omega (clip 50)") + theme_pub(11)
save_fig(p15, file.path(D,"06_正选择分析/figures/02_lnL_vs_omega.pdf"), 8, 6)

top_sites <- paml[order(-positive_sites)][1:min(20,nrow(paml))]
top_sites[, FamilyID := factor(FamilyID, levels=rev(FamilyID))]
p16 <- ggplot(as.data.frame(top_sites), aes(x=FamilyID, y=positive_sites)) +
  geom_col(fill=palette14[4], width=0.75) + coord_flip() +
  labs(title="Top20正选择位点数", x=NULL, y="Positive sites") + theme_pub(10)
save_fig(p16, file.path(D,"06_正选择分析/figures/03_Top20_positive_sites.pdf"), 8, 7)

pos_file <- file.path(D,"06_正选择分析/positive_selection_genes.tsv")
if(file.exists(pos_file)) {
  pos <- fread(pos_file, sep="\t", header=TRUE)
  pos[, omega := as.numeric(omega)]
  pos <- pos[order(-omega)][1:min(20,nrow(pos))]
  pos[, FamilyID := factor(FamilyID, levels=rev(FamilyID))]
  p17 <- ggplot(as.data.frame(pos), aes(x=FamilyID, y=omega)) +
    geom_col(fill=palette14[5], width=0.75) + coord_flip() +
    labs(title="Top omega正选择家族", x=NULL, y="omega") + theme_pub(10)
  save_fig(p17, file.path(D,"06_正选择分析/figures/04_Top20_omega正选择.pdf"), 8, 7)
}

cat("All figures done.\n")
