# nt=60 noisy task-error comparison

## Current refinement: conventional waterfalls at 0.05 dB

After completing the 0.1 dB sweep, both conventional waterfalls are refined
to 0.05 dB: rank 1.8 to 2.2 dB and exact -1.2 to -0.8 dB. The low-SNR grid
stays at 0.1 dB with 1000 frames per point, and BFC rank stays at 100000
frames per point. `waterfall_design.json` records total budgets, and
`waterfall_report_tasks.json` combines original samples with the additions.
`waterfall_tasks.json` contains only new frames; it preserves random streams
at existing SNRs and assigns unused noise streams to new SNRs. Separate
`waterfall_results/` paths avoid old cancelled off-grid checkpoints.

Exact conventional total budgets are 1M at -1.0 dB, 1M at -0.95 dB, 3M at
-0.9 dB, 5M at -0.85 dB, and 30M at -0.8 dB. Rank conventional uses 50k at
1.95 dB, 250k at 2.05 dB, and 3M at 2.15 dB, retaining existing budgets
on the original grid. In total 4011 added jobs simulate 40.11M new frames.
The submission script is `submit_waterfall_refinement.sh`, with 64 concurrent
jobs, 8 CPUs, 4 GB and 45 minutes per 10000-frame shard. Reporting accumulates
counts and frame moments without holding all frames in memory. A zero-error
result after extension remains an upper limit; a nonzero result is not guaranteed.

The previously completed reports/figures are preserved in
`before_waterfall_refinement/` when submitting the extension. The original
three-panel plotting script and figure remain untouched.

The larger rank SNR gain is primarily explained by its conventional baseline:
rank transports 150 bits/message at LDPC rate 5/6, whereas exact transports
100 bits/message at rate 3/5 (including 2880 padding bits per block). Both BFC
schemes transport 60-bit tags at rate 1/3. Each codeword is 64800 bits for
360 messages, or 180 channel uses/message. Thus the BFC waterfalls are close,
but the conventional rank waterfall is about 3 dB to the right of exact.
The initial rank gain at Pe=1e-5 was approximately 6.43 dB by log interpolation;
its endpoint is based on only five error-bearing frames. Exact's 1e-5 crossing
is bracketed by -0.9 and -0.8 dB (roughly 3.4–3.5 dB gain), not yet determined
by two positive measured points. These are task-error gains for these chosen
payloads and rates, rather than a task-independent property of rank vs exact.

## Completed initial sweep (before refinement)

## Current plan: uniform 0.1 dB steps

All curves start at **-5.0 dB**, including both conventional curves. The final
conventional rank grid is -5.0 to 2.2 dB, and conventional exact is -5.0 to
-0.8 dB, each with exactly 0.1 dB spacing. Added low-SNR points use 1000
frames each; the waterfall/tail budgets below are retained. BFC rank remains
-5.0 to -4.2 dB with 100000 frames per point. Total: 8.356 million frames
in 1201 shards, including 106 added conventional plateau shards.

The plateau budget was reduced before submission after checking saved task
errors: exact conventional is 0.5 at -5 dB, 0.4999997 at -3 dB, and about
0.49879 at -1.2 dB; rank conventional at 1.8 dB is 0.44093. Only the added
low-SNR points use 1000 frames. Existing 10000-frame near-waterfall points
and the million-frame tails retain their budgets. Plateau jobs request
8 CPUs, 4 GB and 10 minutes. This reduces added frames from 1060000 to
106000 while retaining every 0.1 dB SNR point.

`full_grid_tasks.json` and `full_grid_design.json` are now authoritative.
`grid01_tasks.json` remains unchanged for the running waterfall array;
`conventional_plateau_tasks.json` contains only the additional jobs. The added
array runs after the current array terminates, preserving the overall 64-job
cap. A replacement report waits for both arrays and plots the complete
conventional curves, including the plateau from -5.0 dB. The three-panel
script and its figure are not modified.

### Earlier waterfall-only grid (superseded conventional starting SNR)

The user's final SNR-grid requirement supersedes the mixed-step plan recorded
below. BFC rank runs -5.0 to -4.2 dB (nine points, 100000 frames each).
Conventional rank runs 1.8, 1.9, 2.0, 2.1, 2.2 dB with respectively
10000, 10000, 50000, 1000000, 3000000 frames. Conventional exact runs
-1.2, -1.1, -1.0, -0.9, -0.8 dB with respectively 10000, 10000, 10000,
250000, 3000000 frames. Total: 8.25 million frames in 1095 shards.

`grid01_tasks.json` and `grid01_design.json` are authoritative for the revised
running campaign. Existing on-grid task metadata and checkpoints are retained
verbatim; off-grid results remain archived and are excluded. The superseded
arrays/report are cancelled and replaced using `submit_task_grid01.sh`.
The replacement array waits for old writers to terminate, caps concurrency
at 64, and schedules a standalone report that automatically selects the
uniform-grid manifest. Archived exact BFC data are also restricted to the
0.1 dB grid. The original three-panel script and figure remain untouched.

## Earlier campaign design (superseded SNR grid)

