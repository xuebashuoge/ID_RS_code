#!/bin/bash
set -euo pipefail
export FT_OUT="$(cd "${1:?Supply million-frame campaign directory}" && pwd)"
test ! -e "$FT_OUT/jobs.txt"
mkdir -p logs
git rev-parse HEAD > "$FT_OUT/source_commit.txt"
export FT_TEST_ONLY=million
smoke=$(sbatch --parsable --job-name=itw_million_test --cpus-per-task=2 --mem=4G --time=00:20:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/jobs.txt"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/tasks.json"
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
run=$(sbatch --parsable --job-name=itw_conv_million --dependency="afterok:${smoke%%;*}" --array="0-${last}%64" --cpus-per-task=8 --mem=4G --time=01:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'conventional=%s\n' "$run" | tee -a "$FT_OUT/jobs.txt"
report=$(sbatch --parsable --dependency="afterok:${run%%;*}" --export=ALL itw2027/fixed_task/conventional_full_report.slurm)
printf 'report=%s\n' "$report" | tee -a "$FT_OUT/jobs.txt"
