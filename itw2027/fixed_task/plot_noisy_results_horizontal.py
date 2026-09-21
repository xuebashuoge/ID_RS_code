#!/usr/bin/env python3
"""Plot the three noisy nt=60 Boolean-function results horizontally."""
import argparse
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
from scipy.io import loadmat

FAMILIES = ('id', 'rank', 'exact')
FAMILY_COLORS = {'id': '#0072B2', 'rank': '#D55E00', 'exact': '#009E73'}
FAMILY_LABELS = {'id': 'ID', 'rank': 'Rank', 'exact': 'Exact'}


def _completed_result(path):
    result = loadmat(path, simplify_cells=True)['result']
    if not result['complete']:
        raise ValueError(f'Incomplete result: {path}')
    return result


def collect_noisy(root, target_frames=10_000):
    noisy = root / 'noisy_n_t_60'
    if not noisy.is_dir():
        raise FileNotFoundError(f'Missing noisy nt=60 result directory: {noisy}')
    groups = {}
    for path in sorted(noisy.glob('*.mat')):
        result = _completed_result(path); task = result['task']
        if int(task['nt']) != 60:
            raise ValueError(f'Not an nt=60 result: {path}')
        data = np.atleast_2d(result['per_frame']); frames = int(task['frames'])
        if len(data) != frames or int(result['frames_done']) != frames:
            raise ValueError(f'Frame-count mismatch: {path}')
        if not np.all(data[:, 0] == data[:, 1]):
            raise ValueError(f'Unbalanced class counts: {path}')
        key = (str(task['family']), str(task['scheme']), float(task['snr_db']))
        fp_bound = float(result['config']['bound'])
        group = groups.setdefault(key, {'data': [], 'frames': set(), 'fp_bound': fp_bound})
        if group['fp_bound'] != fp_bound:
            raise ValueError(f'Inconsistent FP bound: {path}')
        first = int(task['first_frame']); frame_ids = set(range(first, first + frames))
        if frame_ids & group['frames']:
            raise ValueError(f'Overlapping noisy shards: {path}')
        group['frames'].update(frame_ids); group['data'].append(data)
    expected_frames = set(range(1, target_frames + 1)); records = []
    for (family, scheme, snr), group in sorted(groups.items()):
        if group['frames'] != expected_frames:
            raise ValueError(f'Incomplete frame coverage: {(family, scheme, snr)}')
        totals = np.concatenate(group['data']).sum(axis=0)
        records.append(dict(family=family, scheme=scheme, snr_db=snr,
            frames=len(group['frames']), negative_trials=int(totals[0]),
            positive_trials=int(totals[1]),
            balanced_error=(totals[2] + totals[3]) / (totals[0] + totals[1]),
            noiseless_balanced_error=.5 * totals[5] / totals[0],
            balanced_fp_bound=.5 * group['fp_bound']))
    expected_keys = {(family, scheme) for family in FAMILIES
                     for scheme in (('bfc', 'conventional') if family == 'exact' else ('bfc',))}
    if {(r['family'], r['scheme']) for r in records} != expected_keys:
        raise ValueError('Missing or extra noisy family/scheme groups')
    return records


def _series(records, family, scheme):
    return sorted((r for r in records if r['family'] == family and r['scheme'] == scheme),
                  key=lambda r: r['snr_db'])


def _clean_axis(ax):
    ax.grid(axis='y', which='major', color='0.88', linewidth=.55)
    ax.tick_params(axis='both', which='both', direction='out', length=3)
    ax.set_axisbelow(True)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)


FIGSIZE = (3.5, 1.7)
BFC_LIMITS = (-5.05, -4.)
CONVENTIONAL_LIMITS = (1.5, 2.2)


def _save(fig, out):
    stem = out / 'noisy_results_nt60_horizontal'
    fig.savefig(stem.with_suffix('.pdf'))
    fig.savefig(stem.with_suffix('.png'), dpi=300)
    plt.close(fig)


def _plot_bfc(ax, records, family):
    """Plot one family over the low-SNR BFC segment and its FP bound."""
    rows = _series(records, family, 'bfc')
    if not rows:
        raise ValueError(f'Missing noisy BFC rows for {family}')
    x = np.array([r['snr_db'] for r in rows])
    y = np.array([r['balanced_error'] for r in rows])
    reference_row = max(rows, key=lambda r: r['frames'])
    empirical_floor = reference_row['noiseless_balanced_error']
    fp_bound = reference_row['balanced_fp_bound']
    mask = ((x >= BFC_LIMITS[0]) & (x <= BFC_LIMITS[1]) & (y > 0))
    if empirical_floor > 0:
            floor_points = np.flatnonzero(mask & (y <= empirical_floor))

            if family == 'exact' and floor_points.size:
                first_floor_point = floor_points[0]
                mask &= y > empirical_floor
                mask[first_floor_point] = True
            else:
                mask &= y > empirical_floor

    color = FAMILY_COLORS[family]
    ax.plot(x[mask], y[mask], color=color, lw=.9, ls='-', marker='o',
            ms=2.2, markerfacecolor=color, markeredgecolor=color,
            markeredgewidth=.6)
    ax.hlines(fp_bound, *BFC_LIMITS, color=color, lw=.7, ls=':')
    ax.text(.04, .02, FAMILY_LABELS[family], transform=ax.transAxes,
            color=color, fontsize=5.8, ha='left', va='bottom',
            bbox=dict(facecolor='white', edgecolor='none', pad=.15))
    return fp_bound


