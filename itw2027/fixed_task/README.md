# Fixed-task ITW campaign (branch itw_gpt)

This campaign is independent of historical exponent-selected message lengths.
Tasks: ID at m=100000 with one deterministic random target; rank <=20 at
m=5000 (S=21); exact Hamming weight 2 at m=100 (S=4950). Right padding is
deterministic and does not change m or the support. Noiseless nt=28:2:40,
r=nt/2, T=2^r, K=ceil(m/r). The same original sampled messages are used
across nt, with 200 ID negatives and 2000 rank/exact negatives in production.
Every production message enumerates all T positions. Sample maxima are not
maximal errors over all messages/functions. Pilot partial enumeration is
timing evidence only and is rejected as production plot input.

Noisy: nt=40, G=540, Nb=64800, Ni=21600, LDPC rate 1/3, BP with up to 50
iterations and early termination. BPSK Es=1; SNR means Es/N0, real noise
variance N0/2, LLR=4y/N0. Conventional exact-threshold transmits all 540
100-bit messages in a rate-5/6 LDPC frame (Ni=54000). Identical task samples
and paired noise streams are used for the two schemes at shared SNRs.
ID/rank full-message transmission is infeasible within the same frame budget.

Pilot: -5.5:0.5:3.5 dB, 100 independent frames per point. Three banks are
shared across SNRs (not counted as independent source draws when pooling).
Production: a separate seed group, 2500 frames/point, with 10000 at selected
points near the high-SNR pilot waterfall edge. The pilot must bracket a
clear waterfall for both rates before generating production manifests.
The selected grid uses 0.1 dB steps near the measured waterfalls plus anchor
points. Review design.json and pilot plots before submitting production.

Every frame has 270 positives and 270 negatives sampled uniformly within
each class. FN/FP are class-conditional sample averages, not worst-case
guarantees. Store per-frame error counts, FER, iterations and paired
noiseless FP. Confidence intervals resample whole independent frames.
Zero-event upper limits use 1-0.05^(1/F), based on F independent frames;
these conservatively bound the per-task mean via the event of any error in
a frame. Downward triangles in plots mark these upper limits, not measured
positive errors. The paired ID noiseless reference can itself be unresolved;
use the fully enumerated noiseless experiment for its final reference.

## Run and validate

From the repository root (Python always uses conda environment torch28):

```sh
/Applications/MATLAB_R2025a.app/bin/matlab -batch "addpath('itw2027/fixed_task'); test_fixed_task"
conda run -n torch28 python -m unittest discover -s itw2027/fixed_task -p 'test_*.py'
conda run -n torch28 python itw2027/fixed_task/campaign.py pilot --out itw2027/fixed_task/results/pilot
bash itw2027/fixed_task/submit.sh itw2027/fixed_task/results/pilot
conda run -n torch28 python itw2027/fixed_task/campaign.py summarize --out itw2027/fixed_task/results/pilot
conda run -n torch28 python itw2027/fixed_task/campaign.py production --pilot itw2027/fixed_task/results/pilot --out itw2027/fixed_task/results/production
bash itw2027/fixed_task/submit.sh itw2027/fixed_task/results/production
```

On Spartan, use a login shell to initialize Slurm and initialize the existing
conda installation if necessary. MATLAB module defaults to MATLAB/2024b_Update_3.
Results, banks and manifests live under the ignored results directory. No
external dataset is needed; $DATASET is left unchanged.

## Resources and recovery

Arrays initially cap banks at 4 jobs (8 CPUs/32 GB/3 h each), channel tasks
at 8 (8 CPUs/16 GB/6 h each), noiseless tasks at 2 (8 CPUs/32 GB/6 h each).
Pilot channel jobs request 2 h and pilot noiseless jobs request 1 h.
A 20-minute server smoke test gates all simulation arrays via afterok.
Pilot banks contain 100 frames; production banks and channel shards contain
250. Benchmark runtime and memory before production; resize shards to target
2-4 h and request measured duration plus headroom. Do not request 1 TB by default.
The noiseless evaluator is chunked/vectorized, not a 64-worker pool.

Bank/channel checkpoints are saved every 5/10 frames; noiseless checkpoints
after each 64-position chunk. Save uses temporary-file replacement. Runtime
guards stop before scheduler limits and mark unfinished output incomplete.
Resubmitting the SAME manifest index resumes from its checkpoint; final
aggregation rejects missing/incomplete/overlapping shards. Completed results
are validated and reused. Do not run duplicate copies of a task concurrently.
If a bank job fails, its dependent channel array does not run: resume the
failed bank indices, then update/resubmit the held dependent array after
successful bank completion. jobs.txt records submitted array IDs.

Production parameter selection is based on the separate pilot, not on
optional stopping within the production sample. All generated manifests and
source commit hashes should be retained with results.
