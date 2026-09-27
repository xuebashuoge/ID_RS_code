#!/usr/bin/env python3
"""Clone the original noiseless rank design with m=150 and rank <= 2000."""
import argparse
import json
from pathlib import Path

from campaign import save_json


M = 150
RANK_THRESHOLD = 2000
EXPECTED_NT = tuple(range(28, 47, 2))
EXPECTED_MESSAGES = 2000


def generate(base, extension, out):
    """Preserve every original rank task setting except the rank function."""
    if out.exists():
        raise ValueError('Use a fresh destination; results are never overwritten')

    tasks = []
    for source in (base, extension):
        manifest = source / 'noiseless.json'
        source_tasks = json.loads(manifest.read_text())
        tasks.extend(dict(task, m=M, rank_threshold=RANK_THRESHOLD)
                     for task in source_tasks if task['family'] == 'rank')

    if sorted({task['nt'] for task in tasks}) != list(EXPECTED_NT):
        raise ValueError('Source manifests do not cover the expected tag lengths')
    if any(task['kind'] != 'noiseless' or task['family'] != 'rank'
           for task in tasks):
        raise ValueError('Rank-only noiseless manifest contains another task type')

    for nt in EXPECTED_NT:
        nt_tasks = [task for task in tasks if task['nt'] == nt]
        messages = set()
        intervals = set()
        for task in nt_tasks:
            messages.update(range(task['first_message'],
                                  task['first_message'] + task['messages']))
            intervals.add((task['first_position'], task['positions']))
        if messages != set(range(1, EXPECTED_MESSAGES + 1)):
            raise ValueError(f'Incomplete source message coverage at nt={nt}')
        cursor = 1
        for first, last in sorted(intervals):
            if first != cursor:
                raise ValueError(f'Incomplete source position coverage at nt={nt}')
            cursor = last + 1
        if cursor != 2 ** (nt // 2) + 1:
            raise ValueError(f'Incomplete source position coverage at nt={nt}')

    outputs = [task['output'] for task in tasks]
    if len(outputs) != len(set(outputs)):
        raise ValueError('Source manifests contain duplicate rank output paths')

    probe = next(task for task in tasks
                 if task['nt'] == max(EXPECTED_NT)
                 and task['first_message'] == 1
                 and task['first_position'] == 1)
    save_json(out / 'noiseless.json', tasks)
    save_json(out / 'probe_rank.json', [probe])
    save_json(out / 'noiseless_rank.json', [task for task in tasks
                                             if task is not probe])
    save_json(out / 'design.json', dict(
        stage='aligned_noiseless_rank', family='rank', m=M,
        rank_threshold=RANK_THRESHOLD, support=RANK_THRESHOLD + 1,
        messages=EXPECTED_MESSAGES, nt=list(EXPECTED_NT),
        source_manifests=[str((base / 'noiseless.json').resolve()),
                          str((extension / 'noiseless.json').resolve())],
        preserved_task_fields=[
            'kind', 'family', 'nt', 'messages', 'first_message', 'seed_group',
            'first_position', 'positions', 'chunk_size', 'runtime_limit',
            'output'],
        only_function_changes=dict(m=M, rank_threshold=RANK_THRESHOLD)))
    print(f'{out}: {len(tasks)} rank-only noiseless tasks; '
          f'm={M}, rank threshold={RANK_THRESHOLD}')


if __name__ == '__main__':
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path,
                        default=here / 'results/production')
    parser.add_argument('--extension', type=Path,
                        default=here / 'results/extension_20260918')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    generate(args.base, args.extension, args.out)
