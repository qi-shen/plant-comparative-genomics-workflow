#!/usr/bin/env Rscript
# 基因组注释结果评估脚本
# 评估结构注释和功能注释的质量

suppressPackageStartupMessages({
  library(rtracklayer)
  library(Biostrings)
  library(dplyr)
  library(ggplot2)
})

# 设置工作目录和输出路径
work_dir <- "/path/to/project_root"
setwd(work_dir)

output_dir <- file.path(work_dir, "annotation", "evaluation")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# 定义物种
species_list <- c("BH", "CK")

# 评估函数
evaluate_annotation <- function(species) {
  cat(sprintf("\n=== 评估 %s 样本注释结果 ===\n", species))
  
  # 文件路径
  gff3_file <- file.path(work_dir, "annotation", species, "structure", 
                         paste0(species, "_final.gff3"))
  cds_file <- file.path(work_dir, "annotation", species, "structure",
                       paste0(species, "_genes.cds.fa"))
  pep_file <- file.path(work_dir, "annotation", species, "structure",
                       paste0(species, "_genes.pep.fa"))
  func_file <- file.path(work_dir, "annotation", species, "function",
                        paste0(species, "_swissprot_annotation.txt"))
  
  results <- list()
  results$species <- species
  
  # 1. 读取GFF3文件并统计
  if (file.exists(gff3_file)) {
    cat("读取GFF3文件...\n")
    gff3 <- import(gff3_file, format = "gff3")
    
    # 统计各类特征
    results$total_features <- length(gff3)
    results$genes <- sum(gff3$type == "gene")
    results$mRNAs <- sum(gff3$type == "transcript" | gff3$type == "mRNA")
    results$CDSs <- sum(gff3$type == "CDS")
    results$exons <- sum(gff3$type == "exon")
    results$introns <- sum(gff3$type == "intron")
    
    # 提取基因信息
    genes <- gff3[gff3$type == "gene"]
    if (length(genes) > 0) {
      results$gene_width_mean <- mean(width(genes))
      results$gene_width_median <- median(width(genes))
      results$gene_width_min <- min(width(genes))
      results$gene_width_max <- max(width(genes))
    }
    
    # 提取CDS信息
    cds_features <- gff3[gff3$type == "CDS"]
    if (length(cds_features) > 0) {
      results$cds_length_mean <- mean(width(cds_features))
      results$cds_length_median <- median(width(cds_features))
      results$cds_length_min <- min(width(cds_features))
      results$cds_length_max <- max(width(cds_features))
    }
    
    # 提取外显子信息
    exons <- gff3[gff3$type == "exon"]
    if (length(exons) > 0) {
      results$exon_length_mean <- mean(width(exons))
      results$exon_length_median <- median(width(exons))
      results$exon_length_min <- min(width(exons))
      results$exon_length_max <- max(width(exons))
    }
    
    # 计算每个基因的平均外显子数
    if (length(genes) > 0 && length(exons) > 0) {
      # 通过Parent属性关联外显子到转录本
      transcripts <- gff3[gff3$type == "transcript" | gff3$type == "mRNA"]
      if (length(transcripts) > 0) {
        transcript_ids <- unique(transcripts$ID)
        exon_per_transcript <- sapply(transcript_ids, function(tid) {
          sum(exons$Parent == tid, na.rm = TRUE)
        })
        results$exons_per_transcript_mean <- mean(exon_per_transcript)
        results$exons_per_transcript_median <- median(exon_per_transcript)
        results$exons_per_transcript_min <- min(exon_per_transcript)
        results$exons_per_transcript_max <- max(exon_per_transcript)
      }
    }
    
    cat(sprintf("  基因数: %d\n", results$genes))
    cat(sprintf("  转录本数: %d\n", results$mRNAs))
    cat(sprintf("  CDS数: %d\n", results$CDSs))
    cat(sprintf("  外显子数: %d\n", results$exons))
  } else {
    cat(sprintf("警告: GFF3文件不存在: %s\n", gff3_file))
  }
  
  # 2. 检查CDS序列
  if (file.exists(cds_file)) {
    cat("检查CDS序列...\n")
    cds_seqs <- readDNAStringSet(cds_file)
    results$cds_count <- length(cds_seqs)
    results$cds_total_length <- sum(width(cds_seqs))
    results$cds_mean_length <- mean(width(cds_seqs))
    results$cds_median_length <- median(width(cds_seqs))
    
    # 检查是否可被3整除（完整CDS）
    cds_lengths <- width(cds_seqs)
    complete_cds <- sum(cds_lengths %% 3 == 0)
    results$complete_cds_count <- complete_cds
    results$complete_cds_ratio <- complete_cds / length(cds_seqs) * 100
    
    # 检查是否有终止密码子
    has_stop <- sum(vapply(cds_seqs, function(x) {
      seq <- as.character(x)
      nchar(seq) >= 3 && substr(seq, nchar(seq) - 2, nchar(seq)) %in% c("TAA", "TAG", "TGA")
    }, logical(1)))
    results$cds_with_stop <- has_stop
    results$cds_with_stop_ratio <- has_stop / length(cds_seqs) * 100
    
    cat(sprintf("  CDS序列数: %d\n", results$cds_count))
    cat(sprintf("  完整CDS (长度可被3整除): %d (%.2f%%)\n", 
                complete_cds, results$complete_cds_ratio))
    cat(sprintf("  含终止密码子: %d (%.2f%%)\n", 
                has_stop, results$cds_with_stop_ratio))
  } else {
    cat(sprintf("警告: CDS文件不存在: %s\n", cds_file))
  }
  
  # 3. 检查蛋白质序列
  if (file.exists(pep_file)) {
    cat("检查蛋白质序列...\n")
    pep_seqs <- readAAStringSet(pep_file)
    results$pep_count <- length(pep_seqs)
    results$pep_total_length <- sum(width(pep_seqs))
    results$pep_mean_length <- mean(width(pep_seqs))
    results$pep_median_length <- median(width(pep_seqs))
    
    # 检查是否有终止密码子（*）
    has_stop_aa <- sum(vapply(pep_seqs, function(x) {
      seq <- as.character(x)
      endsWith(seq, "*")
    }, logical(1)))
    results$pep_with_stop <- has_stop_aa
    results$pep_with_stop_ratio <- has_stop_aa / length(pep_seqs) * 100
    
    # 检查是否有内部终止密码子（可能的问题）
    internal_stop <- sum(vapply(pep_seqs, function(x) {
      seq <- as.character(x)
      nchar(seq) > 1 && grepl("\\*", substr(seq, 1, nchar(seq) - 1))
    }, logical(1)))
    results$pep_internal_stop <- internal_stop
    
    cat(sprintf("  蛋白质序列数: %d\n", results$pep_count))
    cat(sprintf("  含终止密码子(*): %d (%.2f%%)\n", 
                has_stop_aa, results$pep_with_stop_ratio))
    if (internal_stop > 0) {
      cat(sprintf("  警告: %d 个序列含有内部终止密码子\n", internal_stop))
    }
  } else {
    cat(sprintf("警告: 蛋白质文件不存在: %s\n", pep_file))
  }
  
  # 4. 检查功能注释
  if (file.exists(func_file)) {
    cat("检查功能注释...\n")
    func_anno <- read.delim(func_file, sep = "\t", stringsAsFactors = FALSE, 
                           comment.char = "#", check.names = FALSE)
    
    if (nrow(func_anno) > 0) {
      # 统计唯一基因数
      unique_genes <- unique(func_anno[[1]])  # 第一列通常是基因ID
      results$annotated_genes <- length(unique_genes)
      
      # 如果有总基因数，计算注释率
      if (!is.null(results$genes)) {
        results$annotation_rate <- results$annotated_genes / results$genes * 100
      }
      
      # 统计注释来源
      if ("Identity" %in% colnames(func_anno)) {
        results$mean_identity <- mean(func_anno$Identity, na.rm = TRUE)
        results$median_identity <- median(func_anno$Identity, na.rm = TRUE)
      }
      
      if ("E_value" %in% colnames(func_anno)) {
        results$mean_evalue <- mean(func_anno$E_value, na.rm = TRUE)
        results$median_evalue <- median(func_anno$E_value, na.rm = TRUE)
      }
      
      cat(sprintf("  有功能注释的基因数: %d\n", results$annotated_genes))
      if (!is.null(results$annotation_rate)) {
        cat(sprintf("  注释率: %.2f%%\n", results$annotation_rate))
      }
      if (!is.null(results$mean_identity)) {
        cat(sprintf("  平均序列相似度: %.2f%%\n", results$mean_identity))
      }
    }
  } else {
    cat(sprintf("警告: 功能注释文件不存在: %s\n", func_file))
  }
  
  # 5. 序列一致性检查
  if (!is.null(results$cds_count) && !is.null(results$pep_count)) {
    cat("检查序列一致性...\n")
    if (results$cds_count == results$pep_count) {
      results$sequence_consistency <- "一致"
    } else {
      results$sequence_consistency <- sprintf("不一致 (CDS: %d, PEP: %d)", 
                                             results$cds_count, results$pep_count)
      cat(sprintf("  警告: CDS和蛋白质序列数量不一致\n"))
    }
  }
  
  return(results)
}

