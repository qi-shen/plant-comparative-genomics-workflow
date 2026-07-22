#!/usr/bin/env bash
# Orchestrate the recommended comparative-genomics stages.
# Usage:
#   ./run_all.sh              # run all stages
#   ./run_all.sh orthology    # one stage
#   ./run_all.sh list

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/lib/common.sh"
wf_init

CG="${CG_SCRIPTS_DIR}"

run_step() {
  local label="$1"; shift
  wf_log ">>>> ${label}"
  "$@"
  wf_log "<<<< done: ${label}"
}

stage_orthology() {
  run_step "10 prepare proteomes" bash "${CG}/10_prepare_proteomes.sh"
  run_step "11 filter proteomes" python3 "${CG}/11_filter_proteomes.py"
  run_step "13 OrthoFinder" bash "${CG}/13_run_orthofinder.sh"
  run_step "14 extract single-copy" bash "${CG}/14_extract_single_copy_genes.sh"
}

stage_phylogeny() {
  run_step "20 phylogeny" bash "${CG}/20_run_phylogeny.sh"
}

stage_wgd() {
  run_step "30 WGD" bash "${CG}/30_run_wgd_analysis.sh"
  run_step "31 Ks" python3 "${CG}/31_calculate_ks.py"
}

stage_synteny() {
  run_step "40 prepare synteny" python3 "${CG}/40_prepare_synteny_data.py"
  run_step "41 JCVI synteny" bash "${CG}/41_run_jcvi_synteny.sh"
}

stage_selection() {
  run_step "50 prepare selection" bash "${CG}/50_prepare_selection.sh"
  run_step "51 PAML selection" bash "${CG}/51_run_paml_selection.sh"
  run_step "52 CodeML batch" bash "${CG}/52_run_codeml_batch.sh"
}

stage_cafe() {
  run_step "60 CAFE" bash "${CG}/60_run_cafe.sh"
  run_step "61 parse CAFE" python3 "${CG}/61_parse_cafe_results.py"
}

stage_figures() {
  run_step "70 circos" bash "${CG}/70_run_circos.sh"
  if command -v Rscript >/dev/null 2>&1; then
    run_step "78 supplement figures" Rscript "${CG}/78_fix_all_supplement_figures.R"
  else
    wf_log "Rscript not found; skip R figures"
  fi
}

stage_all() {
  stage_orthology
  stage_phylogeny
  stage_wgd
  stage_synteny
  stage_selection
  stage_cafe
  stage_figures
}

usage() {
  cat <<EOF
Usage: $0 [stage]

Stages:
  list | orthology | phylogeny | wgd | synteny | selection | cafe | figures | all
EOF
}

cmd="${1:-all}"
case "${cmd}" in
  list) usage ;;
  orthology) stage_orthology ;;
  phylogeny) stage_phylogeny ;;
  wgd) stage_wgd ;;
  synteny) stage_synteny ;;
  selection) stage_selection ;;
  cafe) stage_cafe ;;
  figures) stage_figures ;;
  all) stage_all ;;
  *) usage; exit 1 ;;
esac