The rank task is `integer(message) <= 2000`, on 150-bit messages (2001 positive
messages, including zero). All schemes send one 64800-bit DVB-S2 LDPC block
for 360 messages: 180 channel uses per message. BFC uses rate 1/3 and 21600
information bits. Rank conventional uses rate 5/6 and all 54000 information
bits. Exact conventional retains 100-bit messages and rate 3/5, with 36000
payload bits and 2880 padding bits. Exact means Hamming weight exactly two.

The primary metric is `(false positives + false negatives)/(360*frames)`,
with 180 positive and 180 negative source messages in each frame. Payload
FER and information-block FER are diagnostics. Source messages are freshly
sampled; Threefry substreams make checkpoint resume and sharding reproducible.
Sources are shared across SNRs and schemes within each family. Pilot seeds
are separate from production seeds and pilot observations are not pooled.

The former million-frame exact simulation already saved FP and FN counts.
`conventional_full.py summarize` now also produces `task_error_report.json`
and `task_error_report.md`; its historical FER report remains available.
The new campaign independently reruns the exact waterfall and tail.

| Curve | SNR interval (Es/N0, dB) | Frames per point | Frames per job |
|---|---|---|---|
| Rank BFC | -5.00 to -4.20 | exactly 100,000 at every SNR | 2,500 |
| Rank conventional | 1.80 to 2.18 | 10,000–3,000,000 | 10,000 |
| Exact conventional | -1.20 to -0.84 | 10,000–3,000,000 | 10,000 |

The exact SNR grids and budgets are in `task_comparison.py::PLANS` and each
generated `design.json`. The aligned plan uses 20.1 million frames in 2370
jobs. The 2026-09-26 pilots (Slurm 31309981) completed in 74–241 seconds for
1000 frames, including startup, and used at most 1149 MB. Production requests
8 CPUs, 4 GB and 45 minutes per shard, with a checkpoint deadline at 40
minutes. One mixed array caps total simulation concurrency at 64 by default;
128 is supported. The result writer saves every 100 frames.

Run from the repository root:

```bash
conda run -n torch28 python itw2027/fixed_task/task_comparison.py generate \
  --out itw2027/fixed_task/results/NEW_CAMPAIGN
bash itw2027/fixed_task/submit_task_comparison.sh \
  itw2027/fixed_task/results/NEW_CAMPAIGN 64
```

Submission schedules a MATLAB correctness test, the production array after
that test succeeds, and a report/figure job after the entire array succeeds.
Job IDs, source snapshots and checksums are recorded in the campaign folder.
The report job writes `task_error_summary.csv`, `task_error_report.json`,
standalone comparison figures. The exact BFC reference is loaded from the
unchanged archived nt=60 experiment. The old and new rank samples are never
pooled. The three-panel plotting script is restored to Git HEAD, with its
previous working copy backed up in `results/three_panel_before_restore_20260926.py`.
Neither that script nor its figure is used or regenerated by this campaign.

To regenerate reports and the standalone comparison after completion:

```bash
conda run -n torch28 python itw2027/fixed_task/task_comparison.py summarize --out CAMPAIGN
```

For an interrupted shard, resubmit its original manifest index with the same
`FT_OUT`, `FT_MANIFEST`, and `FT_TEST_ONLY=0` environment to `job.slurm`.
Do not run duplicate copies of an index concurrently. Completed shards return
without recomputation; incomplete shards resume their saved frame count.
An `afterok` report dependency will remain blocked if any shard fails; after
repairing those shards, submit `task_comparison_report.slurm` separately.

Uncertainty uses independent frame means, because messages within an LDPC
block are correlated. The normal standard error is only approximate in rare
tails. A separate conservative exact-binomial upper bound uses the event
"any task error in this frame", which bounds the mean task error. Three
million zero-error frames give an upper bound just below 1e-6; zero errors
are plotted as upper limits, never as zero probability. Sparse tails are
flagged for more frames; reaching either target is not guaranteed in advance.
Rank conventional extends to 2.18 dB because the independent pilot still
measured task error 4.25e-4 at 2.10 dB. Exact conventional stops at -0.84 dB,
where the archived million-frame task error was 5.08e-7 (FER was 9e-6).
The new rank BFC budget remains fixed even near its floor; only conventional
budgets increase with SNR. The initial production array 31310093 was cancelled;
the revised fixed-100k campaign uses a fresh directory and does not pool its
partial checkpoints or the pilots into production.

The fixed-100k campaign was subsequently extended with -5.0 and -4.9 dB to
show the plateau and align the BFC curves with ID and exact. Its original
`tasks.json` and `design.json` describe the unchanged running array;
`low_snr_extension.json` records the amendment, `low_snr_tasks.json` contains
80 additional shards, and `report_tasks.json` combines both manifests.
The report automatically selects the combined manifest. The added array
runs after the original array ends, preserving the overall 64-job cap.

Coding gains use log-probability interpolation only when positive observed
points bracket the target. No extrapolation is made below a BFC floor.

Validation:

```bash
cd itw2027/fixed_task
conda run -n torch28 python -m unittest test_task_comparison.py test_conventional_full.py
```

`test_task_comparison.m` checks support boundaries, task error versus FER,
high-SNR decoding, deterministic shard equivalence, and checkpoint resume
for all three curves. The pilots additionally exercise the mixed JSON loader.
