#!/usr/bin/env bash
# Shared helpers for workflow scripts.
# Usage: source "${PROJECT_ROOT}/lib/common.sh"   (or auto-detect below)

set -euo pipefail

_wf_detect_root() {
  if [[ -n "${PROJECT_ROOT:-}" && -d "${PROJECT_ROOT}" ]]; then
    printf '%s' "${PROJECT_ROOT}"
    return
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
  # scripts live in comparative_genomics/scripts or annotation/scripts
  if [[ -f "${here}/../../.project_env.example" || -f "${here}/../../config/species.csv" ]]; then
    cd "${here}/../.." && pwd
    return
  fi
  if [[ -f "${here}/../.project_env.example" || -f "${here}/../config/species.csv" ]]; then
    cd "${here}/.." && pwd
    return
  fi
  pwd
}

wf_init() {
  PROJECT_ROOT="$(_wf_detect_root)"
  export PROJECT_ROOT
  cd "${PROJECT_ROOT}"

  if [[ -f "${PROJECT_ROOT}/.project_env" ]]; then
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/.project_env"
  fi

  export RESULTS_DIR="${RESULTS_DIR:-${PROJECT_ROOT}/old_reults/results}"
  export ANNOTATION_DIR="${ANNOTATION_DIR:-${PROJECT_ROOT}/old_reults/annotation}"
  export COMPARATIVE_DIR="${COMPARATIVE_DIR:-${PROJECT_ROOT}/comparative_genomics}"
  export SCRIPTS_DIR="${SCRIPTS_DIR:-${PROJECT_ROOT}/annotation/scripts}"
  export CG_SCRIPTS_DIR="${CG_SCRIPTS_DIR:-${COMPARATIVE_DIR}/scripts}"
  export LOGS_DIR="${LOGS_DIR:-${COMPARATIVE_DIR}/logs}"
  export CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/config}"
  export SPECIES_CSV="${SPECIES_CSV:-${CONFIG_DIR}/species.csv}"
  export THREADS="${THREADS:-8}"
  export CONDA_ENV="${CONDA_ENV:-comparative}"

  mkdir -p "${LOGS_DIR}"
}

wf_log() {
  echo "[$(date '+%F %T')] $*"
}

wf_die() {
  echo "[ERROR] $*" >&2
  exit 1
}

wf_require_file() {
  [[ -f "$1" ]] || wf_die "missing file: $1"
}

wf_require_dir() {
  [[ -d "$1" ]] || wf_die "missing directory: $1"
}

wf_activate_conda() {
  local env_name="${1:-${CONDA_ENV}}"
  if ! command -v conda >/dev/null 2>&1; then
    wf_die "conda not found in PATH"
  fi
  # shellcheck disable=SC1091
  source "$(conda info --base)/etc/profile.d/conda.sh"
  conda activate "${env_name}"
  export PYTHONNOUSERSITE=1
}

# Read a column from config/species.csv by id.
# Usage: wf_species_field T01 pep_path
wf_species_field() {
  local sid="$1" field="$2"
  python3 - "${SPECIES_CSV}" "${sid}" "${field}" <<'PY'
import csv, sys
path, sid, field = sys.argv[1:4]
with open(path, newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f))
for r in rows:
    if r.get("id") == sid or r.get("prefix") == sid:
        print(r.get(field, ""))
        sys.exit(0)
sys.exit(f"species id not found: {sid}")
PY
}

wf_species_ids() {
  python3 - "${SPECIES_CSV}" <<'PY'
import csv, sys
with open(sys.argv[1], newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        print(r["id"])
PY
}

wf_abs() {
  # resolve path relative to PROJECT_ROOT
  local p="$1"
  if [[ "${p}" = /* ]]; then
    printf '%s' "${p}"
  else
    printf '%s' "${PROJECT_ROOT}/${p}"
  fi
}
