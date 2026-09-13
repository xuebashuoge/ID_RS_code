# Figure 2 audit and matched-length rerun — 13 September 2026

## The apparent rank-only errors were largely a plotting defect

The old plotting helper replaced zero observations with NaN and drew lines without markers. A nonzero observation surrounded by zeros had no line segment and was invisible. In particular, ID at 1.8 dB and threshold at 1.5/1.9 dB were present in the saved results but not visible. Adjacent nonzero rank points did produce segments. This was an error in our presentation, not evidence that only rank's channel code fails.

| SNR (dB) | ID failed frames / FN count | Rank failed frames / FN count | Archived threshold n_t=42 failed frames / FN count |
|---|---:|---:|---:|
| 1.5 | 0 / 0 | 0 / 0 | 1 / 381 |
| 1.6 | 0 / 0 | 1 / 5 | 0 / 0 |
| 1.7 | 0 / 0 | 1 / 46 | 0 / 0 |
| 1.8 | 1 / 1 | 0 / 0 | 0 / 0 |
| 1.9 | 0 / 0 | 1 / 6 | 2 / 13 |
| 2.0 | 0 / 0 | 1 / 1 | 0 / 0 |

Each entry uses 2,500 frames. Counts at different SNRs should not be pooled as estimates of a single FER. `figure2_frame_audit.csv` and `failed_frame_events.csv` preserve the full audit. Regenerate with `python itw2027/scripts/audit_figure2.py` in conda environment torch28.

The corrected plot has a marker for every observation. Zeros are drawn at zero using a linear segment below 1e-6 and log scaling above it. The first-zero confidence-limit triangles were an unnecessary visual convention and have been removed. Their statistical meaning was an upper limit, not an error observation. Confidence limits remain in the tables. The regression test explicitly checks the pattern [0, positive, 0].

## Why equal channel codes can have different empirical failures

ID and rank use exactly the same DVB-S2 parity-check matrix, rate, 64,800-symbol length, 50-iteration BP decoder, payload rate, batch size, and SNR grid. Their point RNG seeds also coincide. However, they transmit different encoded information words. The old channel model adds the same physical Gaussian noise draw to different BPSK sign patterns. Relative to the transmitted signs, the noise realizations differ, so error locations and frame outcomes need not match point by point.

For a linear code with symmetric BP on BPSK-AWGN, this does not imply different underlying FER distributions. `test_awgn_codeword_symmetry.m` verifies identical decoded information-bit error masks for two distinct random codeword sets when their AWGN is sign-aligned. The test passes for eight codeword pairs at each of 0, 0.8, and 1.5 dB. This diagnoses the distinction between common physical noise and common sign-normalized noise; it does not replace the finite-frame statistical evidence with a proof about arbitrary implementations.

The archived n_t=42 threshold has a different seed and a small padding loss. The new matched-length run removes both parameter differences, although different BPSK codeword signs still mean frame outcomes need not coincide. No function-dependent LDPC algorithm or code rate was found.

## A channel-frame error does not force a false negative

The implication is FN => a corrupted payload frame, not its converse. Errors can affect only negative-query slots, or a corrupted positive tuple can still lie inside its Boolean decision region. The saved rate-sweep threshold result at Rc=2/3, 1.5 dB, frame 1809 has a payload frame error and **zero FN**. Thus equality between FER and FN would be wrong even in the existing observations. FN counts also differ drastically across failed frames: one failure can produce one FN or hundreds.

## Are 2,500 frames sufficient?

They resolve the waterfall and provide the existing paired collision-floor comparison, but not a precise FER near 1e-4. The FER estimate changes by 1/2500=4e-4 per failed frame. With zero failures, the one-sided exact 95% upper limit is

`1 - 0.05^(1/2500) = 0.00119757596`.

At true FER 4e-4, observing zero failures in 2,500 frames has probability about 36.8%; at 1e-4 it is about 77.9%. A few isolated failures and zeros are therefore unsurprising. More samples will improve estimation, not guarantee a monotonic empirical trace.

For a high-SNR precision study, preselect a small set of SNRs instead of uniformly extending all 22 points. Around FER=1e-4, 100,000 frames give only ten expected failures (roughly 32% relative standard error); one million frames give about 100 (roughly 10% relative standard error). About 29,956 zero-failure frames would be required to put a one-sided 95% upper bound below 1e-4. These are frame-level statements, not precision claims based on millions of packed tuples. A modest extension to 10,000 frames is useful as a check, but does not make 1e-4 FER precise.

Recommendation: first replace the mismatched threshold data with the fixed 2,500-frame n_t=40 run and inspect the corrected plot. Do not launch a million-frame campaign just to remove a plotting artifact. If the paper will compare high-SNR LDPC reliability quantitatively, then add a separate predeclared, larger frame experiment at selected SNRs. No such extension was submitted here.

Statistical reference: [NIST exact binomial confidence intervals](https://itl.nist.gov/div898/handbook/prc/section2/prc241.htm). Decoder interface: [MathWorks ldpcDecode](https://www.mathworks.com/help/comm/ref/ldpcdecode.html).

## Submitted matched-length experiment

- Function: exact-threshold, beta=2, n_t=40, inner E=0.1.
- Parameters: r=20, T=1,048,576, K=6, m=120, S=7,140.
- LDPC: N_b=64,800, N_i=32,400, G=810, no padding, n_eff=80.
- SNR: 0.5:0.1:2.6 dB; 2,500 frames per point, same as ID/rank.
- Server run directory: `/home/yangshuo/Git/itw2027_nt40_20260913`.
- Bank array: **30503621**, 8 CPUs, 16 GB, 6 hours.
- Point array: **30503622**, 22 tasks, concurrency 4, 8 CPUs/8 GB/14 hours per task; dependent on the bank.
- Results: `itw2027/results/source/noisy/threshold_nt40/` under the run directory.

This is an isolated copy; neither existing server checkout was switched or modified. The matched-length result is pending, not yet used in the corrected legacy preview. Resubmission script: `itw2027/slurm/submit_threshold_nt40.sh`. Do not resubmit it while these jobs are active.

After all 22 points complete, copy the `threshold_nt40/` tree into the local `itw2027/results/source/noisy/`, run `export_evidence`, then rebuild. The builder requires all 22 replacement points and selects them instead of the old threshold waterfall; it preserves the original n_t=42 archive and rate-sweep data. The parameter CSV/table updates automatically. The manuscript prose about 18 padding bits/84.0467 uses must then be updated to no padding/80 uses; it remains explicitly marked pending in the draft snippet.
