#!/bin/bash
#SBATCH --job-name=itw_fixed
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --output=logs/itw_fixed_%A_%a.out
#SBATCH --error=logs/itw_fixed_%A_%a.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load "${ITW_MATLAB_MODULE:-MATLAB/2024b_Update_3}"
export OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK"
export MKL_NUM_THREADS="$SLURM_CPUS_PER_TASK"
if [[ "${FT_TEST_ONLY:-0}" == 60 ]]; then
    matlab -batch "addpath('itw2027/fixed_task'); test_noisy_nt60;"
    exit 0
fi
if [[ "${FT_TEST_ONLY:-0}" == 1 ]]; then
    matlab -batch "addpath('itw2027/fixed_task'); test_fixed_task;"
    exit 0
fi
matlab -batch "addpath('itw2027/fixed_task'); ft_run(getenv('FT_MANIFEST'),str2double(getenv('SLURM_ARRAY_TASK_ID')),getenv('FT_OUT'));"
if command -v my-job-stats >/dev/null 2>&1; then my-job-stats -a -n -s; fi
