#!/bin/bash
#SBATCH --job-name=itw_task_report
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=logs/itw_task_report_%j.out
#SBATCH --error=logs/itw_task_report_%j.err
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
module load Anaconda3
conda run -n torch28 python itw2027/fixed_task/task_comparison.py summarize --out "${FT_OUT:?}"
conda run -n torch28 python itw2027/fixed_task/plot_noiseless_noisy_results_nt60_three_panels.py \
    --task-comparison "$FT_OUT" --out "$FT_OUT/figures"
