#!/bin/bash
set -euo pipefail

mkdir -p logs

# Workload classes use the task/n mapping documented in README.md.
# Fast: ID n=24:28, rank n=24:32, and every exact-threshold cell.
finite_fast_job=$(sbatch --parsable \
    --array="0-2,9-13,18-26%1" \
    --time="1-00:00:00" \
    conference_simulation/slurm/run_finite_length_array.slurm)

# Medium: ID n=30:34 and rank n=34:36.
finite_medium_job=$(sbatch --parsable \
    --dependency="afterok:${finite_fast_job}" \
    --array="3-5,14-15%1" \
    --time="2-00:00:00" \
    conference_simulation/slurm/run_finite_length_array.slurm)

# Slow: ID n=36:40 and rank n=38:40.
finite_slow_job=$(sbatch --parsable \
    --dependency="afterok:${finite_medium_job}" \
    --array="6-8,16-17%1" \
    --time="3-00:00:00" \
    conference_simulation/slurm/run_finite_length_array.slurm)

# Run adversarial validation only after the finite-length arrays release the
# whole node. Cost guards still skip cases beyond the configured safe limits.
adversarial_job=$(sbatch --parsable \
    --dependency="afterok:${finite_slow_job}" \
    conference_simulation/slurm/run_adversarial_array.slurm)
rate_job=$(sbatch --parsable conference_simulation/slurm/run_rate_exponent.slurm)

postprocess_job=$(sbatch --parsable \
    --dependency="afterok:${adversarial_job}:${rate_job}" \
    conference_simulation/slurm/run_postprocess.slurm)

echo "finite fast (24 h):    ${finite_fast_job}"
echo "finite medium (48 h):  ${finite_medium_job}"
echo "finite slow (72 h):    ${finite_slow_job}"
echo "adversarial (24 h):    ${adversarial_job}"
echo "rate/exponent (30 m):  ${rate_job}"
echo "post-processing (2 h): ${postprocess_job}"
