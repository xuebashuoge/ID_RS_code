#!/bin/bash
set -euo pipefail

mkdir -p logs
# 5 rates x 2 algorithms x 13 SNR points = 130 array tasks.
simulation_job=$(sbatch --parsable --array="0-129%16" \
    ldpc_awgn_calibration_sweep.slurm)
plot_job=$(sbatch --parsable --dependency="afterok:${simulation_job}" \
    ldpc_awgn_calibration_plot.slurm)

echo "LDPC calibration job: ${simulation_job}"
echo "Calibration plot job: ${plot_job}"
