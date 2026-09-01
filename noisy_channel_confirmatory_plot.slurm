#!/bin/bash
#SBATCH --job-name=BFC_BP_plot
#SBATCH --output=logs/bp_plot_%j.out
#SBATCH --error=logs/bp_plot_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=01:00:00

set -euo pipefail
mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_plot_noisy_channel_confirmatory_task"
