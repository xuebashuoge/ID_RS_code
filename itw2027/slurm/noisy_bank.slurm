#!/bin/bash
#SBATCH --job-name=ITW27_bank
#SBATCH --output=logs/itw27_bank_%A_%a.out
#SBATCH --error=logs/itw27_bank_%A_%a.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=14:00:00
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from repository root}"
module load "${ITW_MATLAB_MODULE:-MATLAB/2024b_Update_3}"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
export MKL_NUM_THREADS="$SLURM_CPUS_PER_TASK"
matlab -batch "addpath('itw2027/matlab'); run_itw_noisy('bank',getenv('ITW_EXPERIMENT'));"
if command -v my-job-stats >/dev/null 2>&1; then my-job-stats -a -n -s; fi