# 执行评估
all_results <- list()
for (species in species_list) {
  all_results[[species]] <- evaluate_annotation(species)
}

# 生成汇总报告
cat("\n=== 生成评估报告 ===\n")
report_file <- file.path(output_dir, "annotation_evaluation_report.txt")
sink(report_file)

cat("targets注释结果评估报告\n")
cat("=", rep("=", 50), "\n", sep = "")
cat(sprintf("生成时间: %s\n\n", Sys.time()))

for (species in species_list) {
  res <- all_results[[species]]
  cat(sprintf("\n【%s 样本】\n", species))
  cat(rep("-", 60), "\n", sep = "")
  
  cat("\n1. 结构注释统计:\n")
  if (!is.null(res$genes)) {
    cat(sprintf("   基因数: %d\n", res$genes))
    cat(sprintf("   转录本数: %d\n", res$mRNAs))
    cat(sprintf("   CDS数: %d\n", res$CDSs))
    cat(sprintf("   外显子数: %d\n", res$exons))
    cat(sprintf("   内含子数: %d\n", res$introns))
  }
  
  cat("\n2. 基因长度统计:\n")
  if (!is.null(res$gene_width_mean)) {
    cat(sprintf("   平均长度: %.0f bp\n", res$gene_width_mean))
    cat(sprintf("   中位数: %.0f bp\n", res$gene_width_median))
    cat(sprintf("   范围: %d - %d bp\n", res$gene_width_min, res$gene_width_max))
  }
  
  cat("\n3. CDS统计:\n")
  if (!is.null(res$cds_count)) {
    cat(sprintf("   CDS序列数: %d\n", res$cds_count))
    cat(sprintf("   平均长度: %.0f bp\n", res$cds_mean_length))
    cat(sprintf("   中位数: %.0f bp\n", res$cds_median_length))
    cat(sprintf("   完整CDS (长度可被3整除): %d (%.2f%%)\n", 
                res$complete_cds_count, res$complete_cds_ratio))
    cat(sprintf("   含终止密码子: %d (%.2f%%)\n", 
                res$cds_with_stop, res$cds_with_stop_ratio))
  }
  
  cat("\n4. 蛋白质统计:\n")
  if (!is.null(res$pep_count)) {
    cat(sprintf("   蛋白质序列数: %d\n", res$pep_count))
    cat(sprintf("   平均长度: %.0f aa\n", res$pep_mean_length))
    cat(sprintf("   中位数: %.0f aa\n", res$pep_median_length))
    cat(sprintf("   含终止密码子(*): %d (%.2f%%)\n", 
                res$pep_with_stop, res$pep_with_stop_ratio))
    if (res$pep_internal_stop > 0) {
      cat(sprintf("   警告: %d 个序列含有内部终止密码子\n", res$pep_internal_stop))
    }
  }
  
  cat("\n5. 外显子统计:\n")
  if (!is.null(res$exons_per_transcript_mean)) {
    cat(sprintf("   每个转录本平均外显子数: %.2f\n", res$exons_per_transcript_mean))
    cat(sprintf("   中位数: %.0f\n", res$exons_per_transcript_median))
    cat(sprintf("   范围: %d - %d\n", res$exons_per_transcript_min, 
                res$exons_per_transcript_max))
  }
  
  cat("\n6. 功能注释统计:\n")
  if (!is.null(res$annotated_genes)) {
    cat(sprintf("   有功能注释的基因数: %d\n", res$annotated_genes))
    if (!is.null(res$annotation_rate)) {
      cat(sprintf("   注释率: %.2f%%\n", res$annotation_rate))
    }
    if (!is.null(res$mean_identity)) {
      cat(sprintf("   平均序列相似度: %.2f%%\n", res$mean_identity))
      cat(sprintf("   中位数: %.2f%%\n", res$median_identity))
    }
    if (!is.null(res$mean_evalue)) {
      cat(sprintf("   平均E值: %.2e\n", res$mean_evalue))
      cat(sprintf("   中位数: %.2e\n", res$median_evalue))
    }
  }
  
  cat("\n7. 质量评估:\n")
  if (!is.null(res$sequence_consistency)) {
    cat(sprintf("   序列一致性: %s\n", res$sequence_consistency))
  }
  
  # 质量评分
  quality_score <- 0
  quality_notes <- c()
  
  if (!is.null(res$complete_cds_ratio) && res$complete_cds_ratio > 95) {
    quality_score <- quality_score + 20
  } else if (!is.null(res$complete_cds_ratio)) {
    quality_notes <- c(quality_notes, 
                      sprintf("CDS完整性较低 (%.2f%%)", res$complete_cds_ratio))
  }
  
  if (!is.null(res$annotation_rate) && res$annotation_rate > 60) {
    quality_score <- quality_score + 20
  } else if (!is.null(res$annotation_rate)) {
    quality_notes <- c(quality_notes, 
                      sprintf("功能注释率较低 (%.2f%%)", res$annotation_rate))
  }
  
  if (!is.null(res$mean_identity) && res$mean_identity > 50) {
    quality_score <- quality_score + 20
  } else if (!is.null(res$mean_identity)) {
    quality_notes <- c(quality_notes, 
                      sprintf("平均序列相似度较低 (%.2f%%)", res$mean_identity))
  }
  
  if (!is.null(res$pep_internal_stop) && res$pep_internal_stop == 0) {
    quality_score <- quality_score + 20
  } else if (!is.null(res$pep_internal_stop) && res$pep_internal_stop > 0) {
    quality_notes <- c(quality_notes, 
                      sprintf("发现 %d 个含内部终止密码子的序列", res$pep_internal_stop))
  }
  
  if (!is.null(res$sequence_consistency) && res$sequence_consistency == "一致") {
    quality_score <- quality_score + 20
  } else {
    quality_notes <- c(quality_notes, "CDS和蛋白质序列数量不一致")
  }
  
  cat(sprintf("   质量评分: %d/100\n", quality_score))
  if (length(quality_notes) > 0) {
    cat("   需要关注的问题:\n")
    for (note in quality_notes) {
      cat(sprintf("     - %s\n", note))
    }
  }
}

