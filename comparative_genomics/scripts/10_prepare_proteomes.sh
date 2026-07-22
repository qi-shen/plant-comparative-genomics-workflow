#!/usr/bin/env bash
# 10 — Prepare proteomes from config/species.csv
# Reads pep_path for each sample; writes COMPARATIVE_DIR/01_proteomes/<ID>.fa

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

OUTDIR="${COMPARATIVE_DIR}/01_proteomes"
mkdir -p "${OUTDIR}"

wf_log "=========================================="
wf_log "Prepare proteomes"
wf_log "PROJECT_ROOT=${PROJECT_ROOT}"
wf_log "SPECIES_CSV=${SPECIES_CSV}"
wf_log "OUTDIR=${OUTDIR}"
wf_log "=========================================="

wf_require_file "${SPECIES_CSV}"

STATS="${OUTDIR}/proteome_stats.tsv"
echo -e "id\trole\tsequences\tsize" > "${STATS}"

while IFS= read -r sid; do
  [[ -z "${sid}" ]] && continue
  role="$(wf_species_field "${sid}" role)"
  src_rel="$(wf_species_field "${sid}" pep_path)"
  src="$(wf_abs "${src_rel}")"
  dst="${OUTDIR}/${sid}.fa"

  wf_log "Processing ${sid} (${role}) <- ${src_rel}"
  if [[ ! -f "${src}" ]]; then
    wf_log "  WARN: missing ${src}"
    continue
  fi

  awk -v sp="${sid}" '
    /^>/{gsub(/^>/, ">" sp "_"); print; next}
    {gsub(/\./, ""); gsub(/\*/, ""); print}
  ' "${src}" > "${dst}"

  count="$(grep -c '^>' "${dst}" || true)"
  size="$(ls -lh "${dst}" | awk '{print $5}')"
  echo -e "${sid}\t${role}\t${count}\t${size}" >> "${STATS}"
  wf_log "  sequences: ${count}"
done < <(wf_species_ids)

wf_log "Done. Stats: ${STATS}"
cat "${STATS}"
