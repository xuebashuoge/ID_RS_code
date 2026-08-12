#!/bin/bash
#SBATCH --job-name=BFC_trade_plot
#SBATCH --output=logs/trade_plot_%j.out
#SBATCH --error=logs/trade_plot_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00

module load MATLAB/2024b_Update_3
matlab -batch "run_plot_noisy_channel_tradeoff_task"
