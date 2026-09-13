# Figure 2 audit and matched-length rerun — 13 September 2026

**Completed and imported:** all 22 replacement points passed the parameter, fixed-frame, and paired-error checks. Figure 2 and the parameter table now use n_t=40 for every function. The older threshold data in the first diagnostic table below remain labelled as archival.

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

The drawing now separates each function into its own row, with FN/FER on the left and FP/reference/diagnostic on the right. Each quantity has a legend. No uncertainty shading is drawn; the confidence intervals remain in the tables. Observed FP uses points over the noiseless reference instead of two coincident lines. The corrected plot has a marker for every observation. Zeros are drawn at zero using a linear segment below 1e-6 and log scaling above it. The first-zero confidence-limit triangles were an unnecessary visual convention and have been removed. Their statistical meaning was an upper limit, not an error observation. Confidence limits remain in the tables. The regression test explicitly checks the pattern [0, positive, 0].

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

The matched-length replacement is now complete. The corrected plot still shows sparse residual high-SNR events in all three functions; this does not establish a function-dependent FER. Do not launch a million-frame campaign just to remove a plotting artifact. If the paper will compare high-SNR LDPC reliability quantitatively, then add a separate predeclared, larger frame experiment at selected SNRs. No such extension was submitted here.

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

The bank and all 22 point jobs completed successfully. The imported results replace the old threshold waterfall in the selected Figure 2; the n_t=42 data and the historical rate-sweep remain archived. The parameter table and paper prose now describe 810 tags, no padding, and 80 effective channel uses for every function. No job resubmission is needed.

The new threshold has FP 0.00680691358 at 1.5 dB and no observed FN or failed frames there. It has one failed frame with 21 FN at 1.7 dB, two failed frames with 86 FN at 2.0 dB, one failed frame with 134 FN at 2.1 dB, and one failed frame with one FN at 2.4 dB. These isolated observations are now all visible. Its finite rates are R_t=0.1726722649 and R_eff=0.08633613245; the uniform noiseless FP bound is 0.03404617310.

The full matched comparison is in `results/processed/tables/matched_nt40_comparison.csv`; the 148-point archive contains the 126 selected noisy points plus the 22 superseded threshold waterfall points. All 2,500-frame samples remain separate.
