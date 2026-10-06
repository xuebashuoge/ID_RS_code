#!/bin/bash
#SBATCH --output=logs/itw_bfc_100k_test_%j.out
#SBATCH --error=logs/itw_bfc_100k_test_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load "${ITW_MATLAB_MODULE:-MATLAB/2024b_Update_3}"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
matlab -batch "addpath('itw2027/fixed_task'); test_bfc_100k;"