# 比较两个样本
cat("\n\n【BH vs CK 比较】\n")
cat(rep("-", 60), "\n", sep = "")
bh_res <- all_results[["BH"]]
ck_res <- all_results[["CK"]]

if (!is.null(bh_res$genes) && !is.null(ck_res$genes)) {
  cat(sprintf("基因数差异: %d (BH: %d, CK: %d)\n", 
              abs(bh_res$genes - ck_res$genes), bh_res$genes, ck_res$genes))
}

if (!is.null(bh_res$annotation_rate) && !is.null(ck_res$annotation_rate)) {
  cat(sprintf("功能注释率: BH %.2f%%, CK %.2f%%\n", 
              bh_res$annotation_rate, ck_res$annotation_rate))
}

if (!is.null(bh_res$mean_identity) && !is.null(ck_res$mean_identity)) {
  cat(sprintf("平均序列相似度: BH %.2f%%, CK %.2f%%\n", 
              bh_res$mean_identity, ck_res$mean_identity))
}

sink()

cat(sprintf("\n评估报告已保存至: %s\n", report_file))

# 生成可视化图表
cat("\n生成可视化图表...\n")
plot_file <- file.path(output_dir, "annotation_evaluation_plots.pdf")
pdf(plot_file, width = 12, height = 8)

