#!/bin/bash
#SBATCH --job-name=ITW27_exact
#SBATCH --output=logs/itw27_exact_%A_%a.out
#SBATCH --error=logs/itw27_exact_%A_%a.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --time=12:00:00
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from repository root}"
module load "${ITW_MATLAB_MODULE:-MATLAB/2024b_Update_3}"
export BFC_RESULTS_ROOT="${BFC_RESULTS_ROOT:-$PWD/itw2027/results/source/noiseless}"
export BFC_NUM_WORKERS="$SLURM_CPUS_PER_TASK"
# MATLAB threads in each parallel task must not launch another full BLAS pool.
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
matlab -batch "addpath('conference_simulation'); run_conference_finite_length;"
if command -v my-job-stats >/dev/null 2>&1; then my-job-stats -a -n -s; fi
