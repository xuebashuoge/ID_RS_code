#!/bin/bash
set -euo pipefail

mkdir -p logs
prepare_job=$(sbatch --parsable noisy_channel_prepare.slurm)
simulation_job=$(sbatch --parsable --dependency="afterok:${prepare_job}" noisy_channel_sweep.slurm)
plot_job=$(sbatch --parsable --dependency="afterok:${simulation_job}" noisy_channel_plot.slurm)

echo "Source-bank job: ${prepare_job}"
echo "Channel sweep job: ${simulation_job}"
echo "Plot job: ${plot_job}"
