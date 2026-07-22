#!/usr/bin/env bash
set -euo pipefail

BASE="/path/to/project_root/comparative_genomics"
LOGDIR="$BASE/logs"
mkdir -p "$LOGDIR"

source "$(conda info --base)/etc/profile.d/conda.sh"

echo "[1/8] Run OrthoFinder with longest proteomes"
conda activate comparative
OF_OUT="$BASE/02_orthofinder_results_longest"
if [ -d "$OF_OUT" ]; then
  mv "$OF_OUT" "${OF_OUT}_backup_$(date +%Y%m%d_%H%M%S)"
fi
python "/home/shenq/Biosofts/OrthoFinder_source/orthofinder.py" \
  -f "$BASE/01_proteomes_longest" \
  -t 120 -a 64 -S diamond -M msa \
  -o "$OF_OUT" | tee "$LOGDIR/orthofinder_longest_$(date +%Y%m%d_%H%M%S).log"

echo "[2/8] Detect latest longest Results_*"
RESULTS_DIR=$(ls -td "$OF_OUT"/Results_* | head -1)
echo "RESULTS_DIR=$RESULTS_DIR"

echo "[3/8] Run CAFE using latest OrthoFinder result"
WORK_DIR="$BASE/07_cafe"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

OG_COUNTS="$RESULTS_DIR/Orthogroups/Orthogroups.GeneCount.tsv"
SPECIES_TREE="$RESULTS_DIR/Species_Tree/SpeciesTree_rooted.txt"

python3 << PY
import pandas as pd
og_counts = pd.read_csv("$OG_COUNTS", sep="\t")
species_cols = [c for c in og_counts.columns if c not in ["Orthogroup", "Total"]]
ogf = og_counts[(og_counts[species_cols] > 0).all(axis=1)]
ogf = ogf[ogf["Total"] <= 500]
out = pd.DataFrame({"Desc": "(null)", "Family": ogf["Orthogroup"]})
for c in species_cols:
    out[c] = ogf[c]
out.to_csv("gene_families_filtered.tsv", sep="\t", index=False)
print("families_for_cafe=", len(out))
PY

cp "$SPECIES_TREE" species_tree.nwk
cafe5 -i gene_families_filtered.tsv -t species_tree.nwk -o cafe_results -I 100 -p -c 64 -P 0.05 \
  2>&1 | tee "$LOGDIR/cafe_longest_$(date +%Y%m%d_%H%M%S).log" || true

echo "[4/8] Parse CAFE summary tables"
python3 "$BASE/scripts/49_analyze_cafe_families.py" || true

echo "[5/8] Refresh WGD summary tables"
python3 "$BASE/scripts/48_summarize_wgd_results.py"

echo "[6/8] Update final report markdown"
python3 "$BASE/scripts/52_create_final_summary.py"

echo "[7/8] Sync DELIVERY_PACKAGE source tables"
mkdir -p "$BASE/DELIVERY_PACKAGE/01_基因家族分析"
mkdir -p "$BASE/DELIVERY_PACKAGE/04_基因家族动态分析"
mkdir -p "$BASE/DELIVERY_PACKAGE/05_全基因组复制分析"
mkdir -p "$BASE/DELIVERY_PACKAGE/06_正选择分析"
mkdir -p "$BASE/DELIVERY_PACKAGE/00_分析报告"

cp "$RESULTS_DIR/Comparative_Genomics_Statistics/Statistics_PerSpecies.tsv" "$BASE/DELIVERY_PACKAGE/01_基因家族分析/OrthoFinder_Statistics_PerSpecies.tsv"
cp "$RESULTS_DIR/Comparative_Genomics_Statistics/Statistics_Overall.tsv" "$BASE/DELIVERY_PACKAGE/01_基因家族分析/OrthoFinder_Statistics_Overall.tsv"
cp "$RESULTS_DIR/Orthogroups/Orthogroups.GeneCount.tsv" "$BASE/DELIVERY_PACKAGE/01_基因家族分析/Orthogroups.GeneCount.tsv"
cp "$RESULTS_DIR/Species_Tree/SpeciesTree_rooted.txt" "$BASE/DELIVERY_PACKAGE/01_基因家族分析/SpeciesTree_rooted.txt"
cp "$BASE/07_cafe/significant_families.tsv" "$BASE/DELIVERY_PACKAGE/04_基因家族动态分析/显著变化家族.tsv"
cp "$BASE/07_cafe/family_change_summary.tsv" "$BASE/DELIVERY_PACKAGE/04_基因家族动态分析/家族扩张收缩统计.tsv"
cp "$BASE/04_wgd/ks_summary_stats.tsv" "$BASE/DELIVERY_PACKAGE/05_全基因组复制分析/Ks统计汇总.tsv"
cp "$BASE/06_selection/paml_results_summary.tsv" "$BASE/DELIVERY_PACKAGE/06_正选择分析/PAML结果汇总.tsv"
cp "$BASE/06_selection/positive_selection_genes.tsv" "$BASE/DELIVERY_PACKAGE/06_正选择分析/正选择基因列表.tsv"
cp "$BASE/reports/final_comprehensive_report.md" "$BASE/DELIVERY_PACKAGE/00_分析报告/最终综合分析报告.md"

echo "[8/8] Regenerate delivery figures"
Rscript "$BASE/scripts/90_generate_delivery_figures.R"

echo "All done."
