# Presentation and theorem alignment

**Matched-length revision complete:** Figure 2 uses n_t=40 for all three functions. The 22 new threshold points are validated; the older n_t=42 run remains archived. See `figure2_revision.md`.

## Space budget and primary story

Use two wide, two-panel figures and one small three-row table, with about 250–350 words of discussion. Allocate approximately one content page overall, subject to the full manuscript's float placement. If space is tighter, use only the error panels in the paper and move the rate-sequence panel to the linked preprint; keep the finite-rate table. Do not add a separate third rate/latency figure.

ITW 2027 currently allows five content pages and an optional sixth references-only page, with no supplementary pages in the EDAS submission; a linked preprint may contain supplementary material. Source checked 12 September 2026: [official author instructions](https://2027.ieee-itw.org/information-authors-0). A full manuscript page count has not been checked here.

## Noiseless subsection: Figure 1

**Panel (a).** Horizontal axis: tag length `n_t=24,26,...,40` bits. Vertical axis: exact false-positive probability for a fixed negative message, logarithmic scale. Colors: ID, fixed rank 20, exact-threshold beta=2. Solid curves: medians over independently sampled negative messages; bands: fifth–95th percentiles; dotted curves: largest sampled values; dashed curves: `B=S(K−1)/T`. Band boundaries at exact zero are clipped to the labelled plotting floor; underlying zeros remain in the table. The sample comprises 2,000 messages per setting except ID at n_t=38 and 40, with 200 each. For each message, all T indices are enumerated, so there is no position-sampling uncertainty.

This tests the finite proposition at implemented RS parameters and shows how conservative its uniform guarantee can be for specified functions. FN is zero by construction and is checked in the deterministic tests, so an identically-zero FN curve would consume space without information. The three functions are not matched at fixed m; each uses the same inner exponent E=0.1 to expose supported-message/error tradeoffs. Threshold steps come from integer K, not an error in asymptotic scaling. Percentile bands describe variation among messages, not confidence intervals.

The adversarial results belong in one sentence or an optional support table: 22 tested arbitrary supports attain `S(K−1)/T` exactly. Those supports have the same **sizes** as the named-function cases, but need not be the rank or exact-threshold functions. Five ID cases n_t=32,...,40 were skipped by cost guards. This is a strong check of the algebraic mechanism for the unrestricted support family, not proof of tightness for each named function.

**Panel (b).** Horizontal axis: tag length 24–4096, logarithmic scale. Vertical axis: finite exponential rate `R_t=log2(m)/n_t`. Same three colors. Solid: E=0.1; dashed: E(n_t)=1/sqrt(n_t). Horizontal dotted references: 1/2 and 1/6.

This distinguishes the finite rate/error tradeoff from the asymptotic achievability claim. Fixed E gives limits `(1/2−E)/(1+beta)` for threshold and `1/2−E` for fixed weights. A fixed E=0.1 curve cannot converge to 1/2 or 1/6. In the second sequence E tends to zero while n_t E tends to infinity, so the error upper bound still vanishes and the advertised rates are approached. Finite rates can exceed their asymptotic benchmarks because of the log(n_t)/n_t term; this is not a capacity violation. These curves are deterministic evaluations of a certified design, not Monte Carlo simulations at enormous fields.

## Noisy subsection: Figure 2

Use BPSK-AWGN, length 64,800 DVB-S2 LDPC, rate 1/2, BP with at most 50 iterations and early termination. Three function settings: ID n_t=40, rank n_t=40, exact-threshold n_t=40. Every SNR point uses 2,500 fixed frames; the grid is 0.5–2.6 dB in steps of 0.1 dB. `E_b` is energy per occupied **payload** bit, including the exact packing efficiency in the noise normalization.

**Panel (a).** Horizontal axis: E_b/N_0 in dB. Vertical axis: error probability, logarithmic above 1e-6 with a linear segment down to zero. Solid: class-conditional empirical FN for each function. Dashed: measured payload FER. Shading: saved 95% frame-cluster percentile-bootstrap intervals for FN. Every point has a marker, including isolated nonzero observations. Zero estimates are plotted at zero in the linear segment; upper confidence limits remain in the tables rather than being substituted for observations.

This demonstrates the channel-induced FN mechanism and the waterfall. Residual errors and nonmonotonic rare-event estimates are preserved. Packing produces many decisions per frame but cannot turn 2,500 independent frames into millions of independent channel trials.

**Panel (b).** Same axes. Solid: empirical conditional FP. Dotted: paired noiseless-bank FP. Dashed: `min(1,B+observed payload FER)`, explicitly labelled a **diagnostic**, not a certified maximal-error bound. Shading: frame-cluster FP intervals. This shows the intrinsic collision floor and the separate channel contribution. Channel errors can also remove an intrinsic false positive, so noisy FP need not exceed noiseless FP at every SNR.

The source bank is shared across SNRs within each experiment: identical high-SNR floors are not independent replications. The old waterfall and rate-sweep banks differ and are not pooled. The rigorous finite-sample audit checks each frame: coded FN is confined to payload-error frames, and coded FP on a payload-correct frame equals the corresponding noiseless FP. It also checks `FP <= intrinsic FP + bad-frame negative trials` and `FN <= bad-frame positive trials` using actual class counts. Empirical frame-error frequencies are not the theorem's supremum over information words; this distinction must appear in the text.

## Table I: finite rates and packing

Rows: the three representative function settings above. Columns in the compact LaTeX table: function, n_t, m, exact S, R_t, G, R_eff. State N_b=64800, N_i=32400 in the caption; n_eff is 80 for all three functions, with G=810 and no padding. The CSV also includes K, T, B, padding, asymptotic references, and the packing gain G relative to sending one tag per same physical LDPC frame. The large integers in this table are the supported **message lengths in bits**, not message counts 2^m.

This table makes the rate definition auditable, exposes rounding/padding, and quantifies why packing is useful without a costly additional experiment. A finite rate is tied to the shown nonzero error certificate; it is not the computation capacity.

## Optional material, excluded from the main page budget

- `optional_rate_tradeoff.pdf`: x=n_eff, y=max(empirical FP, empirical FN), at 1.5 dB over channel rates 1/3, 2/5, 1/2, 3/5, 2/3. This optional historical sweep still uses threshold n_t=42 and is not part of the matched-length Figure 2. This is a tradeoff for the sampled ensemble, not a maximal error or an optimization proof. No simulated full-message transmission baseline is claimed.
- `finite_rate_at_1percent.csv`: x=n_t and y=largest certified finite R at B<=0.01; aligned and padded messages are distinguished. It solves the exact support-size certificate within the balanced r,T allocation. It is not a global optimum over every RS allocation.
- Adversarial table: parameter/weight, n_t, expected and observed root counts, verified/skipped status. Do not label its arbitrary supports as actual rank/threshold functions.
- No new Rayleigh, broad SNR, or large-field brute-force sweeps are needed for the current claims.
