#!/bin/bash
# Run ON unimelb from the new checkout. Dry run by default; pass --copy to copy.
set -euo pipefail
cd "$(dirname "$0")/../.."
opts=(-a --ignore-existing)
if [[ "${1:-}" != --copy ]]; then opts+=(--dry-run --itemize-changes); fi
mkdir -p itw2027/results/source/noiseless itw2027/results/source/noisy
rsync "${opts[@]}" --exclude='*_checkpoint.mat' \
  /home/yangshuo/Git/ID_RS_code/conference_results/raw/ itw2027/results/source/noiseless/
rsync "${opts[@]}" --exclude='*.pdf' --exclude='*.png' \
  /home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/ itw2027/results/source/noisy/
