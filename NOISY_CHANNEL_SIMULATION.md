# Concatenated BFC/LDPC noisy-channel simulation

The noisy-channel path groups independent short BFC transmissions
`(u,c_u)` into a DVB-S2 LDPC information block. Both the position index and
the selected RS symbol are protected by the same channel code.

## Quick local check

The default profile is intentionally limited to `n=8` and two LDPC frames:

```matlab
test_noisy_channel_components
main_noisy_channel_sim
```

Outputs are written below `results/noisy_channel/local_smoke`.

## Server sweep

Submit the dependent source-bank, channel, and plotting arrays from the
repository root:

```bash
bash submit_noisy_channel_sweep.sh
```

The full profile uses the `n_list` in `noisy_channel_config.m`, AWGN and
symbol-wise flat Rayleigh fading, and `Eb/N0=0:1:10` dB. Eight concurrent
jobs request eight CPUs and 32 GB each. Completed point files are detected
and reused.

For a smaller server validation, run the `server_pilot` profile serially
or adapt the array entry point:

```matlab
main_noisy_channel_sim('server_pilot')
```

## Receiver and energy conventions

- The RS evaluation length is `L=2^r`. The one-based index mapping is the
  extended-RS ordering `1 -> 0`, `2 -> 1`, ..., `L -> alpha^(L-2)`, so every
  `r`-bit index pattern is valid. The source-bank and decoder paths evaluate
  only the requested point indices and do not materialize the complete table.
- DVB-S2 rate-1/2 LDPC uses a 32,400-bit information block and a
  64,800-bit codeword.
- BPSK maps zero to `+1` and one to `-1`.
- `Eb/N0` is referenced to actual BFC tuple payload bits. Padding is
  included in the transmitted LDPC frame but excluded from the effective
  payload rate.
- AWGN requires no equalizer.
- Rayleigh fading assumes perfect CSI and uses the coherent soft metric
  `4*real(conj(h).*y)/N0`. This is the required single-tap compensation;
  it is more stable than explicitly dividing by small fading coefficients.
- Timing, carrier and frame synchronization are perfect. Pilot-based
  estimation, multipath equalization, CRC and retransmission are not part
  of this first model.

## Memory strategy

The code never materializes complete RS codewords or all `L` evaluation
points. Source tuples and their noiseless BFC decisions are generated once
per `n` and reused across channel points. At the receiver, unchanged tuples
reuse the cached decision; only corrupted tuples enter the decoding-region
membership test. That test is chunked according to
`cfg.memory.region_working_mb`.

The source distribution is balanced between Boolean outputs zero and one
so false-positive and false-negative rates are both measurable. The
reported end-to-end error is reweighted to the uniform-message prior using
`S/2^m`.

## Rate and channel-use conventions

The simulation saves four distinct quantities; they should not be called by
the same generic "effective rate" name:

- `ldpc_code_rate = K_LDPC/N_LDPC` is the nominal channel-code rate.
- `ldpc_payload_rate = G*n/N_LDPC` also accounts for tuple padding. It is
  the rate used for payload-referenced `Eb/N0` noise scaling.
- `channel_uses_per_bfc_decision = N_LDPC/G` is the average number of BPSK
  channel uses assigned to one independently decoded BFC tuple.
- `parallel_bfc_rate = G*(n*R_BFC)/N_LDPC` is the sum of the BFC rate
  numerators per physical channel use. For the identification function,
  this is `G*log2(m)/N_LDPC`, approximately `R_c*log2(m)/n` when there is
  no padding.

Here `G=floor(K_LDPC/n)`. A 64,800-bit rate-1/2 LDPC frame therefore packs
`32400/n` tuples and consumes 64,800 BPSK channel uses. The packed tuples
are independent BFC decisions; the frame is not treated as one
identification message with message space `N^G`.

`plot_noisy_channel_results` retains the detailed per-`n` figures and also
creates `noisy_channel_compare_n_<channel>.png`, which compares all saved
values of `n` on common `Eb/N0` axes. `replot_noisy_channel_drop_zeros`
creates the same recommended comparison while omitting zero-observation
points rather than adding a display floor.

## Controlled tradeoff sweeps

Two experiment families keep the interpretation of the x-axis controlled:

```matlab
% Safe two-frame local checks; defaults to the identification function.
main_noisy_channel_e2_sweep
main_noisy_channel_ldpc_rate_sweep

% Full AWGN sweeps for n=[4 6 8].
main_noisy_channel_e2_sweep('server_full', 'id')
main_noisy_channel_ldpc_rate_sweep('server_full', 'id')
```

