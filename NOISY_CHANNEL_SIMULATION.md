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

- The RS evaluation length is `L=2^r-1`; the unused all-one index pattern
  is treated as an erasure.
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

The default E2 sweep uses `E2=[0.05 0.10 0.15 0.20]` and keeps the LDPC
rate at 1/2. `K` is recalculated from the maximum-rate rule for every
`(E2,n)` point. The default channel-code sweep uses DVB-S2 rates
`[1/3 2/5 1/2 3/5 2/3]`, fixes `E2=0.10`, and therefore keeps the BFC
parameters fixed for each `n`.

Each aggregate image has one tile for each `n`. It includes error versus
`Eb/N0`, error versus parallel BFC rate with SNR as the line parameter, and
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
    id=4,8,16,32 exact-threshold=12,16,20 rank=8,12,16
```

Each function type and `n` list are captured in the submitted jobs through
`BFC_FUNC_TYPE` and `BFC_N_LIST`. Results are written under separate
function-type directories. A function without `=...` uses `[4 8 16 32]`;
omitting all function types remains backward compatible and uses `id` with
that same list.
