#!/bin/bash
# Submit fresh ID and exact-weight BFC samples from the repository root.
set -euo pipefail
module load Anaconda3
export FT_OUT="$(cd "${1:?Supply campaign directory}" && pwd)"
concurrency="${2:-64}"
record="${3:-jobs.txt}"
[[ "$concurrency" =~ ^[0-9]+$ ]] && ((concurrency>=2 && concurrency<=128)) || {
    echo 'Concurrency must be between 2 and 128' >&2; exit 1;
}
[[ "$record" =~ ^jobs(_retry_[0-9]+)?\.txt$ ]] || {
    echo 'Job record must be jobs.txt or jobs_retry_N.txt' >&2; exit 1;
}
each=$((concurrency/2))
record_path="$FT_OUT/$record"
tag="${record%.txt}"
test ! -e "$record_path"
test -f "$FT_OUT/tasks.json" && test -f "$FT_OUT/id_tasks.json" && test -f "$FT_OUT/exact_tasks.json"
snapshot="$FT_OUT/source_snapshot_$tag"
mkdir -p logs "$snapshot"
cp itw2027/fixed_task/*.m itw2027/fixed_task/*.py itw2027/fixed_task/*.sh \
   itw2027/fixed_task/*.slurm "$snapshot/"
git rev-parse HEAD > "$FT_OUT/source_commit_$tag.txt"
sha256sum "$FT_OUT/tasks.json" "$FT_OUT/id_tasks.json" "$FT_OUT/exact_tasks.json" \
    "$snapshot/"* > "$FT_OUT/source_sha256_$tag.txt"
smoke=$(sbatch --parsable --job-name=itw_bfc_100k_test \
    --cpus-per-task=8 --mem=4G --time=00:20:00 --export=ALL \
    itw2027/fixed_task/bfc_100k_test.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$record_path"
export FT_TEST_ONLY=0
dependencies=()
for family in id exact; do
    export FT_MANIFEST="$FT_OUT/${family}_tasks.json"
    last=$(conda run -p /data/gpfs/projects/punim2792/anaconda3/envs/torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$FT_MANIFEST")
    run=$(sbatch --parsable --job-name="itw_${family}_bfc_100k" \
        --dependency="afterok:${smoke%%;*}" --array="0-${last}%${each}" \
        --cpus-per-task=8 --mem=4G --time=02:00:00 --export=ALL \
        itw2027/fixed_task/job.slurm)
    printf '%s_production=%s\n' "$family" "$run" | tee -a "$record_path"
    dependencies+=("${run%%;*}")
done
printf 'concurrency_per_family=%s\n' "$each" | tee -a "$record_path"
report=$(sbatch --parsable --job-name=itw_bfc_100k_report \
    --dependency="afterok:${dependencies[0]}:${dependencies[1]}" --export=ALL \
    itw2027/fixed_task/bfc_100k_report.slurm)
printf 'report=%s\n' "$report" | tee -a "$record_path"