The default E2 sweep uses `E2=[0.05 0.10 0.15 0.20]`, keeps the LDPC
rate at 1/2, and resolves the waterfall on `Eb/N0=0:0.25:3` dB. `K` is
recalculated from the maximum-rate rule for every `(E2,n)` point. The
default channel-code sweep uses DVB-S2 rates
`[1/3 2/5 1/2 3/5 2/3]`, fixes `E2=0.10`, and therefore keeps the BFC
parameters fixed for each `n`; it uses `Eb/N0=0:0.25:5` dB because the
low-rate FER waterfalls occur later.

Every setting in a tradeoff sweep uses the same `n` grid, and configuration
construction rejects any point with `K<=1`. Defaults are chosen to reuse the
source banks already generated by the original server sweeps: `id=[4 16]`,
`exact-threshold=[36 42]`, and `rank=[24 32 40]`. A custom `BFC_N_LIST`
remains supported, but new `n` values require new banks.

Monte Carlo stopping is class-aware. A point stops after the minimum number
of frames when both FP and FN have either reached their target counts or
their corresponding class has reached `max_trials_per_class`. For the full
profile the defaults are 200 FP, 200 FN, and one million trials per class.
Hard limits of 5,000 frames and 48 hours prevent a zero-error class from
running indefinitely. With zero observations, one million class trials
correspond to the rule-of-three one-sided 95% upper bound `3e-6`.

Changing the SNR grid, stopping rule, saved metrics, or plots does not change
the BFC source distribution. An existing bank is reused whenever its
`(function,n,E2,K,m)` metadata are compatible and it contains at least the
number of tuples required by `max_frames`. Existing version-1 point results
are rerun from those banks once to add the transition decomposition.

Each aggregate image has one tile for each `n`. Separate images report the
balanced average error, FPR, FNR, and `max(FPR,FNR)`. The detailed per-`n`
outputs also include LDPC BER, FER, tuple error, and the exact decomposition

`P_end = P_intrinsic + P_channel-created - P_channel-corrected`.

Aggregate views include error versus `Eb/N0`, error versus parallel BFC rate
with SNR as the line parameter, and
for the channel-code-rate sweep, error versus physical channel uses per BFC
decision with SNR as the line parameter. Outputs are below
`results/noisy_channel_tradeoffs`.

The corresponding server submissions are:

```bash
bash submit_noisy_channel_tradeoff_sweep.sh e2 id
bash submit_noisy_channel_tradeoff_sweep.sh ldpc_rate id
```

Pass more than one function type to submit independent job chains without
editing `noisy_channel_config.m`. Add `=n1,n2,...` to give each function its
own `n` list. For example:

```bash
bash submit_noisy_channel_tradeoff_sweep.sh e2 \
    id=4,16,32 exact-threshold=36,42 rank=24,32,40
```

Each function type and `n` list are captured in the submitted jobs through
`BFC_FUNC_TYPE` and `BFC_N_LIST`. Results are written under separate
function-type directories. A function without `=...` uses its
bank-reuse default listed above; omitting all function types uses `id`.

### Traditional error-versus-SNR replot

After a sweep has produced point files, generate one conventional
error-versus-`Eb/N0` image for every E2 or LDPC-rate setting. Curves within
an image compare the simulated values of `n` and show physical channel uses
per BFC decision in the legend:

```matlab
replot_noisy_channel_tradeoff_by_setting('e2', 'server_full', 'id')
replot_noisy_channel_tradeoff_by_setting( ...
    'ldpc_rate', 'server_full', 'id')
```

The default y-axis is the balanced end-to-end BFC decision error
`(FP+FN)/trials`. Optional metrics are `weighted`, `tuple`, `ber`, and `fer`.
Observed zero-error points are omitted by default because they cannot be
drawn on a logarithmic axis. To show the rule-of-three upper-bound display
value instead, use:

```matlab
replot_noisy_channel_tradeoff_by_setting( ...
    'e2', 'server_full', 'id', 'balanced', 'rule_of_three')
```

Submit the same replot as a standalone SLURM job with environment variables:

```bash
# E2 sweep, default balanced BFC decision error, zero points omitted
sbatch --export=ALL,BFC_SWEEP_TYPE=e2,BFC_SWEEP_PROFILE=server_full,\
BFC_FUNC_TYPE=id noisy_channel_tradeoff_replot.slurm

# LDPC-rate sweep, displaying zero observations at the rule-of-three bound
sbatch --export=ALL,BFC_SWEEP_TYPE=ldpc_rate,BFC_SWEEP_PROFILE=server_full,\
BFC_FUNC_TYPE=id,BFC_ERROR_METRIC=balanced,BFC_ZERO_MODE=rule_of_three \
noisy_channel_tradeoff_replot.slurm
```

The accepted values of `BFC_ERROR_METRIC` are `balanced`, `fpr`, `fnr`,
`max`, `weighted`, `tuple`, `ber`, and `fer`. `BFC_ZERO_MODE` is `omit`
or `rule_of_three`.
