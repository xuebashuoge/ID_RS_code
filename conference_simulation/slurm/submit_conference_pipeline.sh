#!/bin/bash
set -euo pipefail

mkdir -p logs

finite_job=$(sbatch --parsable conference_simulation/slurm/run_finite_length_array.slurm)
adversarial_job=$(sbatch --parsable conference_simulation/slurm/run_adversarial_array.slurm)
rate_job=$(sbatch --parsable conference_simulation/slurm/run_rate_exponent.slurm)

postprocess_job=$(sbatch --parsable \
    --dependency="afterok:${finite_job}:${adversarial_job}:${rate_job}" \
    conference_simulation/slurm/run_postprocess.slurm)

echo "finite-length array: ${finite_job}"
echo "adversarial array:   ${adversarial_job}"
echo "rate/exponent:       ${rate_job}"
echo "post-processing:     ${postprocess_job}"
