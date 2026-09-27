#!/bin/bash
set -euo pipefail
export FT_OUT="$(cd "${1:?Campaign directory}" && pwd)"
production="${2:?Current production job ID}"
old_report="${3:?Pending report job ID}"
[[ "$production" =~ ^[0-9]+$ && "$old_report" =~ ^[0-9]+$ ]]
test ! -e "$FT_OUT/conventional_plateau_jobs.txt"
export FT_MANIFEST="$FT_OUT/conventional_plateau_tasks.json"
export FT_TEST_ONLY=0
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
mkdir -p "$FT_OUT/conventional_plateau_source_snapshot"
cp itw2027/fixed_task/task_comparison.py itw2027/fixed_task/task_comparison_report.slurm \
   itw2027/fixed_task/submit_conventional_plateau.sh "$FT_OUT/conventional_plateau_source_snapshot/"
sha256sum "$FT_MANIFEST" "$FT_OUT/full_grid_tasks.json" "$FT_OUT/conventional_plateau_source_snapshot/"* \
    > "$FT_OUT/conventional_plateau_source_sha256.txt"
run=$(sbatch --parsable --job-name=itw_conv_plateau --dependency="afterany:$production" \
    --array="0-${last}%64" --cpus-per-task=8 --mem=4G --time=00:10:00 \
    --export=ALL itw2027/fixed_task/job.slurm)
printf 'plateau=%s\noriginal_production=%s\n' "$run" "$production" \
    > "$FT_OUT/conventional_plateau_jobs.txt"
report=$(sbatch --parsable --dependency="afterok:$production:${run%%;*}" --export=ALL \
    itw2027/fixed_task/task_comparison_report.slurm)
printf 'report=%s\n' "$report" >> "$FT_OUT/conventional_plateau_jobs.txt"
scancel "$old_report"
cat "$FT_OUT/conventional_plateau_jobs.txt"
