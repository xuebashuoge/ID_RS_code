# Noisy-only nt=60 campaign

Only physical tag length/packing change from the preceding noisy campaign:
nt=60, G=360, Nb=64800, neff=180. BFC payload Ni=21600 and LDPC rate 1/3
are unchanged. Fixed m values remain ID 100000, rank 5000, exact 100.
r=30, T=2^30, K=ceil(m/30); deterministic message padding is handled before
RS evaluation. Only sampled RS positions are evaluated; no full T table is
allocated and no noiseless enumeration is run.

Use the original 37-point SNR grid and 10000 frames per function/scheme/SNR.
Every frame has 180 positive and 180 negative tasks. Conventional exact
transmission retains its original LDPC rate 5/6 as requested by changing
only nt/G: the 36000 message bits are followed by 18000 deterministic zeros
in its 54000-bit information block. Decisions use only recovered message
bits; FER counts any error in the entire LDPC information block, including
padding. Both methods use the same 64800 BPSK symbols and Es/N0 definition.

New source seed group 3, same fixed ID target, matched source samples and
noise seeds between the new BFC/conventional schemes. No source bank from
nt=40 is reused. Legacy manifests keep nt=40,G=540 defaults.

All new bank/results filenames and directories include suffix _n_t_60.
Raw MAT output retains separate FN, FP, FER, balanced task error, counts,
per-frame data, parameters, seeds, LDPC payload/padding dimensions and runtime.
No plotting, noiseless, or postprocessing jobs are submitted.

Submission: 20-minute smoke test (2 CPUs/4 GB), followed by 12 source-bank
jobs (8 CPUs/4 GB/2 h, up to 12 concurrent), then 592 channel jobs (8 CPUs/
4 GB/1 h, up to 32 concurrent). Each shard has 2500 frames. Checkpoints and
runtime guards remain enabled. Internal bank/channel guards are 110/50 min.

```sh
conda run -n torch28 python itw2027/fixed_task/noisy_nt60.py --base itw2027/fixed_task/results/production --out itw2027/fixed_task/results/production_n_t_60
bash itw2027/fixed_task/submit_noisy_nt60.sh itw2027/fixed_task/results/production_n_t_60
```
