#!/bin/bash
# New matched-length threshold run; 22 fixed 2,500-frame points.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p logs
export ITW_EXPERIMENT=threshold_nt40
bank=$(sbatch --parsable --array=0 --mem=16G --time=06:00:00 itw2027/slurm/noisy_bank.slurm)
point=$(sbatch --parsable --dependency="afterok:${bank%%;*}" --array=0-21%4 --time=14:00:00 itw2027/slurm/noisy_point.slurm)
printf 'bank_job=%s\npoint_array=%s\n' "$bank" "$point"
