#!/bin/bash
#SBATCH --job-name=BFC_BP_bank
#SBATCH --output=logs/bp_bank_%A_%a.out
#SBATCH --error=logs/bp_bank_%A_%a.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=18:00:00

set -euo pipefail
mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_prepare_confirmatory_bank_task"

if command -v my-job-stats >/dev/null 2>&1; then
    my-job-stats -a -n -s
fi
