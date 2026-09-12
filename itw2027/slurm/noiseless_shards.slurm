#!/bin/bash
#SBATCH --job-name=ITW27_shard
#SBATCH --output=logs/itw27_shard_%A_%a.out
#SBATCH --error=logs/itw27_shard_%A_%a.err
#SBATCH --cpus-per-task=32
#SBATCH --mem=32G
#SBATCH --time=36:00:00
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?Submit from repository root}"
i=${SLURM_ARRAY_TASK_ID:?}
export BFC_FUNC_TYPE=id
if ((i<10)); then export BFC_N=34 BFC_NUM_MESSAGES=200 BFC_SHARD_INDEX=$i
elif ((i<30)); then export BFC_N=36 BFC_NUM_MESSAGES=100 BFC_SHARD_INDEX=$((i-10))
elif ((i<38)); then export BFC_N=38 BFC_NUM_MESSAGES=25 BFC_SHARD_INDEX=$((i-30))
elif ((i<46)); then export BFC_N=40 BFC_NUM_MESSAGES=25 BFC_SHARD_INDEX=$((i-38))
elif ((i<56)); then export BFC_FUNC_TYPE=rank BFC_N=38 BFC_NUM_MESSAGES=200 BFC_SHARD_INDEX=$((i-46))
elif ((i<66)); then export BFC_FUNC_TYPE=rank BFC_N=40 BFC_NUM_MESSAGES=200 BFC_SHARD_INDEX=$((i-56))
else exit 2; fi
# The runner's array index is only used before the explicit family/n overrides.
export BFC_ARRAY_INDEX=0
bash itw2027/slurm/noiseless.slurm
