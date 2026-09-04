#!/bin/bash
#SBATCH --job-name=BFC_paper
#SBATCH --output=logs/bfc_paper_%j.out
#SBATCH --error=logs/bfc_paper_%j.err
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=01:00:00

set -euo pipefail
mkdir -p logs
module load MATLAB/2024b_Update_3
matlab -batch "run_compile_noisy_channel_publication_task"
