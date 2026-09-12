#!/bin/bash
#SBATCH --job-name=ITW27_figures
#SBATCH --output=logs/itw27_figures_%j.out
#SBATCH --error=logs/itw27_figures_%j.err
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:15:00
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from the repository root}"
export MPLCONFIGDIR="${TMPDIR:-/tmp}/itw27-matplotlib-${SLURM_JOB_ID}"
conda run --no-capture-output -n torch28 python itw2027/scripts/test_rates.py
conda run --no-capture-output -n torch28 python itw2027/scripts/build_results.py
