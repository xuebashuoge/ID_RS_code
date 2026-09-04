# Noisy-channel paper results

The publication-strength data are the fixed-sample belief-propagation runs in
`results/noisy_channel_confirmatory_bp/waterfall` (66 points) and
`results/noisy_channel_confirmatory_bp/rate_pareto` (60 points). Every point
uses 2,500 independent LDPC frames. The waterfall fixes `N_b=64800` and
`R_c=1/2`; the rate-pareto sweep keeps `N_b=64800` and varies `R_c`.

Run the non-destructive organizer from the repository root with MATLAB:

```matlab
compile_noisy_channel_publication_results();
```

Alternatively, submit only the lightweight post-processing job:

```bash
sbatch noisy_channel_publication_compile.slurm
```

This writes a complete manifest, finite-error diagnostic table, a preselected
1.5-dB operating-point table, a compression/rate table, and figures below
`results/noisy_channel_publication/confirmatory_bp`.

`cfg.bfc.E2=0.1` is the inner RS-tag exponent `E_{2,t}`. The exponent with
respect to effective physical channel uses is `E_{2,eff}=R_c E_{2,t}`; it is
0.05 for the fixed-rate waterfall. Both are exported explicitly.

Zero-event markers use the one-sided 95% bound at the independent LDPC-frame
cluster level. The older tuple-level rule-of-three is retained only in the
legacy CSV field for provenance and should not be cited as channel-error
precision.

The adaptive historical sweeps under `results/noisy_channel_tradeoffs` are
pilot data. The 200-frame LDPC calibration validates normalization and decoder
behavior but is not used for the paper's inferential claims.

The reproducibility Slurm requests were right-sized from the saved job
statistics: confirmatory point jobs used at most about 1.4 GB and 13.5 hours,
source-bank jobs used at most about 20.2 GB and 6.5 hours, and calibration jobs
used about 1.1 GB and at most 2.5 hours. The revised requests retain substantial
headroom (8 GB/18 hours, 32 GB/10 hours, and 8 GB/4 hours, respectively).
