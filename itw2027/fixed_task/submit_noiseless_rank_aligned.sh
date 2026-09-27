#!/bin/bash
# Rank-only noiseless rerun; task geometry and sampling match the original campaign.
set -euo pipefail
export FT_OUT="$(cd "${1:?Usage: bash submit_noiseless_rank_aligned.sh OUTPUT_DIRECTORY}" && pwd)"
mkdir -p logs
if [[ -e "$FT_OUT/jobs.txt" ]]; then
    echo 'Existing submissions found; inspect jobs.txt before resubmitting.' >&2
    exit 1
fi
test -f "$FT_OUT/design.json"
count() { conda run -n torch28 python -c 'import json,sys; print(len(json.load(open(sys.argv[1])))-1)' "$1"; }
git rev-parse HEAD > "$FT_OUT/source_commit.txt"
export FT_TEST_ONLY=comparison
smoke=$(sbatch --parsable --job-name=itw_rank_nl_test --cpus-per-task=2 --mem=4G --time=00:20:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'smoke=%s\n' "$smoke" | tee "$FT_OUT/jobs.txt"
export FT_TEST_ONLY=0
export FT_MANIFEST="$FT_OUT/probe_rank.json"
probe=$(sbatch --parsable --job-name=itw_rank_nl_probe --dependency="afterok:${smoke%%;*}" --array=0 --cpus-per-task=2 --mem=16G --time=06:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'probe=%s\n' "$probe" | tee -a "$FT_OUT/jobs.txt"
export FT_MANIFEST="$FT_OUT/noiseless_rank.json"
run=$(sbatch --parsable --job-name=itw_rank_nl --dependency="afterok:${probe%%;*}" --array="0-$(count "$FT_MANIFEST")%64" --cpus-per-task=2 --mem=16G --time=06:00:00 --export=ALL itw2027/fixed_task/job.slurm)
printf 'noiseless_rank=%s\n' "$run" | tee -a "$FT_OUT/jobs.txt"
