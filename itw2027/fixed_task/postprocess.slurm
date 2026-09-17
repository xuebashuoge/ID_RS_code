#!/bin/bash
#SBATCH --job-name=itw_fixed_plots
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=logs/itw_fixed_plots_%j.out
#SBATCH --error=logs/itw_fixed_plots_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load Anaconda3
export MPLCONFIGDIR="${FT_OUT:?}/.matplotlib"
conda run -n torch28 python itw2027/fixed_task/campaign.py summarize --out "$FT_OUT"
