#!/bin/bash
set -euo pipefail
export FT_OUT="$(cd "${1:?Campaign directory}" && pwd)"
test ! -e "$FT_OUT/waterfall_jobs.txt"
export FT_MANIFEST="$FT_OUT/waterfall_tasks.json"
export FT_TEST_ONLY=0
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
mkdir -p "$FT_OUT/waterfall_source_snapshot" "$FT_OUT/before_waterfall_refinement"
cp itw2027/fixed_task/*.m itw2027/fixed_task/*.py itw2027/fixed_task/*.sh \
   itw2027/fixed_task/*.slurm "$FT_OUT/waterfall_source_snapshot/"
cp "$FT_OUT/task_error_summary.csv" "$FT_OUT/task_error_report.json" \
   "$FT_OUT/task_error_comparison.png" "$FT_OUT/task_error_comparison.pdf" \
   "$FT_OUT/before_waterfall_refinement/"
sha256sum "$FT_MANIFEST" "$FT_OUT/waterfall_report_tasks.json" "$FT_OUT/waterfall_source_snapshot/"* \
    > "$FT_OUT/waterfall_source_sha256.txt"
run=$(sbatch --parsable --job-name=itw_waterfall --array="0-${last}%64" \
    --cpus-per-task=8 --mem=4G --time=00:45:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'production=%s\nconcurrency=64\n' "$run" > "$FT_OUT/waterfall_jobs.txt"
report=$(sbatch --parsable --dependency="afterok:${run%%;*}" --export=ALL \
    itw2027/fixed_task/task_comparison_report.slurm)
printf 'report=%s\n' "$report" >> "$FT_OUT/waterfall_jobs.txt"
cat "$FT_OUT/waterfall_jobs.txt"
