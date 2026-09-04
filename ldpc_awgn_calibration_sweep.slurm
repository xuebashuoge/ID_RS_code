#!/bin/bash
#SBATCH --job-name=LDPC_cal
#SBATCH --output=logs/ldpc_cal_%A_%a.out
#SBATCH --error=logs/ldpc_cal_%A_%a.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=04:00:00

set -euo pipefail
mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_ldpc_awgn_calibration_array_task"

if command -v my-job-stats >/dev/null 2>&1; then
    my-job-stats -a -n -s
fi
