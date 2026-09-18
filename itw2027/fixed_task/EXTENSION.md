# Incremental extension, 2026-09-18

## Scientific changes

- Noiseless nt=28:2:46; compute only 42,44,46. Fixed message lengths and
  the original negative-message samples and seeds remain unchanged.
- Noisy: all 37 existing SNRs, all four task/scheme combinations, 10000
  independent frames per point. G remains 540, with 270 tasks per class.
- Existing production contains 460000 frames. Add 1020000 frames in 408
  shards of 2500, yielding 1480000 frames. All twelve source banks already
  contain the required frames. Original snr_index values must be preserved:
  they are part of the noise seed, not recomputed from the incremental grid.
- Main noisy figures show balanced task error (FN+FP)/2. Per-class FN/FP,
  FER, raw counts and frame-cluster confidence intervals remain in CSV/MAT.
  Existing MAT files remain unchanged; overall error is reconstructed from
  their raw per-frame counts. New noisy files also store balanced_error.
- ID/rank x limits are -5 to -3.6 dB. Exact uses a marked broken x axis:
  -5 to -3.6 and 1.1 to 2.9 dB. No lines connect across the omitted interval.
  A full-range plot and separate FN/FP/FER diagnostic plot are also exported.
- Zero overall observations are omitted from logarithmic curves, not replaced
  with fictitious positive errors or repeated upper-limit triangles. The
  conventional zero-event tail is annotated; confidence limits remain in CSV.
- Noiseless reference on balanced-error plots is one half of noiseless FP.
- All four figures (noisy, noisy_full_range, noisy_diagnostics, noiseless)
  are exported as vector PDF and 600-dpi PNG.

## Reuse and validation

Extension results are written separately. reuse.json records the original
production root and SHA-256 hashes of both original result manifests. These
manifests are never rewritten. Aggregation validates task metadata, complete
and disjoint frame IDs 1:10000, all original SNR/task combinations, and full
index coverage for every sampled message at all ten tag lengths.

Each new noiseless task enumerates up to 262144 positions for 25 ID or 250
rank/exact negatives. There are 448 tasks per family, 1344 total. Each family
has one nt=46 timing/validation probe; this is a real production shard whose
output is retained. Its other 447 tasks depend on its successful completion.
Checkpoints and progress logs occur every 20 position chunks (1280 positions)
or at the end/runtime guard, reducing shared-filesystem metadata traffic.

## Slurm requests: at most 32 concurrent simulation tasks

| Group | Tasks | CPUs | RAM | Wall time | Concurrency |
|---|---:|---:|---:|---:|---:|
| ID noiseless | 448 | 2 | 4 GB | 2 h | 16 |
| Rank noiseless | 448 | 2 | 4 GB | 1 h | 4 |
| Exact noiseless | 448 | 2 | 4 GB | 30 min | 4 |
| Noisy additions | 408 | 8 | 4 GB | 1 h | 8 |
| Smoke validation | 1 | 2 | 4 GB | 20 min | 1 |
| Postprocessing | 1 | 1 | 4 GB | 30 min | 1 |

Family probes precede their respective arrays and use the same requests.
The smoke test precedes all runs; plots depend on every simulation array.
Main-array peak allocation is 112 CPUs and 128 GB distributed across jobs;
no individual job exceeds 8 CPUs or 4 GB. Each array is below 1000 entries.
Internal runtime guards: ID 110 min, rank/noisy 50 min, exact 25 min.

Requests use measured old-production maxima: noisy 29.6 min; nt=40 ID
54.7 min, rank 25.9 min, exact 7.4 min; peak simulation memory <1.7 GiB.
The nt=46 probes test the field-size extrapolation before the full arrays.

## Commands from the repository root

Python uses conda torch28. On Spartan load Anaconda3 and set CONDA_ENVS_PATH
to /data/gpfs/projects/punim2792/anaconda3/envs if not already initialized.

```sh
conda run -n torch28 python itw2027/fixed_task/campaign.py replot --base itw2027/fixed_task/results/production --out itw2027/fixed_task/results/replot_20260918
conda run -n torch28 python itw2027/fixed_task/campaign.py extension --base itw2027/fixed_task/results/production --out itw2027/fixed_task/results/extension_20260918
bash itw2027/fixed_task/submit_extension.sh itw2027/fixed_task/results/extension_20260918
```

The extension generator refuses an existing destination, validates all reused
completed results, and submits no jobs itself. submit_extension.sh refuses
to submit twice when jobs.txt exists. Resume failed indices individually
with their unchanged manifests, then repair dependency holds as needed.
