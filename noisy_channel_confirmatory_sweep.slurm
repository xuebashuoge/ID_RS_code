#!/bin/bash
#SBATCH --job-name=BFC_conf
#SBATCH --output=logs/conf_%A_%a.out
#SBATCH --error=logs/conf_%A_%a.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00

set -euo pipefail
mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_noisy_channel_confirmatory_array_task"

if command -v my-job-stats >/dev/null 2>&1; then
    my-job-stats -a -n -s
fi
