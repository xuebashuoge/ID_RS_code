#!/bin/bash
#SBATCH --job-name=LDPC_cal_plot
#SBATCH --output=logs/ldpc_cal_plot_%j.out
#SBATCH --error=logs/ldpc_cal_plot_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=01:00:00

set -euo pipefail
mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_plot_ldpc_awgn_calibration_task"
