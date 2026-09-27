#!/bin/bash
# Run from repository root. One array enforces the cap across all three curves.
set -euo pipefail
export FT_OUT="$(cd "${1:?Supply campaign directory}" && pwd)"
concurrency="${2:-64}"
[[ "$concurrency" =~ ^[0-9]+$ ]] && ((concurrency>=1 && concurrency<=128)) || {
    echo 'Concurrency must be between 1 and 128' >&2; exit 1;
}
test ! -e "$FT_OUT/jobs.txt"
mkdir -p logs "$FT_OUT/source_snapshot"
cp itw2027/fixed_task/*.m itw2027/fixed_task/*.py itw2027/fixed_task/*.sh \
   itw2027/fixed_task/*.slurm "$FT_OUT/source_snapshot/"
git rev-parse HEAD > "$FT_OUT/source_commit.txt"
git diff -- itw2027/fixed_task > "$FT_OUT/source_diff.patch"
sha256sum "$FT_OUT/tasks.json" "$FT_OUT/source_snapshot/"* > "$FT_OUT/source_sha256.txt"
export FT_TEST_ONLY=comparison
smoke=$(sbatch --parsable --job-name=itw_task_test --cpus-per-task=8 --mem=4G \
    --time=00:10:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/jobs.txt"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/tasks.json"
last=$(conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
dependency="afterok:${smoke%%;*}"
if [[ -n "${FT_DEPENDENCY:-}" ]]; then dependency+=":$FT_DEPENDENCY"; fi
run=$(sbatch --parsable --job-name=itw_task_error --dependency="$dependency" \
    --array="0-${last}%${concurrency}" --cpus-per-task=8 --mem=4G --time=00:45:00 \
    --export=ALL itw2027/fixed_task/job.slurm)
printf 'production=%s\nconcurrency=%s\n' "$run" "$concurrency" | tee -a "$FT_OUT/jobs.txt"
report=$(sbatch --parsable --dependency="afterok:${run%%;*}" --export=ALL \
    itw2027/fixed_task/task_comparison_report.slurm)
printf 'report=%s\n' "$report" | tee -a "$FT_OUT/jobs.txt"
