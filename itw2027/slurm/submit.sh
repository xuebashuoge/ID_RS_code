#!/bin/bash
# Default: rebuild the paper artifacts from the committed compact evidence.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p logs
case "${1:-figures}" in
  figures) sbatch itw2027/slurm/postprocess.slurm ;;
  noisy)
    export ITW_EXPERIMENT="${2:-waterfall}"
    case "$ITW_EXPERIMENT" in waterfall) last=65;; rate_pareto) last=59;; *) exit 2;; esac
    # Copies/reused completed points are validated and skipped. Each source
    # bank is a separate job; no hidden preparation inside 8-GB point jobs.
    bank=$(sbatch --parsable --array=0-2%1 itw2027/slurm/noisy_bank.slurm)
    point=$(sbatch --parsable --dependency="afterok:${bank%%;*}" --array="0-${last}%4" itw2027/slurm/noisy_point.slurm)
    exportjob=$(sbatch --parsable --dependency="afterok:${point%%;*}" itw2027/slurm/export.slurm)
    sbatch --dependency="afterok:${exportjob%%;*}" itw2027/slurm/postprocess.slurm ;;
  noiseless)
    # Full regeneration is OPTIONAL. Completed source results are skipped.
    # n>=34 ID is split into more, shorter independent message shards. This
    # changes samples vs archived runs; use a fresh directory for regeneration.
    export BFC_RESULTS_ROOT="${BFC_RESULTS_ROOT:-$PWD/itw2027/results/rerun_noiseless}"
    mkdir -p "$BFC_RESULTS_ROOT"
    sbatch --array=0-3,9-14,18-26%2 --cpus-per-task=16 --mem=16G --time=12:00:00 itw2027/slurm/noiseless.slurm
    sbatch --array=4,15%2 --time=24:00:00 itw2027/slurm/noiseless.slurm
    sbatch --array=0-29,46-65%2 --time=12:00:00 itw2027/slurm/noiseless_shards.slurm
    sbatch --array=30-45%2 --time=36:00:00 itw2027/slurm/noiseless_shards.slurm
    echo 'Regeneration submitted. Review job logs and use the import instructions before rebuilding evidence.' ;;
  *) echo 'Usage: submit.sh [figures|noisy [waterfall|rate_pareto]|noiseless]' >&2; exit 2 ;;
esac
