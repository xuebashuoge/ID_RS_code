# Evidence audit and rate calculations

**13 September update:** the original Figure 2 omitted isolated nonzero points because it used line-only traces with NaNs at zeros. This is fixed. Upper-limit triangles are removed, actual zero estimates are drawn, and the n_t=40 threshold replacement is complete and selected for Figure 2. See `figure2_revision.md`; historical n_t=42 values below remain archival.

## Branches and source provenance

The new branch starts from `single_message` commit `aaa2424d8fc2a52c6926f45c170f8f0169db8df3`. The noisy simulation engine was copied into `itw2027/matlab/noisy/` from `noisy_channel_revised` commit `20ed9cd1a909836ab2907397c4c5ef7b9afa17e2`. It is isolated to avoid switching branches or replacing the noiseless functions. New wrappers validate compatible completed points, isolate result locations, and fail jobs that do not finish the fixed sample.

Server files were actually inspected and read on 12 September 2026, rather than inferred from old plots. Original file paths, sizes, and hashes appear in `reuse_manifest.csv`. The compact evidence contains all per-message collision counts and all noisy per-frame statistics. Noisy ID target vectors were removed only from the compact evidence to save space; they remain in the original server files and can be regenerated from the bank seed. All statistical reanalysis inputs are retained. The imported numerical engine (only trailing whitespace normalized) is indexed in `imported_code_manifest.csv`.

The noiseless raw files record their original simulation commit, including `a9eee201f38657977cb681e5b9d3278d38895de3`. Comparing that commit to the current noiseless branch showed changes only to README/Slurm scheduling within the inspected simulation paths, not the numerical implementation. The original saved commit for every shard is retained in `noiseless_runs.csv`.

## Reuse decisions

| Evidence | Inspection result | Decision |
|---|---|---|
| `single_message`: `conference_results/raw/finite_length/` on server | 33 complete files, 27 task/length cells; 2,000 samples normally, four 50-message shards for ID n=38 and 40 | Reuse collision counts and exact per-message probabilities; recompute quantiles and rates |
| `single_message`: `conference_results/raw/adversarial/` | 22 verified exact equalities; five explicit skipped ID cases | Reuse as arbitrary-support validation; retain skipped statuses |
| `single_message`: `rate_exponent/` | Old finite-rate formulas and fixed-E sweeps | Preserve source provenance; replace paper rate plot with both fixed-E and vanishing-E sequences |
| `noisy_channel_revised`: `noisy_channel_confirmatory_bp/waterfall/` | 66 complete BP points, 2,500 frames each, three families | Reuse all points; separate FP/FN and correct the uncertainty interpretation |
| `noisy_channel_confirmatory_bp/rate_pareto/` | 60 complete BP points, 2,500 frames each, five code rates | Reuse in optional figure and full saved table; do not pool with waterfall bank |
| Six confirmatory source banks | Correct extended zero-first RS mapping and matching family/parameters | Mark for server copy; do not regenerate by default |
| Old `results_temp/fixed_msg_*`, adaptive noisy sweeps, min-sum plots, Rayleigh sweeps, 200-frame calibration | Different sampling/decoder/design or pilot role | Exclude from the selected evidence; retain old branch files for history |
| Existing paper-ready PNG/PDF/summary tables | Old plot focus/normalization/uncertainty conventions | Rebuild selected presentation from compact evidence |

The six historical bank source paths are listed below. The selected threshold waterfall now uses the additional bank at `/home/yangshuo/Git/itw2027_nt40_20260913/itw2027/results/source/noisy/threshold_nt40/source_banks/exact-threshold/E2_0p1/bank_n_40.mat`.

```text
/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/waterfall/source_banks/id/E2_0p1/bank_n_40.mat
/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/waterfall/source_banks/rank/E2_0p1/bank_n_40.mat
/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/waterfall/source_banks/exact-threshold/E2_0p1/bank_n_42.mat
/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/rate_pareto/source_banks/id/E2_0p1/bank_n_40.mat
/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/rate_pareto/source_banks/rank/E2_0p1/bank_n_40.mat
/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/rate_pareto/source_banks/exact-threshold/E2_0p1/bank_n_42.mat
```

Keep `waterfall` and `rate_pareto` distinct at the destination. Their bank lengths and intrinsic collision estimates differ. The full tree-copy helper preserves that layout.

## Exact finite rate and asymptotic meaning

For any instantiated code, the largest supported R under L(R,n)=2^(Rn) is:

- Noiseless: `R_t = log2(m)/n_t`.
- Packed noisy: `R_eff = log2(m)/(N_b/G) = G log2(m)/N_b`.

Use `S=1` for ID, `S=rank+1=21` for fixed rank 20, and **S=binom(m,beta)** for exact-threshold. A fixed positive integer beta gives `binom(m,beta) ~ m^beta/beta!`. Replacing the exact finite support by the latter in measured tables would be incorrect. It is nevertheless a conservative upper envelope for design, used by the legacy K calculator:

