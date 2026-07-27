#!/bin/bash
#SBATCH --job-name=BFC_bank
#SBATCH --output=logs/bank_%A_%a.out
#SBATCH --error=logs/bank_%A_%a.err
#SBATCH --array=0-3%4
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=72:00:00

module load MATLAB/2024b_Update_3
matlab -batch "run_prepare_source_bank_task"
