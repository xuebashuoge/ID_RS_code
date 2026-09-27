#!/bin/bash
# Replace superseded mixed-step arrays, retaining compatible checkpoints.
set -euo pipefail
export FT_OUT="$(cd "${1:?Campaign directory}" && pwd)"
old_production="${2:?Superseded production ID}"
old_plateau="${3:?Superseded plateau ID}"
old_report="${4:?Superseded report ID}"
for job in "$old_production" "$old_plateau" "$old_report"; do [[ "$job" =~ ^[0-9]+$ ]]; done
test ! -e "$FT_OUT/grid01_jobs.txt"
export FT_MANIFEST="$FT_OUT/grid01_tasks.json"
export FT_TEST_ONLY=0
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
mkdir -p "$FT_OUT/grid01_source_snapshot"
cp itw2027/fixed_task/*.m itw2027/fixed_task/*.py itw2027/fixed_task/*.sh \
   itw2027/fixed_task/*.slurm "$FT_OUT/grid01_source_snapshot/"
sha256sum "$FT_MANIFEST" "$FT_OUT/grid01_source_snapshot/"* > "$FT_OUT/grid01_source_sha256.txt"
# Cancellation saves previously written checkpoints. The afterany dependency
# also waits for all old writers to exit before any replacement shard resumes.
scancel "$old_report" "$old_plateau" "$old_production"
run=$(sbatch --parsable --job-name=itw_task_grid01 \
    --dependency="afterany:$old_production:$old_plateau" \
    --array="0-${last}%64" --cpus-per-task=8 --mem=4G --time=00:45:00 \
    --export=ALL itw2027/fixed_task/job.slurm)
printf 'production=%s\nconcurrency=64\n' "$run" > "$FT_OUT/grid01_jobs.txt"
report=$(sbatch --parsable --dependency="afterok:${run%%;*}" --export=ALL \
    itw2027/fixed_task/task_comparison_report.slurm)
printf 'report=%s\n' "$report" >> "$FT_OUT/grid01_jobs.txt"
cat "$FT_OUT/grid01_jobs.txt"
