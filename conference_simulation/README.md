# Conference Section 3 simulation suite

This directory produces the proposed two figures and one table while keeping
raw runs separate from processed, paper-ready artifacts.

## Experiment grid

- Tasks: identification, rank with `S=21`, and exact threshold with `beta=2`.
- Finite-length grid: `n=24:2:40`, design `E_FP=0.10`.
- Default sample: 2,000 uniformly sampled **negative** messages per task/n.
- Each sampled message is evaluated over all `L=2^(n/2)` positions, so its
  `R_i/L` is exact; no position Monte Carlo is used.
- Rate/exponent targets: `0.05, 0.10, 0.15, 0.20` on `n=24:2:80`.

The 27-cell array is ordered by task and then by `n`:

1. array indices 0--8: identification;
2. array indices 9--17: rank;
3. array indices 18--26: exact threshold.

## Server submission

From the repository root:

```bash
bash conference_simulation/slurm/submit_conference_pipeline.sh
```

The finite-length and adversarial jobs request 64 CPUs and 1024 GB. They use
`%1` concurrency and dependencies so only one whole-node simulation job is
eligible to run at a time.

The submission helper divides the finite-length grid into workload classes:

| Class | Array cells | Wall-time ceiling |
|---|---|---:|
| Fast | ID `n=24:28`, rank `n=24:32`, all exact threshold | 24 hours |
| Medium | ID `n=30:34`, rank `n=34:36` | 48 hours |
| Slow | ID `n=36:40`, rank `n=38:40` | 72 hours |

The medium array depends on the fast array, the slow array depends on the
medium array, and adversarial validation starts only after the slow array.
Rate/exponent generation is independent and requests only 30 minutes.

The exact calculation is compute-heavy for large `K`, especially ID at
`n=40`. Every finite-length job writes a resumable checkpoint. If a slow cell
reaches its 72-hour limit, resubmitting that array index resumes from its last
checkpoint; a completed `.mat` file is left unchanged.

Useful submission overrides include:

```bash
sbatch --time=12:00:00 \
  --export=ALL,BFC_NUM_MESSAGES=200,BFC_CHUNK_SIZE=256 \
  conference_simulation/slurm/run_finite_length_array.slurm
```

`BFC_NUM_MESSAGES` is per array job. Independent shards can be produced by
setting `BFC_SHARD_INDEX` to different integers; post-processing concatenates
all shards for the same task/n cell.

The adversarial runner has default cost guards. Rows with
`status=skipped_by_cost_guard` are explicit, not silently treated as verified.
Raise `BFC_ADVERSARIAL_MAX_K` and `BFC_ADVERSARIAL_MAX_PROXY` only after checking
the pilot timings.

## Pilot run

Before the full submission, run one small array cell:

```bash
sbatch --array=18 --time=02:00:00 \
  --export=ALL,BFC_NUM_MESSAGES=20,BFC_CHUNK_SIZE=128 \
  conference_simulation/slurm/run_finite_length_array.slurm
```

Index 18 is exact threshold at `n=24`.

## Outputs

Raw results are written under `conference_results/raw/` and ignored by Git.
Processed tables are written under `conference_results/processed/tables/`.
Figures are written as both PDF and 300-dpi PNG under
`conference_results/processed/figures/`:

- `figure1_finite_length_typical_worst_case.{pdf,png}`
- `figure2_rate_error_exponent.{pdf,png}`

The PDF export is vector-first at the requested 300-dpi export setting; the
fallback uses MATLAB's 300-dpi vector PDF driver.

## Legacy result inventory

On either legacy branch/worktree, normalize existing per-n files without
moving or deleting them:

```matlab
addpath('conference_simulation');
cleanup_legacy_results();
```

This writes `legacy_results_inventory.csv` and `.mat` under
`conference_results/processed/legacy/`.