```text
r=n_t/2, T=2^r, A=2^[n_t(1/2-E)]         (even n_t)
ID:              K=floor(A)
rank:            K=floor(A/21)
exact threshold: K=floor((beta! A/r^beta)^[1/(1+beta)])
m=rK, B=S(K-1)/T <= 2^(-n_t E).
```

The new `certificate()` instead finds the largest m within fixed balanced `r=ceil(n_t/2), T=2^floor(n_t/2)` satisfying the **exact** inequality

```text
S(m) (ceil(m/r)-1) <= epsilon T,  1 <= ceil(m/r) <= T.
```

It uses integer bisection and rational comparisons. The optional aligned case restricts m to multiples of r. For a padded code the inequality remains valid but equality of the worst-case bound need not be attainable by arbitrary full coefficient vectors. Small-grid brute-force tests independently validate the integer optimum.

For fixed E>0, the asymptotic rate of the conservative design is `(1/2−E)/(1+beta)`; use beta=0 for constant weights. To approach `1/[2(1+beta)]` with vanishing error, the plotted choice `E(n_t)=1/sqrt(n_t)` satisfies E→0 and n_t E→infinity. It yields an upper error bound `2^(-sqrt(n_t))`. No Monte Carlo is run at the enormous m values on this curve.

For noisy packing use `G=floor(N_i/n_t)`, `padding=N_i−G n_t`, and `R_eff=(G n_t/N_b) R_t`. The factor is the payload rate, not exactly R_c when padding is present. Asymptotically it tends to R_c when packing loss vanishes; then the benchmarks are R_c/2 and R_c/[2(1+beta)]. At fixed E=0.1 and R_c=1/2, the ideal effective exponent is 0.05; with padding the exact factor is the payload rate.

## Representative observations

At noiseless n_t=40:

| Function | m | Median exact FP | Largest sampled FP | Uniform B | Sample count |
|---|---:|---:|---:|---:|---:|
| ID | 1,310,720 | 9.5367e−7 | 3.8147e−6 | 0.0624990 | 200 |
| Rank (20) | 62,400 | 2.0027e−5 | 3.6240e−5 | 0.0624647 | 2,000 |
| Exact threshold beta=2 | 120 | 0.00678110 | 0.00703716 | 0.0340462 | 2,000 |

The current noisy threshold setting uses n_t=40, m=120 and hence the same parameters as the noiseless n_t=40 point. Its paired noisy-experiment reference uses a separate source bank. The older n_t=42, m=168 waterfall is archived and excluded from the selected figure.

At 1.5 dB in the matched-length noisy waterfall, FP is 2.9630e−6, 2.4691e−5, and 0.00680691 for ID, rank, and threshold, respectively. All three have zero observed FN and zero failed payload frames in 2,500 at this SNR. These are ensemble estimates, not worst-case error probabilities. Zero events do not establish zero channel error: the one-sided 95% frame-event upper bound is approximately 0.001198.

## Interpretation limits and checks

1. All 27 finite-length cells satisfy the exact algebraic bound for every sampled negative message. The sampled maximum is not a supremum over all messages or functions.
2. All 126 noisy points pass per-frame error identities. Correct payload decoding gives exactly the paired noiseless decisions. The class-weighted bad-frame event bounds FN and the extra possible FP contribution without inserting a G factor.
3. The original channel FER counts errors in occupied payload bits, excluding padding. It is therefore labelled **payload FER**. It is not the maximal full-information-word FER xi assumed by the theorem. `B+observed FER` is an empirical diagnostic only; no rigorous maximal-error curve is estimated from the Monte Carlo sample.
4. Confidence intervals use frame clusters. Nonzero-event bootstrap intervals with only one or a few contributing frames are necessarily unstable. Zero-event confidence limits in the saved tables use independent-frame resolution, never the legacy tuple-level rule of three. The revised plot shows the observed zero values directly. For unequal class counts in odd-G frames a conservative max-class-size/mean-class-size factor is included.
5. The original balanced source bank alternates positive/negative examples. It estimates class-conditional behavior for the specified functions. It is not uniform sampling from all 2^m inputs, nor worst-case query selection.
6. A 64,800-symbol physical frame remains the decoding unit. n_eff is amortized resource cost per decision, not an 80-symbol latency code. Packing gain G compares serving G tasks in one frame with using one otherwise identical frame per task; it is not a simulated throughput benchmark including computation and queuing.
7. The supplied draft's statement that the union bound is loose whenever S>1 is too strong. For unrestricted supports, disjoint K−1 root sets attain it when feasible. A safe sentence is: “The uniform bound may be conservative for a specified Boolean function because collision sets can overlap or have fewer than K−1 roots.”
8. Practical threshold beta is a positive integer. The polynomial-weight theorem may use real beta>0, but an exact-Hamming-weight Boolean query with noninteger beta is not defined.
