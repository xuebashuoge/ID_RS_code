#!/bin/bash
set -euo pipefail
export FT_OUT="$(cd "${1:?Supply corrected conventional results directory}" && pwd)"
mode="${2:-full}"
case "$mode" in
    pilot) manifest=pilot.json; job_file=jobs_pilot.txt ;;
    full) manifest=noisy_conventional_rc_3_5_n_t_60.json; job_file=jobs.txt ;;
    *) echo 'Second argument must be pilot or full' >&2; exit 1 ;;
esac
test ! -e "$FT_OUT/$job_file"
mkdir -p logs
git rev-parse HEAD > "$FT_OUT/source_commit.txt"
export FT_TEST_ONLY=60
smoke=$(sbatch --parsable --job-name=itw_rc35_test --cpus-per-task=2 --mem=4G --time=00:20:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/$job_file"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/$manifest"
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
job=$(sbatch --parsable --job-name=itw_conv_rc35 --dependency="afterok:${smoke%%;*}" --array="0-${last}%32" --cpus-per-task=8 --mem=4G --time=01:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'conventional=%s\n' "$job" | tee -a "$FT_OUT/$job_file"
