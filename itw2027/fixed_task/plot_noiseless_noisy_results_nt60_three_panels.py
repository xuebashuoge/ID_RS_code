#!/usr/bin/env python3
"""Plot vertically separated noiseless and noisy nt=60 results."""
import argparse
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
from collections import defaultdict
from scipy.io import loadmat

FAMILIES = ('id', 'rank', 'exact')
FAMILY_COLORS = {'id': '#0072B2', 'rank': '#D55E00', 'exact': '#009E73'}
FAMILY_LABELS = {'id': 'ID', 'rank': 'Rank', 'exact': 'Exact'}
FIGSIZE = (3.5, 1.92)
EXPECTED_NT = tuple(range(28, 47, 2))
EXPECTED_MESSAGES = {'id': 200, 'rank': 2000, 'exact': 2000}


def _completed_result(path):
    result = loadmat(path, simplify_cells=True)['result']
    if not result['complete']:
        raise ValueError(f'Incomplete result: {path}')
    return result


def collect_noiseless(roots):
    groups = {}
    for root in roots:
        for path in sorted((root / 'noiseless').glob('*.mat')):
            result = _completed_result(path); task = result['task']
            family, nt = str(task['family']), int(task['nt'])
            hits = np.atleast_1d(result['hits'])
            first, last = int(task['first_position']), int(task['positions'])
            if int(result['next_position']) != last + 1:
                raise ValueError(f'Incomplete position shard: {path}')
            config = result['config']
            group = groups.setdefault((family, nt), dict(
                T=int(config['T']), bound=float(config['bound']), messages=defaultdict(dict)))
            if (group['T'], group['bound']) != (int(config['T']), float(config['bound'])):
                raise ValueError(f'Inconsistent noiseless configuration: {path}')
            for offset, value in enumerate(hits):
                message = int(task['first_message']) + offset
                interval = (first, last)
                if interval in group['messages'][message]:
                    raise ValueError(f'Duplicate noiseless shard: {path}')
                group['messages'][message][interval] = int(value)
    expected = {(family, nt) for family in FAMILIES for nt in EXPECTED_NT}
    if set(groups) != expected:
        raise ValueError('Noiseless evidence does not cover every family and tag length')
    table = []
    for family in FAMILIES:
        for nt in EXPECTED_NT:
            group = groups[(family, nt)]
            if set(group['messages']) != set(range(1, EXPECTED_MESSAGES[family] + 1)):
                raise ValueError(f'Incomplete message coverage: {(family, nt)}')
            probabilities = []
            for message in sorted(group['messages']):
                cursor, total = 1, 0
                for (first, last), count in sorted(group['messages'][message].items()):
                    if first != cursor:
                        raise ValueError(f'Missing/overlapping positions: {(family, nt, message)}')
                    cursor, total = last + 1, total + count
                if cursor != group['T'] + 1:
                    raise ValueError(f'Partial enumeration: {(family, nt, message)}')
                probabilities.append(total / group['T'])
            values = np.asarray(probabilities)
            table.append(dict(family=family, nt=nt, mean=float(values.mean()),
                              sample_max=float(values.max()), bound=group['bound']))
    return table


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


THREE_PANEL_FIGSIZE = (FIGSIZE[0], 2.18)


def _save_three_panels(fig, out):
    """Save without overwriting the two-axis version of the figure."""
    stem = out / 'combined_results_three_panels'
    fig.savefig(stem.with_suffix('.pdf'))
    fig.savefig(stem.with_suffix('.png'), dpi=300)
    plt.close(fig)


