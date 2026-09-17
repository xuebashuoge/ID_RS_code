#!/bin/bash
# Submit existing manifests from the repository root; failures retain checkpoints.
set -euo pipefail
export FT_OUT="$(cd "${1:?Usage: bash submit.sh RESULT_DIRECTORY}" && pwd)"
mkdir -p logs
if [[ -e "$FT_OUT/jobs.txt" ]]; then
    echo 'jobs.txt already exists; inspect existing jobs and resume only failed indices.' >&2
    exit 1
fi
count() { conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$1"; }
channel_time=02:00:00
noiseless_time=06:00:00
if grep -q '"stage": "pilot"' "$FT_OUT/design.json"; then
    channel_time=02:00:00
    noiseless_time=01:00:00
fi
git rev-parse HEAD > "$FT_OUT/source_commit.txt"
export FT_TEST_ONLY=1
smoke=$(sbatch --parsable --time=00:20:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/jobs.txt"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/banks.json"
banks=$(sbatch --parsable --dependency="afterok:${smoke%%;*}" --array="0-$(count "$FT_MANIFEST")%4" --time=02:00:00 --mem=8G --export=ALL itw2027/fixed_task/job.slurm)
printf 'banks=%s\n' "$banks" | tee -a "$FT_OUT/jobs.txt"
export FT_MANIFEST="$FT_OUT/noisy.json"
noisy=$(sbatch --parsable --dependency="afterok:${banks%%;*}" --array="0-$(count "$FT_MANIFEST")%8" --time="$channel_time" --mem=8G --export=ALL itw2027/fixed_task/job.slurm)
printf 'noisy=%s\n' "$noisy" | tee -a "$FT_OUT/jobs.txt"
export FT_MANIFEST="$FT_OUT/noiseless.json"
noiseless=$(sbatch --parsable --dependency="afterok:${smoke%%;*}" --array="0-$(count "$FT_MANIFEST")%16" --time="$noiseless_time" --cpus-per-task=2 --mem=8G --export=ALL itw2027/fixed_task/job.slurm)
printf 'noiseless=%s\n' "$noiseless" | tee -a "$FT_OUT/jobs.txt"
plots=$(sbatch --parsable --dependency="afterok:${noisy%%;*}:${noiseless%%;*}" --export=ALL itw2027/fixed_task/postprocess.slurm)
printf 'plots=%s\n' "$plots" | tee -a "$FT_OUT/jobs.txt"
