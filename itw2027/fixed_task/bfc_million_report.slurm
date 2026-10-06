#!/bin/bash
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=logs/itw_bfc_million_report_%j.out
#SBATCH --error=logs/itw_bfc_million_report_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load Anaconda3
conda run -n torch28 python itw2027/fixed_task/bfc_million.py summarize --out "${FT_OUT:?}"
