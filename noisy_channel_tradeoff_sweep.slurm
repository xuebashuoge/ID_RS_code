#!/bin/bash
#SBATCH --job-name=BFC_trade
#SBATCH --output=logs/trade_%A_%a.out
#SBATCH --error=logs/trade_%A_%a.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=72:00:00

module load MATLAB/2024b_Update_3
matlab -batch "run_noisy_channel_tradeoff_array_task"

if command -v my-job-stats >/dev/null 2>&1; then
    my-job-stats -a -n -s
fi