def plot_noisy(records, out):
    """Plot ID, Rank, and broken-axis Exact from left to right."""
    fig = plt.figure(figsize=FIGSIZE)
    outer = fig.add_gridspec(
        1, 3, width_ratios=[1., 1., 1.72], wspace=.15)
    id_ax = fig.add_subplot(outer[0, 0])
    rank_ax = fig.add_subplot(outer[0, 1], sharey=id_ax)
    exact_grid = outer[0, 2].subgridspec(
        1, 2, width_ratios=[1.35, 1.], wspace=.09)
    exact_bfc_ax = fig.add_subplot(exact_grid[0, 0], sharey=id_ax)
    exact_conventional_ax = fig.add_subplot(
        exact_grid[0, 1], sharey=id_ax)

    _plot_bfc(id_ax, records, 'id')
    _plot_bfc(rank_ax, records, 'rank')
    exact_fp_bound = _plot_bfc(exact_bfc_ax, records, 'exact')
    exact_conventional_ax.hlines(
        exact_fp_bound, *CONVENTIONAL_LIMITS,
        color=FAMILY_COLORS['exact'], lw=.7, ls=':')

    conventional = _series(records, 'exact', 'conventional')
    if not conventional:
        raise ValueError('Missing conventional exact-threshold rows')
    x = np.array([r['snr_db'] for r in conventional])
    y = np.array([r['balanced_error'] for r in conventional])
    for ax, segment_limits in (
            (exact_bfc_ax, BFC_LIMITS),
            (exact_conventional_ax, CONVENTIONAL_LIMITS)):
        mask = ((x >= segment_limits[0]) & (x <= segment_limits[1])
                & (y > 0))
        ax.plot(x[mask], y[mask], color=FAMILY_COLORS['exact'], lw=.9,
                ls='--', marker='s', ms=2.2, markerfacecolor='white',
                markeredgecolor=FAMILY_COLORS['exact'], markeredgewidth=.6)

    for ax in (id_ax, rank_ax, exact_bfc_ax):
        ax.set(yscale='log', ylim=(1e-7, .8), xlim=BFC_LIMITS)
        ax.set_xticks([-5., -4.5, -4.])
        ax.tick_params(axis='both', which='both', labelsize=5.2, pad=1.2)
        ax.get_xticklabels()[-1].set_horizontalalignment('right')
        _clean_axis(ax)
    exact_conventional_ax.set(
        yscale='log', ylim=(1e-7, .8), xlim=CONVENTIONAL_LIMITS)
    exact_conventional_ax.set_xticks([1.5, 2.2])
    exact_conventional_ax.tick_params(
        axis='both', which='both', labelsize=5.2, pad=1.2)
    exact_conventional_ax.get_xticklabels()[0].set_horizontalalignment('left')
    exact_conventional_ax.get_xticklabels()[-1].set_horizontalalignment('right')
    _clean_axis(exact_conventional_ax)

    # The common y scale needs labels only on the first logical subfigure.
    for ax in (rank_ax, exact_bfc_ax, exact_conventional_ax):
        ax.tick_params(axis='y', which='both', left=False, labelleft=False)

    # Mark the omitted interval in the Exact subfigure.
    exact_bfc_ax.spines['right'].set_visible(False)
    exact_conventional_ax.spines['left'].set_visible(False)
    for ax, xpos in ((exact_bfc_ax, 1), (exact_conventional_ax, 0)):
        ax.plot([xpos - .025, xpos + .025], [-.018, .018],
                transform=ax.transAxes, color='k', clip_on=False, lw=.8)

    fig.legend(handles=[
        Line2D([], [], color='.25', lw=.9, ls='-', marker='o', ms=2.2,
               label='BFC'),
        Line2D([], [], color='.25', lw=.7, ls=':',
               label='Noiseless FP bound'),
        Line2D([], [], color='.25', lw=.9, ls='--', marker='s', ms=2.2,
               markerfacecolor='white', label='Conventional'),
    ], loc='upper center', bbox_to_anchor=(.5, .985), ncol=3,
       frameon=False, fontsize=4.8, handlelength=1.1, columnspacing=.5,
       handletextpad=.22, labelspacing=.05, borderaxespad=0)
    fig.text(.5, .01, 'SNR (dB)', ha='center', va='bottom', fontsize=6.5)
    fig.text(.025, .51, 'Error probability', rotation=90,
             ha='center', va='center', fontsize=6.5)
    fig.subplots_adjust(left=.115, right=.99, bottom=.14, top=.90)
    _save(fig, out)


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--noisy', type=Path,
                        default=here / 'results/production_n_t_60')
    parser.add_argument('--out', type=Path, default=None)
    args = parser.parse_args()

    default_out = here / 'figures'
    out = default_out if args.out is None else args.out
    out.mkdir(parents=True, exist_ok=True)
    records = collect_noisy(args.noisy)
    plot_noisy(records, out)
    print(f'Validated {len(records)} noisy nt=60 points; wrote '
          f'{out / "noisy_results_nt60_horizontal.pdf"} and '
          f'{out / "noisy_results_nt60_horizontal.png"}.')


if __name__ == '__main__':
    main()
