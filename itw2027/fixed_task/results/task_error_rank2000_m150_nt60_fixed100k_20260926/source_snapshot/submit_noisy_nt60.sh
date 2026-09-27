#!/bin/bash
set -euo pipefail
export FT_OUT="$(cd "${1:?Supply the n_t_60 results directory}" && pwd)"
mkdir -p logs
test ! -e "$FT_OUT/jobs_n_t_60.txt"
test -f "$FT_OUT/design_n_t_60.json"
count() { conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$1"; }
git rev-parse HEAD > "$FT_OUT/source_commit_n_t_60.txt"
export FT_TEST_ONLY=60
smoke=$(sbatch --parsable --job-name=itw_test_nt60 --cpus-per-task=2 --mem=4G --time=00:20:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/jobs_n_t_60.txt"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/banks_n_t_60.json"
banks=$(sbatch --parsable --job-name=itw_bank_nt60 --dependency="afterok:${smoke%%;*}" --array="0-$(count "$FT_MANIFEST")%12" --cpus-per-task=8 --mem=4G --time=02:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'banks=%s\n' "$banks" | tee -a "$FT_OUT/jobs_n_t_60.txt"
export FT_MANIFEST="$FT_OUT/noisy_n_t_60.json"
noisy=$(sbatch --parsable --job-name=itw_noisy_nt60 --dependency="afterok:${banks%%;*}" --array="0-$(count "$FT_MANIFEST")%32" --cpus-per-task=8 --mem=4G --time=01:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'noisy=%s\n' "$noisy" | tee -a "$FT_OUT/jobs_n_t_60.txt"
# Intentionally no noiseless array or plotting/postprocessing job.
