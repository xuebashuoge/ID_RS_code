#!/bin/bash
#SBATCH --job-name=BFC_LDPC
#SBATCH --output=logs/noisy_%A_%a.out
#SBATCH --error=logs/noisy_%A_%a.err
#SBATCH --array=0-87%8
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=72:00:00

module load MATLAB/2024b_Update_3
matlab -batch "run_noisy_channel_array_task"