def _plot_noiseless(noiseless_axes, table):
    """Draw the original three-row noiseless panel."""
    styles = {'mean': ('-', 'o', None), 'sample_max': ('--', 's', 'white'),
              'bound': (':', None, None)}
    limits = {'id': (6e-8, 1.5), 'rank': (1e-6, 1.5),
              'exact': (3e-4, 1.5)}
    ticks = {'id': (1e-6, 1e-3, 1.), 'rank': (1e-5, 1e-2, 1.),
             'exact': (1e-3, 1e-1, 1.)}

    for ax, family in zip(noiseless_axes, FAMILIES):
        rows = sorted((r for r in table if r['family'] == family),
                      key=lambda r: r['nt'])
        if not rows:
            raise ValueError(f'Missing noiseless rows for {family}')
        color = FAMILY_COLORS[family]
        for metric, (linestyle, marker, face) in styles.items():
            ax.plot([r['nt'] for r in rows], [r[metric] for r in rows],
                    color=color, lw=.8, ls=linestyle, marker=marker, ms=1.9,
                    markerfacecolor=color if face is None else face,
                    markeredgecolor=color, markeredgewidth=.6)
        ax.set(yscale='log', xlim=(27.3, 46.7), ylim=limits[family])
        ax.set_yticks(ticks[family])
        ax.text(.025, .13, FAMILY_LABELS[family], transform=ax.transAxes,
                color=color, fontsize=5.1, ha='left', va='bottom')
        ax.tick_params(axis='both', which='both', labelsize=4.5, pad=1.2)
        _clean_axis(ax)

    for ax in noiseless_axes[:-1]:
        ax.tick_params(axis='x', which='both', bottom=False, labelbottom=False)
    noiseless_axes[-1].set_xticks([28, 34, 40, 46])
    noiseless_axes[-1].set_xlabel(r'$n_t$', fontsize=6, labelpad=1)
    noiseless_axes[0].legend(handles=[
        Line2D([], [], color='.25', lw=.8, ls='-', marker='o', ms=2,
               label='Mean'),
        Line2D([], [], color='.25', lw=.8, ls='--', marker='s', ms=2,
               markerfacecolor='white', label='Max'),
        Line2D([], [], color='.25', lw=.8, ls=':', label='Bound'),
    ], loc='upper right', bbox_to_anchor=(.99, 1.05), ncol=3,
       frameon=False, fontsize=4.4, handlelength=1.15, columnspacing=.55,
       handletextpad=.25, labelspacing=.05, borderaxespad=0)


def _plot_noisy(noisy_axes, records):
    """Draw one noisy row per Boolean-function family.

    ID and Rank use the BFC waterfall interval only. Exact retains the broken
    SNR axis so the BFC and conventional waterfall intervals remain at their
    true SNR values.
    """
    id_ax, rank_ax, exact_bfc_ax, exact_conventional_ax = noisy_axes
    family_axes = {'id': id_ax, 'rank': rank_ax, 'exact': exact_bfc_ax}
    bfc_limits = (-5.05, -4.)
    conventional_limits = (1.5, 2.2)

    for family in FAMILIES:
        ax = family_axes[family]
        rows = _series(records, family, 'bfc')
        if not rows:
            raise ValueError(f'Missing noisy BFC rows for {family}')
        x = np.array([r['snr_db'] for r in rows])
        y = np.array([r['balanced_error'] for r in rows])
        reference_row = max(rows, key=lambda r: r['frames'])
        empirical_floor = reference_row['noiseless_balanced_error']
        fp_bound = reference_row['balanced_fp_bound']
        mask = ((x >= bfc_limits[0]) & (x <= bfc_limits[1]) & (y > 0))
        if empirical_floor > 0:
            floor_points = np.flatnonzero(mask & (y <= empirical_floor))

            if family == 'exact' and floor_points.size:
                first_floor_point = floor_points[0]
                mask &= y > empirical_floor
                mask[first_floor_point] = True
            else:
                mask &= y > empirical_floor

        color = FAMILY_COLORS[family]
        ax.plot(x[mask], y[mask], color=color, lw=.8, ls='-', marker='o',
                ms=1.9, markerfacecolor=color, markeredgecolor=color,
                markeredgewidth=.6)
        ax.hlines(fp_bound, *bfc_limits, color=color, lw=.7, ls=':')
        ax.text(.025, .35, FAMILY_LABELS[family], transform=ax.transAxes,
                color=color, fontsize=5.1, ha='left', va='bottom',
                bbox=dict(facecolor='white', edgecolor='none', pad=.15))

        # Exact is the only row with a second, conventional-SNR segment.
        if family == 'exact':
            exact_conventional_ax.hlines(
                fp_bound, *conventional_limits, color=color, lw=.7, ls=':')

    conventional = _series(records, 'exact', 'conventional')
    if not conventional:
        raise ValueError('Missing conventional exact-threshold rows')
    x = np.array([r['snr_db'] for r in conventional])
    y = np.array([r['balanced_error'] for r in conventional])
    for ax, segment_limits in (
            (exact_bfc_ax, bfc_limits),
            (exact_conventional_ax, conventional_limits)):
        mask = ((x >= segment_limits[0]) & (x <= segment_limits[1])
                & (y > 0))
        ax.plot(x[mask], y[mask], color=FAMILY_COLORS['exact'], lw=.8,
                ls='--', marker='s', ms=1.9, markerfacecolor='white',
                markeredgecolor=FAMILY_COLORS['exact'], markeredgewidth=.6)

    for ax in (id_ax, rank_ax, exact_bfc_ax):
        ax.set(yscale='log', ylim=(1e-7, .8), xlim=bfc_limits)
        ax.tick_params(axis='both', which='both', labelsize=4.5, pad=1.2)
        _clean_axis(ax)
    exact_conventional_ax.set(
        yscale='log', ylim=(1e-7, .8), xlim=conventional_limits)
    exact_conventional_ax.tick_params(
        axis='both', which='both', labelsize=4.5, pad=1.2)
    _clean_axis(exact_conventional_ax)

    # Use denser SNR ticks for ID and Rank, while retaining the original
    # three endpoint/center ticks for Exact.
    for ax in (id_ax, rank_ax):
        ax.set_xticks([-5., -4.75, -4.5, -4.25, -4.])
    exact_bfc_ax.set_xticks([-5., -4.5, -4.])
    exact_conventional_ax.set_xticks([1.5, 1.85, 2.2])
    for ax in (id_ax, rank_ax, exact_bfc_ax):
        ax.get_xticklabels()[-1].set_horizontalalignment('right')
    exact_conventional_ax.get_xticklabels()[0].set_horizontalalignment('left')
    exact_bfc_ax.set_xlabel('SNR (dB)', x=.84, fontsize=6, labelpad=1)

    # Mark the omitted SNR interval on the Exact row only.
    exact_bfc_ax.spines['right'].set_visible(False)
    exact_conventional_ax.spines['left'].set_visible(False)
    exact_conventional_ax.tick_params(
        axis='y', which='both', left=False, labelleft=False)
    for ax, xpos in ((exact_bfc_ax, 1), (exact_conventional_ax, 0)):
        ax.plot([xpos - .022, xpos + .022], [-.018, .018],
                transform=ax.transAxes, color='k', clip_on=False, lw=.8)

    # As in the noiseless panel, line meaning is carried by the legend while
    # the Boolean functions are identified by colored in-axis labels.
    id_ax.legend(handles=[
        Line2D([], [], color='.25', lw=.8, ls='-', marker='o', ms=2,
               label='BFC'),
        Line2D([], [], color='.25', lw=.7, ls=':',
               label='Noiseless FP bound'),
    ], loc='upper right', bbox_to_anchor=(1.02, 1.14), ncol=2,
       frameon=False, fontsize=4.2, handlelength=1.1, columnspacing=.45,
       handletextpad=.22, labelspacing=.05, borderaxespad=0)
    exact_conventional_ax.legend(handles=[
        Line2D([], [], color='.25', lw=.8, ls='--', marker='s', ms=2,
               markerfacecolor='white', label='Conventional'),
    ], loc='center left', bbox_to_anchor=(-0.1, .52), frameon=False,
       fontsize=4.2, handlelength=1.1, handletextpad=.22, borderaxespad=0)


