#!/usr/bin/env python3
"""Validate and plot the standalone noisy nt=60 campaign.

The nt=60 campaign has no noiseless simulation.  This script therefore reads
only ``noisy_n_t_60/*.mat`` and plots the balanced task error from the four
2,500-frame shards belonging to each family/scheme/SNR point.
"""
import argparse
import csv
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat


FAMILIES = ('id', 'rank', 'exact')
COLORS = {'id': '#0072B2', 'rank': '#D55E00', 'exact': '#009E73'}
LABELS = {'id': 'ID', 'rank': 'Rank', 'exact': 'Exact'}
EXPECTED_SCHEMES = {
    'id': ('bfc',),
    'rank': ('bfc',),
    'exact': ('bfc', 'conventional'),
}


def _completed(path):
    result = loadmat(path, simplify_cells=True)['result']
    if not result['complete']:
        raise ValueError(f'Incomplete result: {path}')
    return result


def collect(root, target_frames=10_000, shard_frames=2_500):
    """Read, validate, and aggregate the nt=60 noisy MAT shards."""
    noisy = root / 'noisy_n_t_60'
    if not noisy.is_dir():
        raise FileNotFoundError(f'Missing nt=60 result directory: {noisy}')

    groups = {}
    for path in sorted(noisy.glob('*.mat')):
        result = _completed(path)
        task = result['task']
        if int(task['nt']) != 60 or int(task['G']) != 360:
            raise ValueError(f'Not an nt=60 task: {path}')
        frames = int(task['frames'])
        if frames != shard_frames or int(result['frames_done']) != frames:
            raise ValueError(f'Unexpected frame count: {path}')
        if int(task['seed_group']) != 3:
            raise ValueError(f'Unexpected seed group: {path}')

        data = np.asarray(result['per_frame'])
        if data.ndim != 2 or data.shape != (frames, 7):
            raise ValueError(f'Unexpected per_frame shape: {path}: {data.shape}')
        if not np.all(data[:, 0] == data[:, 1]):
            raise ValueError(f'Unbalanced class counts: {path}')

        key = (str(task['family']), str(task['scheme']), float(task['snr_db']))
        group = groups.setdefault(key, {'data': [], 'frames': set(), 'paths': []})
        first = int(task['first_frame'])
        frame_ids = set(range(first, first + frames))
        if group['frames'] & frame_ids:
            raise ValueError(f'Overlapping frame shards: {path}')
        group['frames'].update(frame_ids)
        group['data'].append(data)
        group['paths'].append(path)

    expected = set(range(1, target_frames + 1))
    records = []
    for (family, scheme, snr), group in sorted(groups.items()):
        if group['frames'] != expected:
            raise ValueError(
                f'Incomplete frame coverage for {(family, scheme, snr)}: '
                f'{len(group["frames"])} frames')
        if family not in FAMILIES or scheme not in EXPECTED_SCHEMES[family]:
            raise ValueError(f'Unexpected family/scheme: {(family, scheme)}')
        totals = np.concatenate(group['data']).sum(axis=0)
        negative, positive, fp, fn, fer, noiseless_fp, iterations = totals
        total_frames = len(np.concatenate(group['data']))
        records.append({
            'family': family,
            'scheme': scheme,
            'snr_db': snr,
            'frames': len(group['frames']),
            'negative_trials': int(negative),
            'positive_trials': int(positive),
            'false_positives': int(fp),
            'false_negatives': int(fn),
            'frame_errors': int(fer),
            'noiseless_false_positives': int(noiseless_fp),
            'balanced_error': float((fp + fn) / (negative + positive)),
            'FP': float(fp / negative),
            'FN': float(fn / positive),
            'FER': float(fer / total_frames),
            'noiseless_FP': float(noiseless_fp / negative),
            'mean_iterations': float(iterations / total_frames),
        })

    actual = {(r['family'], r['scheme']) for r in records}
    expected_pairs = {
        (family, scheme)
        for family in FAMILIES
        for scheme in EXPECTED_SCHEMES[family]
    }
    if actual != expected_pairs:
        raise ValueError(f'Missing or extra family/scheme groups: {actual}')
    snrs = {r['snr_db'] for r in records}
    if len(snrs) != 37:
        raise ValueError(f'Expected 37 SNRs, found {len(snrs)}')
    return records


