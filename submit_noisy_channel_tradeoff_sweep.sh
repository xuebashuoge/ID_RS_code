#!/bin/bash
set -euo pipefail

sweep_type="${1:-e2}"
profile="server_full"

if (( $# > 0 )); then
    shift
fi
job_specs=("$@")
if (( ${#job_specs[@]} == 0 )); then
    job_specs=(id)
fi

case "${sweep_type}" in
    e2)
        config_count=4
        ;;
    ldpc_rate|rate)
        sweep_type="ldpc_rate"
        config_count=5
        ;;
    *)
        echo "Usage: $0 {e2|ldpc_rate} [func_type[=n1,n2,...] ...]" >&2
        exit 2
        ;;
esac

# Default tradeoff config: n=[4 8 16 32], AWGN, Eb/N0=0:1:10.
default_n_list="4:8:16:32"
channel_count=1
snr_count=11

func_types=()
n_lists=()
n_counts=()
for job_spec in "${job_specs[@]}"; do
    if [[ "${job_spec}" == *=* ]]; then
        func_type="${job_spec%%=*}"
        n_list="${job_spec#*=}"
        n_list="${n_list//,/:}"
    else
        func_type="${job_spec}"
        n_list="${default_n_list}"
    fi

    if [[ -z "${func_type}" || ! "${n_list}" =~ ^[0-9]+(:[0-9]+)*$ ]]; then
        echo "Invalid job specification: ${job_spec}" >&2
        echo "Expected func_type=n1,n2,... (for example id=4,8,16,32)." >&2
        exit 2
    fi

    IFS=: read -r -a n_values <<< "${n_list}"
    for n in "${n_values[@]}"; do
        if (( n < 2 || n % 2 != 0 )); then
            echo "Invalid n=${n} for ${func_type}: n must be a positive even integer." >&2
            exit 2
        fi
    done

    func_types+=("${func_type}")
    n_lists+=("${n_list}")
    n_counts+=("${#n_values[@]}")
done

mkdir -p logs
for (( job_index=0; job_index<${#func_types[@]}; job_index++ )); do
    func_type="${func_types[job_index]}"
    n_list="${n_lists[job_index]}"
    n_count="${n_counts[job_index]}"
    prepare_last=$((config_count * n_count - 1))
    simulation_last=$((config_count * n_count * channel_count * snr_count - 1))
    exports="ALL,BFC_SWEEP_TYPE=${sweep_type},BFC_SWEEP_PROFILE=${profile},BFC_FUNC_TYPE=${func_type},BFC_N_LIST=${n_list}"

    prepare_job=$(sbatch --parsable --export="${exports}" \
        --array="0-${prepare_last}%16" noisy_channel_tradeoff_prepare.slurm)
    simulation_job=$(sbatch --parsable --export="${exports}" \
        --array="0-${simulation_last}%16" \
        --dependency="afterok:${prepare_job}" noisy_channel_tradeoff_sweep.slurm)
    plot_job=$(sbatch --parsable --export="${exports}" \
        --dependency="afterok:${simulation_job}" noisy_channel_tradeoff_plot.slurm)

    echo "Sweep: ${sweep_type}; function: ${func_type}; n: ${n_list//:/,}"
    echo "Source-bank job: ${prepare_job}"
    echo "Channel sweep job: ${simulation_job}"
    echo "Plot job: ${plot_job}"
done
