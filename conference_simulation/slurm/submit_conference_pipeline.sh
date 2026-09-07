#!/bin/bash
set -euo pipefail

# Resolve the repository root from this script so it can be launched from any
# current directory on a SLURM login node.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "${script_dir}/../.." && pwd)
cd "${repo_root}"

if ! command -v sbatch >/dev/null 2>&1; then
    echo "Error: sbatch is unavailable. Run this script on a SLURM login node." >&2
    exit 1
fi

finite_script="conference_simulation/slurm/run_finite_length_array.slurm"
adversarial_script="conference_simulation/slurm/run_adversarial_array.slurm"
rate_script="conference_simulation/slurm/run_rate_exponent.slurm"
postprocess_script="conference_simulation/slurm/run_postprocess.slurm"

for required_file in \
    "${finite_script}" \
    "${adversarial_script}" \
    "${rate_script}" \
    "${postprocess_script}"; do
    if [[ ! -f "${required_file}" ]]; then
        echo "Error: required file not found: ${required_file}" >&2
        exit 1
    fi
done

# Large-ID defaults. Override these environment variables before launching
# this script if more shards are wanted. Four shards x 50 messages gives 200
# sampled negative messages for ID n=38 and n=40.
id_shard_count=${BFC_ID_SHARD_COUNT:-4}
id_messages_per_shard=${BFC_ID_MESSAGES_PER_SHARD:-50}

if ! [[ "${id_shard_count}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: BFC_ID_SHARD_COUNT must be a positive integer." >&2
    exit 1
fi
if ! [[ "${id_messages_per_shard}" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: BFC_ID_MESSAGES_PER_SHARD must be a positive integer." >&2
    exit 1
fi

mkdir -p logs

# Fast: ID n=24:28, rank n=24:32, and every exact-threshold cell.
finite_fast_job=$(sbatch --parsable \
    --array="0-2,9-13,18-26%1" \
    --time="1-00:00:00" \
    "${finite_script}")

# Medium: ID n=30:34 and rank n=34:36.
finite_medium_job=$(sbatch --parsable \
    --dependency="afterok:${finite_fast_job}" \
    --array="3-5,14-15%1" \
    --time="2-00:00:00" \
    "${finite_script}")

# Slow unsharded cells: ID n=36 and rank n=38:40.
finite_slow_job=$(sbatch --parsable \
    --dependency="afterok:${finite_medium_job}" \
    --array="6,16-17%1" \
    --time="3-00:00:00" \
    "${finite_script}")

# ID n=38 (task 7) and n=40 (task 8) are submitted as independent message
# shards. Distinct shard indices produce distinct seeds and result files.
id_shard_jobs=()
for task_index in 7 8; do
    for ((shard_index = 0; shard_index < id_shard_count; shard_index++)); do
        shard_job=$(sbatch --parsable \
            --dependency="afterok:${finite_medium_job}" \
            --array="${task_index}" \
            --time="2-00:00:00" \
            --cpus-per-task=32 \
            --mem=64G \
            --export="ALL,BFC_NUM_MESSAGES=${id_messages_per_shard},BFC_SHARD_INDEX=${shard_index},BFC_CHECKPOINT_EVERY=5" \
            "${finite_script}")
        id_shard_jobs+=("${shard_job}")
    done
done

# Every shard must complete successfully before adversarial validation starts.
# Post-processing later concatenates shard files by task and n.
id_shard_dependency=$(IFS=:; echo "${id_shard_jobs[*]}")

adversarial_job=$(sbatch --parsable \
    --dependency="afterok:${finite_slow_job}:${id_shard_dependency}" \
    "${adversarial_script}")

# This deterministic job is independent of the long finite-length chain.
rate_job=$(sbatch --parsable "${rate_script}")

postprocess_job=$(sbatch --parsable \
    --dependency="afterok:${adversarial_job}:${rate_job}" \
    "${postprocess_script}")

echo "Submitted conference simulation pipeline from: ${repo_root}"
echo "finite fast (24 h):       ${finite_fast_job}"
echo "finite medium (48 h):     ${finite_medium_job}"
echo "finite slow (72 h):       ${finite_slow_job}"
echo "ID n=38/40 shard jobs:    ${id_shard_jobs[*]}"
echo "messages per large ID n:  $((id_shard_count * id_messages_per_shard))"
echo "adversarial (24 h):       ${adversarial_job}"
echo "rate/exponent (30 m):     ${rate_job}"
echo "post-processing (2 h):    ${postprocess_job}"
