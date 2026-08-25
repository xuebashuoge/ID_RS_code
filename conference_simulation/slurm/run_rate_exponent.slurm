#!/bin/bash
#SBATCH --job-name=bfc_rate_exp
#SBATCH --output=logs/bfc_rate_exp_%j.out
#SBATCH --error=logs/bfc_rate_exp_%j.err
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:30:00

set -euo pipefail

module load MATLAB/2024b_Update_3
cd "$SLURM_SUBMIT_DIR"
matlab -batch "addpath(pwd,fullfile(pwd,'conference_simulation')); run_rate_error_exponent"
