# Spartan pilot, 2026-09-17

Source commit: 892ddbb. Server checkout: /home/yangshuo/Git/itw_gpt.
All jobs completed successfully: smoke 30687188; source banks 30687189;
76 channel points 30687190; three noiseless timing points 30687191.
Each channel point used 100 frames, G=540, 270 tasks per class per frame.

Observed LDPC FER:

| Scheme | SNR Es/N0 dB | FER |
|---|---:|---:|
| ID BFC, rate 1/3 | -4.5 | 0.51 |
| Rank BFC, rate 1/3 | -4.5 | 0.58 |
| Exact BFC, rate 1/3 | -4.5 | 0.61 |
| All BFC | -4.0 | 0/100 frames |
| Exact conventional, rate 5/6 | 1.5 | 1.00 |
| Exact conventional, rate 5/6 | 2.0 | 0.20 |
| Exact conventional, rate 5/6 | 2.5 | 0/100 frames |

The BFC and conventional waterfalls are therefore separated as expected.
Exact BFC paired noiseless FP was 136/27000 = 0.005037. ID had zero
observed FP and rank one, so their floors are not resolved by the pilot.
Zero observed errors must not be interpreted as zero underlying error.

Production grid: -4.9:0.1:-3.6 and 1.1:0.1:2.9, plus anchors -5.5, -3,
0, 3.5 dB. Shared grid across schemes for comparison. Use 10000 frames
for BFC at -4.4,-4.3,-4.2 dB and conventional at 2.1,2.2,2.3 dB;
2500 elsewhere. Source group 2 is independent of pilot group 1.

Pilot source-bank jobs took 2:06-2:38; channel jobs 0:30-1:39. Peak bank
memory in Slurm was about 1.3-1.5 GiB. Noiseless enumeration of 512 positions
for two negatives took 3.3 s (ID), 0.8 s (rank), and 0.7 s (exact), excluding
startup. Production position sharding and checkpointing bound job size.
