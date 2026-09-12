# Server resource and execution plan

## Default: no new expensive simulation

The selected figures have complete saved evidence. `bash itw2027/slurm/submit.sh figures` submits one 1-CPU, 4-GB, 15-minute postprocessing job. It reads committed compact evidence, runs integer-rate checks, and rebuilds figures and tables. It does not need the source banks or server source paths.

All Slurm files use one task per job and at most 32 CPUs and 32 GB, below the available 64-CPU/1024-GB per-job ceiling. There is no reason to request a whole terabyte. `MATLAB/2024b_Update_3` matches the saved server version; override `ITW_MATLAB_MODULE` if the site's module name changes. Python uses conda environment `torch28`. Submit from the repository root through the helper so `logs/` exists before Slurm opens its log files. No partition or account is invented; the user's configured defaults apply.

## Evidence supporting the requests

`results/server_resource_logs.txt` contains extracted original log lines, and `server_resource_usage.csv` parses successful resource-report blocks. Requests include practical memory/time headroom; adjusted CPU/shard runtimes below are estimates, not fresh benchmarks.

| Work | Observed resources | New request | Rationale |
|---|---|---|---|
| Noisy BP point, 2,500 frames | 126 jobs at 8 CPUs; <=1,365 MB; longest 13.46 h | 8 CPUs, 8 GB, 18 h | Same worker count and numerical work; 16-h internal runtime guard leaves scheduler margin |
| Source-bank preparation | Six jobs at 8 CPUs; <=20,143 MB; longest 10.15 h | 8 CPUs, 32 GB, 14 h | ID transient symbol/bit arrays dominate memory. Old 10-h suggestion was below an observed runtime |
| Noiseless easy cells | Original jobs used 64 CPUs; numerical arrays about 7–8 GB; broad low CPU utilization in logs | 16 CPUs, 16 GB, 12 h | Smaller allocation, explicit thread control; sufficient working-set margin |
| ID n=32 and rank n=36 | Full-sample numerical times about 9.0 h and 5.0 h at old allocation | 32 CPUs, 32 GB, 24 h | Conservative allowance for reduced parallelism |
| ID n=34,36 and rank n=38,40 shards | Original complete runs are long; rank n=40 about 34.9 h, ID n=36 spans resumed attempts | 32 CPUs, 32 GB, 12 h per shard | Split message samples instead of enumerating all samples in one long job |
| ID n=38,40 small shards | Old 50-message shards took 26.7–44.7 h at 32 CPUs, about 4.6–4.8 GB | 32 CPUs, 32 GB, 36 h for 25-message shards | Roughly halve sample evaluation work; retain memory margin and checkpoints |
| Adversarial optional test | Completed attempts <=0.68 h at 32/64 CPUs, <=8.2 GB; high-K cases guarded | 16 CPUs, 16 GB, 3 h; small pilot first | Keep guards active; no need to reproduce skipped large-ID cases |
| Evidence export / plots | Small files, integer arithmetic, no field allocation | 1 CPU, 4 GB, 15 min each | Avoid waiting for a large node |

Original `elapsed_seconds` in resumed noiseless files covers the final attempt, not necessarily the total job history. Do not interpret it as full cold-run timing. Some original jobs exhausted an earlier wall-time allowance and resumed. The new sharded strategy explicitly avoids using those misleading partial times as guaranteed full-run estimates.

The noiseless evaluator keeps `(S+M) x K` coefficients and `(S+M) x C` chunk values, not a full `2^m` message space or `M x T x K` array. At r=20, ID K=65536 with M=25 uses about 6.6 MB just for negative coefficients; a large part of the measured 4–8 GB footprint is MATLAB/parallel runtime and transient arrays. Reducing CPU count is primarily a queue/runtime tradeoff, not a mathematical requirement. Process-pool fallback can raise memory; use the log to check whether the intended thread pool was created.

## Copy/reuse workflow

Run `copy_server_reuse.sh` on unimelb to preview, then `copy_server_reuse.sh --copy` to copy. It preserves both original directories and uses `--ignore-existing`, so it will not silently replace a destination file. After a copy, hashes can be compared against `reuse_manifest.csv`; copied original outputs can be converted with:

```bash
mkdir -p logs
sbatch itw2027/slurm/export.slurm
```

The compact evidence is already included, so this step is optional. Full source files are only needed to regenerate MATLAB results or verify bit-for-bit provenance. The two original trees are approximately 2 MB noiseless and 144 MB noisy including banks. Exact per-file byte counts are recorded in the manifest.

`submit.sh noisy waterfall` and `submit.sh noisy rate_pareto` submit bank arrays (concurrency 1), then point arrays (concurrency 4), then export and figures after successful completion. An existing compatible point is validated and skipped before bank loading. Missing banks fail the point job rather than launching a hidden memory-heavy computation. Bank preparation validates existing bank metadata and length. The wrapper requires complete fixed-frame output; a runtime-limited point is not accepted as completed evidence. A retry of an incomplete channel point starts it again with the same seed; the old engine does not checkpoint within the channel loop.

For a short setup check, run the local integration suite or select just one point in the relevant array after copying banks:

```bash
sbatch --array=0 --export=ALL,ITW_EXPERIMENT=waterfall itw2027/slurm/noisy_point.slurm
```

## Optional new noiseless sample

`submit.sh noiseless` writes to `itw2027/results/rerun_noiseless/` and uses 66 shard jobs plus the smaller unsharded cells. The selected paper does not need these jobs. Array caps are two per resource group; lower `%2` to `%1` for a smaller total cluster footprint. Independent groups may run concurrently.

| Shard array indices | Family / n_t | Messages per shard | Number of shards | Total messages |
|---|---|---:|---:|---:|
| 0–9 | ID / 34 | 200 | 10 | 2,000 |
| 10–29 | ID / 36 | 100 | 20 | 2,000 |
| 30–37 | ID / 38 | 25 | 8 | 200 |
| 38–45 | ID / 40 | 25 | 8 | 200 |
| 46–55 | Rank / 38 | 200 | 10 | 2,000 |
| 56–65 | Rank / 40 | 200 | 10 | 2,000 |

Each noiseless shard retains checkpointing, a seed, a signature, and actual sample count. A completed shard is left unchanged on resubmission. The new shard boundaries produce different samples even when a seed overlaps an old run; **do not combine old and new datasets**. Use a new evidence/output root when evaluating a fresh sample. For example, build a new source tree containing `noiseless/` and the reused `noisy/` tree, then call `export_evidence(absolute_source_root, absolute_new_evidence_root)`. Set `ITW_EVIDENCE_ROOT` and `ITW_OUTPUT_ROOT` to these new absolute directories for `build_results.py`. Keep directories inside `itw2027/` so provenance paths remain relative to this package. The builder requires all 27 noiseless cells and 126 noisy points; partial campaigns fail visibly.

For optional adversarial regeneration, start with `sbatch --array=0 --time=02:00:00 itw2027/slurm/adversarial.slurm`. With existing source files this validates nothing new and simply reuses the completed result; choose a fresh `BFC_RESULTS_ROOT` to recompute. Do not disable large-K cost guards for the main paper. Skipped cases remain explicitly skipped.

No server jobs were submitted as part of this implementation. This avoids recomputing completed evidence and leaves the user in control of the server campaign.