# 准备数据
plot_data <- data.frame(
  Species = rep(species_list, each = 4),
  Metric = rep(c("基因数", "转录本数", "CDS数", "外显子数"), 2),
  Value = c(
    bh_res$genes %||% 0, bh_res$mRNAs %||% 0, bh_res$CDSs %||% 0, bh_res$exons %||% 0,
    ck_res$genes %||% 0, ck_res$mRNAs %||% 0, ck_res$CDSs %||% 0, ck_res$exons %||% 0
  )
)

if (sum(plot_data$Value) > 0) {
  p1 <- ggplot(plot_data, aes(x = Metric, y = Value, fill = Species)) +
    geom_bar(stat = "identity", position = "dodge") +
    scale_fill_manual(values = c("BH" = "#00BFAE", "CK" = "#1F77B4")) +
    labs(title = "结构注释统计比较", x = "特征类型", y = "数量") +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(color = "black"),
          panel.border = element_rect(color = "black", fill = NA))
  print(p1)
}

# 功能注释率比较
if (!is.null(bh_res$annotation_rate) && !is.null(ck_res$annotation_rate)) {
  anno_data <- data.frame(
    Species = species_list,
    Annotation_Rate = c(bh_res$annotation_rate, ck_res$annotation_rate)
  )
  
  p2 <- ggplot(anno_data, aes(x = Species, y = Annotation_Rate, fill = Species)) +
    geom_bar(stat = "identity") +
    scale_fill_manual(values = c("BH" = "#00BFAE", "CK" = "#1F77B4")) +
    labs(title = "功能注释率比较", x = "样本", y = "注释率 (%)") +
    ylim(0, 100) +
    theme_minimal() +
    theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(color = "black"),
          panel.border = element_rect(color = "black", fill = NA))
  print(p2)
}

dev.off()
cat(sprintf("图表已保存至: %s\n", plot_file))

cat("\n评估完成！\n")

