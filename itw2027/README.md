# ITW 2027 simulation package

This branch implements **two paper figures and one three-row parameter table** for the supplied theorems. All selected empirical results are available and validated. No new large channel simulations are needed for these figures. The rate curves and the integer finite-rate optimization are new deterministic calculations. The MATLAB scripts also support regeneration on the server.

Start with [the presentation plan](docs/presentation_plan.md), [the audit](docs/evidence_audit.md), and [the Slurm resource plan](docs/server_jobs.md). LaTeX subsection text and captions are in [paper_results.tex](docs/paper_results.tex). The existing untracked `paper/` directory was left untouched.

## Outputs

- `results/processed/figures/figure1_noiseless.{pdf,png}`: error distributions and rate sequences.
- `results/processed/figures/figure2_noisy.{pdf,png}`: separate false-negative and false-positive behavior.
- `results/processed/tables/paper_parameters.{csv,tex}`: three representative configurations, packing and rates.
- `results/processed/tables/finite_rate_at_1percent.csv`: largest certified message and rate within the balanced RS parameter choice, including odd lengths and padding; aligned and unrestricted message lengths are distinguished.
- `results/processed/tables/rate_sequences.csv`: fixed-exponent and vanishing-exponent calculations, through tag length 4096. These large lengths are analytical evaluations, not implemented GF simulations.
- `results/processed/tables/noiseless_distribution.csv`: 27 settings, exact position enumeration for each sampled negative message.
- `results/processed/tables/noisy_all_points.csv`: 126 points, separate FP/FN, frame statistics, rates, padding, intervals, paired-error checks.
- `results/processed/figures/optional_rate_tradeoff.{pdf,png}`: optional rate sweep at 1.5 dB, omit from the page-limited version.
- `results/evidence/`: compact saved MAT files, including per-frame data for reanalysis. No server access is needed to rebuild the figures.
- `results/processed/tables/reuse_manifest.csv`: exact original server paths, byte counts, SHA-256 hashes, and source-bank copy markings.

## Rebuild locally

Python uses the required `torch28` conda environment. Dependencies are `numpy`, `scipy`, and `matplotlib` (versions used: Python environment's NumPy, SciPy 1.16.2, Matplotlib 3.10.5). No HDF5 Python dependency is required.

```bash
conda run --no-capture-output -n torch28 python itw2027/scripts/test_rates.py
conda run --no-capture-output -n torch28 python itw2027/scripts/build_results.py
```

The builder fails on missing coverage, duplicate noiseless shard seeds, incorrect support sizes/rates, incomplete fixed-frame runs, or violated paired decoding identities. It does not silently replace missing empirical results with theory. `results/processed/validation.json` records the resulting coverage.

MATLAB Communications Toolbox and Parallel Computing Toolbox are required for simulation/component tests:

```bash
/Applications/MATLAB_R2025a.app/bin/matlab -batch "addpath('itw2027/matlab'); test_itw_integration"
```

The six small BP smoke points exercise ID, rank, and exact-threshold at 0 and 6 dB. They are validation tests, not additional paper observations. The log is saved in `results/integration_test.log`.

## Server use

From the repository root:

```bash
# Default and sufficient for all selected paper figures:
bash itw2027/slurm/submit.sh figures

# Preview the exact reusable files on unimelb, then copy when ready:
bash itw2027/scripts/copy_server_reuse.sh
bash itw2027/scripts/copy_server_reuse.sh --copy

# Optional: regenerate/validate the historical fixed-sample channel experiment.
# Existing compatible complete points are validated and skipped.
bash itw2027/slurm/submit.sh noisy waterfall
bash itw2027/slurm/submit.sh noisy rate_pareto
```

The copy helper is intended to run **on unimelb** in the new checkout. It leaves original server files untouched. No Slurm jobs were submitted during development. Full banks and original result files are ignored in Git; the small evidence files and all paper outputs are included.

For fully fresh noiseless regeneration, see the resource plan before `submit.sh noiseless`: it uses more, smaller shards and therefore generates a new negative-message sample. Do not pool the old sample and new sample without an explicit sampling design. Keep the regenerated dataset separate, replace the source input as one complete dataset, and export to a fresh evidence directory when evaluating it.

## Scientific conventions

For all three functions the finite exponential rate is `log2(m)/n_t`. With packing, it is `G*log2(m)/N_b`, where `G=floor(N_i/n_t)`, and `n_eff=N_b/G`. Exact-threshold has **exact** support `binom(m,beta)` for positive integer beta; `m^beta/beta!` is a conservative design envelope and asymptotic equivalent. Fixed rank 20 has support 21. Fixed rank and ID have asymptotic benchmark 1/2; beta=2 has benchmark 1/6. Multiply by asymptotic channel-code rate for the corresponding ideal packing benchmark.

The sample maximum is not a maximal-error estimate over all messages/functions. Observed payload FER is not the theorem's maximal channel-code FER. Large supported m does not imply short decoding latency: the entire 64,800-symbol LDPC frame is still decoded.
