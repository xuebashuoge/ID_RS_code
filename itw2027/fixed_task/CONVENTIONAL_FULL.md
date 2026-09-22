# Conventional FER confirmation: one million fresh frames per SNR

The corrected rate-3/5 pilot (array 31026211) completed at all five points.
Its FER was 1 at -1.4 dB, 0.9996 at -1.2, 0.1692 at -1.0, and zero observed
in 2500 frames at -0.8 and -0.6. These pilot samples are not pooled into the
confirmatory sample. The old rate-5/6 point at 2.1 dB had 5 frame errors in
10000 frames (FER=5e-4); 6e-5 was balanced task error, a different metric.

## Fixed design

- Conventional exact-threshold only: m=100, G=360, Nb=64800, neff=180,
  LDPC rate 3/5, Ni=38880, 36000 message bits and 2880 zero padding bits.
- BP, at most 50 iterations with early termination; BPSK Es/N0 with real
  noise variance N0/2. FER tests the entire recovered information block.
- SNR grid: -5,-4,-3,-2,-1.5,-1.2,-1.1; then -1.00:0.02:-0.60; and 0 dB.
- All 29 points use exactly 1000000 independently sampled frames, 180
  positive and 180 negative messages per frame. No outcome-dependent stops.
- 100 shards per SNR, 10000 frames each: 2900 array tasks, concurrency 64.
  Each task requests 8 CPUs, 4 GB and 1 hour, with a 50-minute internal
  guard. Peak requested resources at 64 concurrent tasks are 512 CPUs and
  256 GB across the cluster. Checkpoints are saved every 100 frames.
- No BFC, noiseless, or plotting jobs. A dependent report job (1 CPU,
  4 GB, 30 min) validates complete coverage and writes CSV/JSON/Markdown.

## Independent random streams and recovery

Messages are streamed directly into conventional LDPC blocks. No RS tags
are computed and no 10000-frame bank is repeated. Exact positive messages
are uniform over the 4950 weight-two words; negatives use uniform bit rows
with rejection of the positive support.

Threefry source seed 20260922 uses substream global_frame. Noise seed 20260923
uses substream snr_index*2^32+global_frame. All substream IDs are exactly
representable and task validation restricts ranges. This prevents the old
10000-frame seed spacing from causing overlaps in a million-frame sweep.
Messages are paired across SNRs; noise substreams are distinct. Both streams
are reconstructed from the global frame ID so sharding/resume is exact.

Each MAT result retains per-frame counts, FN/FP/FER, balanced error, decoder
iterations, complete task parameters and runtime. Original campaigns remain
unchanged. Resubmit incomplete indices with the same manifest to resume.

## Threshold report

The report separately identifies the first tested SNR with empirical FER
below 1e-5, the first with a one-sided exact-binomial 95% upper bound below
1e-5, and the first satisfying a simultaneous 95% bound (Bonferroni over
the 29 planned SNRs). Confidence bounds are not calculated using task slots
as independent trials. At zero frame errors in a million frames, the
pointwise upper bound is approximately 3e-6. Threshold resolution in the
waterfall is 0.02 dB; no continuous threshold is inferred between points.

```sh
conda run -n torch28 python itw2027/fixed_task/conventional_full.py generate --out itw2027/fixed_task/results/conventional_million_rc_3_5_n_t_60
bash itw2027/fixed_task/submit_conventional_full.sh itw2027/fixed_task/results/conventional_million_rc_3_5_n_t_60
```
