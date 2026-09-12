#!/bin/bash
#SBATCH --job-name=ITW27_export
#SBATCH --output=logs/itw27_export_%j.out
#SBATCH --error=logs/itw27_export_%j.err
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:15:00
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from repository root}"
module load "${ITW_MATLAB_MODULE:-MATLAB/2024b_Update_3}"
matlab -batch "addpath('itw2027/matlab'); export_evidence;"
