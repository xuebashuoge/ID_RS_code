#!/bin/bash
# Incremental campaign: original production files are read-only inputs.
set -euo pipefail
export FT_OUT="$(cd "${1:?Usage: bash submit_extension.sh EXTENSION_DIRECTORY}" && pwd)"
mkdir -p logs
if [[ -e "$FT_OUT/jobs.txt" ]]; then
    echo 'Existing submissions found; inspect jobs.txt and resume only failed tasks.' >&2
    exit 1
fi
test -f "$FT_OUT/reuse.json"
count() { conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$1"; }
git rev-parse HEAD > "$FT_OUT/source_commit.txt"
export FT_TEST_ONLY=1
smoke=$(sbatch --parsable --job-name=itw_ext_test --cpus-per-task=2 --mem=4G --time=00:20:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/jobs.txt"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/noisy.json"
noisy=$(sbatch --parsable --job-name=itw_ext_noisy --dependency="afterok:${smoke%%;*}" --array="0-$(count "$FT_MANIFEST")%8" --cpus-per-task=8 --mem=4G --time=01:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'noisy=%s\n' "$noisy" | tee -a "$FT_OUT/jobs.txt"
dependencies="${noisy%%;*}"
for family in id rank exact; do
    case "$family" in
        id) wall=02:00:00; concurrency=16 ;;
        rank) wall=01:00:00; concurrency=4 ;;
        exact) wall=00:30:00; concurrency=4 ;;
    esac
    # A real nt=46 production shard gates each family; its output is reused.
    export FT_MANIFEST="$FT_OUT/probe_${family}.json"
    probe=$(sbatch --parsable --job-name="itw_ext_probe_${family}" --dependency="afterok:${smoke%%;*}" --array=0 --cpus-per-task=2 --mem=4G --time="$wall" --export=ALL itw2027/fixed_task/job.slurm)
    printf 'probe_%s=%s\n' "$family" "$probe" | tee -a "$FT_OUT/jobs.txt"
    export FT_MANIFEST="$FT_OUT/noiseless_${family}.json"
    run=$(sbatch --parsable --job-name="itw_ext_${family}" --dependency="afterok:${probe%%;*}" --array="0-$(count "$FT_MANIFEST")%${concurrency}" --cpus-per-task=2 --mem=4G --time="$wall" --export=ALL itw2027/fixed_task/job.slurm)
    printf 'noiseless_%s=%s\n' "$family" "$run" | tee -a "$FT_OUT/jobs.txt"
    dependencies="${dependencies}:${run%%;*}"
done
plots=$(sbatch --parsable --dependency="afterok:${dependencies}" --export=ALL itw2027/fixed_task/postprocess.slurm)
printf 'plots=%s\n' "$plots" | tee -a "$FT_OUT/jobs.txt"
