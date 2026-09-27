#!/bin/bash
# Append plateau points to an already submitted campaign without restarting it.
set -euo pipefail
export FT_OUT="$(cd "${1:?Campaign directory}" && pwd)"
production="${2:?Original production job ID}"
report="${3:?Pending report job ID}"
[[ "$production" =~ ^[0-9]+$ && "$report" =~ ^[0-9]+$ ]]
test ! -e "$FT_OUT/low_snr_jobs.txt"
test -f "$FT_OUT/report_tasks.json"
export FT_MANIFEST="$FT_OUT/low_snr_tasks.json"
export FT_TEST_ONLY=0
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
mkdir -p "$FT_OUT/low_snr_source_snapshot"
cp itw2027/fixed_task/task_comparison.py itw2027/fixed_task/task_comparison_report.slurm \
   itw2027/fixed_task/submit_task_low_snr.sh "$FT_OUT/low_snr_source_snapshot/"
sha256sum "$FT_MANIFEST" "$FT_OUT/report_tasks.json" "$FT_OUT/low_snr_source_snapshot/"* \
    > "$FT_OUT/low_snr_source_sha256.txt"
run=$(sbatch --parsable --job-name=itw_rank_plateau --dependency="afterany:$production" \
    --array="0-${last}%64" --cpus-per-task=8 --mem=4G --time=00:45:00 \
    --export=ALL itw2027/fixed_task/job.slurm)
printf 'plateau=%s\noriginal_production=%s\nreport=%s\n' "$run" "$production" "$report" \
    > "$FT_OUT/low_snr_jobs.txt"
# Slurm stores a copy of the script at submission; replace the pending report
# so it includes the new combined-manifest selection as well as both dependencies.
new_report=$(sbatch --parsable --dependency="afterok:$production:${run%%;*}" \
    --export=ALL itw2027/fixed_task/task_comparison_report.slurm)
printf 'replacement_report=%s\n' "$new_report" >> "$FT_OUT/low_snr_jobs.txt"
scancel "$report"
cat "$FT_OUT/low_snr_jobs.txt"
