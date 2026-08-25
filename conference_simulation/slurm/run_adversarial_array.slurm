#!/bin/bash
#SBATCH --job-name=bfc_adversarial
#SBATCH --output=logs/bfc_adversarial_%A_%a.out
#SBATCH --error=logs/bfc_adversarial_%A_%a.err
#SBATCH --array=0-26%2
#SBATCH --cpus-per-task=64
#SBATCH --mem=1024G
#SBATCH --time=7-00:00:00

set -euo pipefail

module load MATLAB/2024b_Update_3
cd "$SLURM_SUBMIT_DIR"

export BFC_ARRAY_INDEX="$SLURM_ARRAY_TASK_ID"
export BFC_NUM_WORKERS="$SLURM_CPUS_PER_TASK"
export MATLAB_LOG_DIR="${SLURM_TMPDIR:-/tmp/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}}"
mkdir -p "$MATLAB_LOG_DIR"
export MATLAB_PREFDIR="$MATLAB_LOG_DIR/preferences"
mkdir -p "$MATLAB_PREFDIR"

# The defaults guard exceptionally expensive cases. To force the entire
# configured grid, submit with suitable overrides, for example:
#   sbatch --export=ALL,BFC_ADVERSARIAL_MAX_K=70000,BFC_ADVERSARIAL_MAX_PROXY=2e11 ...
matlab -batch "addpath(pwd,fullfile(pwd,'conference_simulation')); run_adversarial_tightness"

if command -v my-job-stats >/dev/null 2>&1; then
    my-job-stats -a -n -s
fi
