#!/bin/bash
set -euo pipefail

sweep_type="${1:-e2}"
func_type="${2:-id}"
profile="server_full"

case "${sweep_type}" in
    e2)
        config_count=4
        ;;
    ldpc_rate|rate)
        sweep_type="ldpc_rate"
        config_count=5
        ;;
    *)
        echo "Usage: $0 {e2|ldpc_rate} [func_type]" >&2
        exit 2
        ;;
esac

# Default tradeoff config: n=[4 6 8], AWGN, Eb/N0=0:1:10.
n_count=4
channel_count=1
snr_count=11
prepare_last=$((config_count * n_count - 1))
simulation_last=$((config_count * n_count * channel_count * snr_count - 1))
exports="ALL,BFC_SWEEP_TYPE=${sweep_type},BFC_SWEEP_PROFILE=${profile},BFC_FUNC_TYPE=${func_type}"

mkdir -p logs
prepare_job=$(sbatch --parsable --export="${exports}" \
    --array="0-${prepare_last}%8" noisy_channel_tradeoff_prepare.slurm)
simulation_job=$(sbatch --parsable --export="${exports}" \
    --array="0-${simulation_last}%8" \
    --dependency="afterok:${prepare_job}" noisy_channel_tradeoff_sweep.slurm)
plot_job=$(sbatch --parsable --export="${exports}" \
    --dependency="afterok:${simulation_job}" noisy_channel_tradeoff_plot.slurm)

echo "Sweep: ${sweep_type}; function: ${func_type}"
echo "Source-bank job: ${prepare_job}"
echo "Channel sweep job: ${simulation_job}"
echo "Plot job: ${plot_job}"
