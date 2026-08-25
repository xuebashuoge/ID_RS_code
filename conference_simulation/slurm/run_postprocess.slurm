#!/bin/bash
#SBATCH --job-name=bfc_postprocess
#SBATCH --output=logs/bfc_postprocess_%j.out
#SBATCH --error=logs/bfc_postprocess_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=02:00:00

set -euo pipefail

module load MATLAB/2024b_Update_3
cd "$SLURM_SUBMIT_DIR"
matlab -batch "addpath(pwd,fullfile(pwd,'conference_simulation')); compile_conference_results"
