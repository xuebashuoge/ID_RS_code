#!/bin/bash
#SBATCH --job-name=BFC_replot
#SBATCH --output=logs/replot_%j.out
#SBATCH --error=logs/replot_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00

set -euo pipefail

mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_replot_noisy_channel_tradeoff_task"
