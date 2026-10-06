#!/usr/bin/env python3
"""Fresh 100,000-frame ID and exact-weight BFC task-error campaign."""
import argparse
from pathlib import Path

from campaign import save_json
from task_comparison import summarize


SNR_DB = tuple(round(-5.0 + i / 10, 1) for i in range(9))
FRAMES_PER_POINT = 100_000
SHARD_FRAMES = {'id': 1_000, 'exact': 2_500}


def generate(out):
    if out.exists():
        raise ValueError('Use a fresh destination; existing results must not be overwritten')
    tasks = []
    for family, m in (('id', 100_000), ('exact', 100)):
        shard_frames = SHARD_FRAMES[family]
        for snr_index, snr in enumerate(SNR_DB, 1):
            for first in range(1, FRAMES_PER_POINT + 1, shard_frames):
                shard = (first - 1) // shard_frames
                tasks.append(dict(kind='task_comparison', family=family,
                    scheme='bfc', m=m, ldpc_rate=1/3, nt=60, G=360,
                    frames_per_point=FRAMES_PER_POINT, frames=shard_frames,
                    first_frame=first, snr_db=snr, snr_index=snr_index,
                    source_seed=20261006, position_seed=20261007,
                    noise_seed=20261008, runtime_limit=6600,
                    output=(f'results/{family}_bfc_{snr:+06.2f}_'
                            f'{shard:03d}_100k.mat')))
    tasks.sort(key=lambda t: (t['first_frame'], t['family'], t['snr_db']))
    save_json(out / 'tasks.json', tasks)
    for family in SHARD_FRAMES:
        save_json(out / f'{family}_tasks.json',
                  [task for task in tasks if task['family'] == family])
    save_json(out / 'design.json', dict(stage='id_exact_bfc_100k',
        families={'id': {'m': 100_000}, 'exact': {'m': 100, 'weight': 2}},
        scheme='bfc', snr_db=SNR_DB, frames_per_point=FRAMES_PER_POINT,
        shard_frames=SHARD_FRAMES, total_frames=sum(t['frames'] for t in tasks),
        nt=60, G=360, Nb=64800, ldpc_rate=1/3,
        snr_definition='Es/N0', source_seed=20261006,
        position_seed=20261007, noise_seed=20261008,
        conventional_unchanged=True, rank_unchanged=True,
        source_samples='Fresh Threefry substreams, shared across SNRs within each family'))
    print(f'{len(tasks)} jobs; {sum(t["frames"] for t in tasks):,} fresh frames')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('generate', 'summarize'))
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.action == 'generate':
        generate(args.out)
    else:
        summarize(args.out, exact_root=None)


if __name__ == '__main__':
    main()