def _style_axis(ax):
    ax.grid(axis='y', color='0.88', linewidth=.55)
    ax.set_axisbelow(True)
    ax.tick_params(axis='both', which='both', direction='out', length=3,
                   labelsize=7, pad=2)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)


def plot(records, out):
    """Plot the noisy nt=60 curves with the same broken SNR range."""
    fig, (low_ax, high_ax) = plt.subplots(
        1, 2, figsize=(5.2, 3.0), sharey=True,
        gridspec_kw={'width_ratios': (1.35, 1.), 'wspace': .08})
    axes = ((low_ax, (-5.05, -3.5)), (high_ax, (1.1, 2.9)))

    for family in FAMILIES:
        rows = sorted(
            (r for r in records if r['family'] == family and r['scheme'] == 'bfc'),
            key=lambda r: r['snr_db'])
        color = COLORS[family]
        for ax, limits in axes:
            selected = [r for r in rows if limits[0] <= r['snr_db'] <= limits[1]
                        and r['balanced_error'] > 0]
            ax.plot([r['snr_db'] for r in selected],
                    [r['balanced_error'] for r in selected],
                    color=color, lw=1.0, marker='o', ms=2.5,
                    label=LABELS[family])

    rows = sorted((r for r in records
                   if r['family'] == 'exact' and r['scheme'] == 'conventional'),
                  key=lambda r: r['snr_db'])
    for ax, limits in axes:
        selected = [r for r in rows if limits[0] <= r['snr_db'] <= limits[1]
                    and r['balanced_error'] > 0]
        ax.plot([r['snr_db'] for r in selected],
                [r['balanced_error'] for r in selected],
                color=COLORS['exact'], lw=1.0, ls='--', marker='s', ms=2.5,
                markerfacecolor='white', markeredgecolor=COLORS['exact'],
                label='Exact conventional')

    for ax, limits in axes:
        ax.set(xlim=limits, yscale='log', ylim=(1e-7, .75), xlabel='SNR (dB)')
        _style_axis(ax)
    low_ax.set_ylabel('Balanced task error')
    low_ax.set_xticks([-5., -4.5, -4.])
    high_ax.set_xticks([1.5, 2., 2.5])
    low_ax.spines['right'].set_visible(False)
    high_ax.spines['left'].set_visible(False)
    high_ax.tick_params(axis='y', left=False, labelleft=False)
    low_ax.legend(frameon=False, fontsize=7, loc='best')
    fig.suptitle('NT=60 noisy channel results', fontsize=10)
    fig.subplots_adjust(left=.12, right=.98, bottom=.18, top=.86)
    fig.savefig(out / 'noisy_results_nt60.pdf')
    fig.savefig(out / 'noisy_results_nt60.png', dpi=300)
    plt.close(fig)


def write_csv(records, out):
    fields = list(records[0])
    with (out / 'noisy_summary_nt60.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator='\n')
        writer.writeheader()
        writer.writerows(records)


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--results', type=Path,
                        default=here / 'results/production_n_t_60',
                        help='NT=60 result directory')
    parser.add_argument('--out', type=Path, default=None,
                        help='Output directory; defaults to --results')
    args = parser.parse_args()
    out = args.results if args.out is None else args.out
    out.mkdir(parents=True, exist_ok=True)
    records = collect(args.results)
    write_csv(records, out)
    plot(records, out)
    print(f'Validated {len(records)} nt=60 noisy points; wrote outputs to {out}.')


if __name__ == '__main__':
    main()
