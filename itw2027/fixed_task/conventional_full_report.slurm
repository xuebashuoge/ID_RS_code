#!/bin/bash
#SBATCH --job-name=itw_fer_report
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=logs/itw_fer_report_%j.out
#SBATCH --error=logs/itw_fer_report_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load Anaconda3
conda run -n torch28 python itw2027/fixed_task/conventional_full.py summarize --out "${FT_OUT:?}"
