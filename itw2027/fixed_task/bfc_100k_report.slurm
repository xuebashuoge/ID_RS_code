#!/bin/bash
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=logs/itw_bfc_100k_report_%j.out
#SBATCH --error=logs/itw_bfc_100k_report_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load Anaconda3
conda run -p /data/gpfs/projects/punim2792/anaconda3/envs/torch28 python itw2027/fixed_task/bfc_100k.py summarize --out "${FT_OUT:?}"
