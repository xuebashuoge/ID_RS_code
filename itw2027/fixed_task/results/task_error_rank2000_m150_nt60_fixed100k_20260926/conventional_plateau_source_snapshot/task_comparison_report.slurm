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
manifest=tasks.json
if [[ -f "${FT_OUT:?}/report_tasks.json" ]]; then manifest=report_tasks.json; fi
if [[ -f "$FT_OUT/grid01_tasks.json" ]]; then manifest=grid01_tasks.json; fi
if [[ -f "$FT_OUT/full_grid_tasks.json" ]]; then manifest=full_grid_tasks.json; fi
conda run -n torch28 python itw2027/fixed_task/task_comparison.py summarize --out "$FT_OUT" --manifest "$manifest"
