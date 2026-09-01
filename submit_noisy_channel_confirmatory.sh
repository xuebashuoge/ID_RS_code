#!/bin/bash
set -euo pipefail

experiment="${1:-waterfall}"
case "${experiment}" in
    waterfall)
        bank_count=3
        point_count=66
        ;;
    rate_pareto|rate-pareto)
        experiment="rate_pareto"
        bank_count=3
        point_count=60
        ;;
    *)
        echo "Usage: $0 {waterfall|rate_pareto}" >&2
        exit 2
        ;;
esac

mkdir -p logs
exports="ALL,BFC_CONFIRMATORY_EXPERIMENT=${experiment}"
bank_last=$((bank_count-1))
point_last=$((point_count-1))
prepare_job=$(sbatch --parsable --export="${exports}" \
    --array="0-${bank_last}%3" noisy_channel_confirmatory_prepare.slurm)
simulation_job=$(sbatch --parsable --export="${exports}" \
    --array="0-${point_last}%8" --dependency="afterok:${prepare_job}" \
    noisy_channel_confirmatory_sweep.slurm)
plot_job=$(sbatch --parsable --export="${exports}" \
    --dependency="afterok:${simulation_job}" \
    noisy_channel_confirmatory_plot.slurm)

echo "Confirmatory experiment: ${experiment}"
echo "Decoder: belief propagation; fixed frames per point: 2500"
echo "Output root: results/noisy_channel_confirmatory_bp/${experiment}"
echo "Source-bank job: ${prepare_job}"
echo "Fixed-sample sweep job: ${simulation_job}"
echo "Plot job: ${plot_job}"