def plot_combined(records, table, out):
    """Plot two aligned panels, each containing three vertical subfigures."""
    fig = plt.figure(figsize=THREE_PANEL_FIGSIZE)
    outer = fig.add_gridspec(1, 2, width_ratios=[1., 1.], wspace=.18)

    noiseless_grid = outer[0, 0].subgridspec(3, 1, hspace=.10)
    noiseless_axes = [fig.add_subplot(noiseless_grid[i, 0]) for i in range(3)]

    noisy_grid = outer[0, 1].subgridspec(
        3, 2, width_ratios=[1.35, 1.], hspace=.32, wspace=.09)
    id_ax = fig.add_subplot(noisy_grid[0, :])
    rank_ax = fig.add_subplot(noisy_grid[1, :])
    exact_bfc_ax = fig.add_subplot(noisy_grid[2, 0])
    exact_conventional_ax = fig.add_subplot(
        noisy_grid[2, 1], sharey=exact_bfc_ax)

    _plot_noiseless(noiseless_axes, table)
    _plot_noisy(
        (id_ax, rank_ax, exact_bfc_ax, exact_conventional_ax), records)

    fig.text(.295, .975, '(a) Noiseless channel', ha='center', va='top',
             fontsize=7.1)
    fig.text(.755, .975, '(b) Noisy channel', ha='center', va='top',
             fontsize=7.1)
    fig.text(.025, .48, 'Error probability', rotation=90,
             ha='center', va='center', fontsize=6)
    fig.subplots_adjust(left=.105, right=.985, bottom=.16, top=.87)
    _save_three_panels(fig, out)


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path,
                        default=here / 'results/production')
    parser.add_argument('--extension', type=Path,
                        default=here / 'results/extension_20260918')
    parser.add_argument('--noisy', type=Path,
                        default=here / 'results/production_n_t_60')
    parser.add_argument('--out', type=Path, default=None)
    args = parser.parse_args()

    default_out = here / 'figures'
    out = default_out if args.out is None else args.out
    out.mkdir(parents=True, exist_ok=True)
    records = collect_noisy(args.noisy)
    table = collect_noiseless((args.base, args.extension))
    plot_combined(records, table, out)
    print(f'Validated {len(records)} noisy nt=60 points and '
          f'{len(table)} noiseless rows; wrote '
          f'{out / "combined_results_three_panels.pdf"} and '
          f'{out / "combined_results_three_panels.png"}.')


if __name__ == '__main__':
    main()
