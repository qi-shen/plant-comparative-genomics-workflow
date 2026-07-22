#!/usr/bin/env bash
# 13 — Run OrthoFinder on prepared proteomes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../lib/common.sh"
wf_init

PROTEOMES="${COMPARATIVE_DIR}/01_proteomes"
# Prefer filtered/ if present
if [[ -d "${PROTEOMES}/filtered" ]] && compgen -G "${PROTEOMES}/filtered/*.fa" >/dev/null; then
  PROTEOMES="${PROTEOMES}/filtered"
fi
OUTDIR="${COMPARATIVE_DIR}/02_orthofinder_results"
THREADS="${THREADS:-120}"
LOGFILE="${LOGS_DIR}/orthofinder_$(date +%Y%m%d_%H%M%S).log"
ORTHOFINDER="${ORTHOFINDER:-orthofinder}"

wf_log "=========================================="
wf_log "OrthoFinder"
wf_log "proteomes: ${PROTEOMES}"
wf_log "outdir:    ${OUTDIR}"
wf_log "threads:   ${THREADS}"
wf_log "=========================================="

wf_require_dir "${PROTEOMES}"
wf_activate_conda "${CONDA_ENV}"

if [[ -d "${OUTDIR}" ]]; then
  wf_log "WARN: removing existing ${OUTDIR}"
  rm -rf "${OUTDIR}"
fi

if command -v "${ORTHOFINDER}" >/dev/null 2>&1; then
  OF_CMD=("${ORTHOFINDER}")
elif [[ -n "${ORTHOFINDER_PY:-}" ]]; then
  OF_CMD=(python "${ORTHOFINDER_PY}")
else
  # fallback common names
  if command -v orthofinder.py >/dev/null 2>&1; then
    OF_CMD=(orthofinder.py)
  else
    wf_die "OrthoFinder not found. Set ORTHOFINDER or ORTHOFINDER_PY in .project_env"
  fi
fi

"${OF_CMD[@]}" \
  -f "${PROTEOMES}" \
  -t "${THREADS}" \
  -a "${OF_ANAL_THREADS:-64}" \
  -S diamond \
  -M msa \
  -o "${OUTDIR}" \
  2>&1 | tee -a "${LOGFILE}"

RESULTS_DIR="$(ls -td "${OUTDIR}"/Results_* 2>/dev/null | head -1 || true)"
if [[ -n "${RESULTS_DIR}" && -d "${RESULTS_DIR}" ]]; then
  wf_log "Results: ${RESULTS_DIR}"
  if [[ -d "${RESULTS_DIR}/Single_Copy_Orthologue_Sequences" ]]; then
    sc="$(ls "${RESULTS_DIR}/Single_Copy_Orthologue_Sequences"/*.fa 2>/dev/null | wc -l)"
    wf_log "Single-copy OGs: ${sc}"
  fi
fi

wf_log "OrthoFinder finished at $(date)"
