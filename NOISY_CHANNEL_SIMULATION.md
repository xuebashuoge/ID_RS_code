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

The full profile uses `n=44:2:50`, AWGN and symbol-wise flat Rayleigh
fading, and `Eb/N0=0:1:10` dB. Eight concurrent jobs request eight CPUs
and 32 GB each. Completed point files are detected and reused.

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
