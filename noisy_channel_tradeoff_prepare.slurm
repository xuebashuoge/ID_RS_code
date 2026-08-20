#!/bin/bash
#SBATCH --job-name=BFC_trade_bank
#SBATCH --output=logs/trade_bank_%A_%a.out
#SBATCH --error=logs/trade_bank_%A_%a.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=24:00:00

module load MATLAB/2024b_Update_3
matlab -batch "run_prepare_tradeoff_bank_task"

if command -v my-job-stats >/dev/null 2>&1; then
    my-job-stats -a -n -s
fi