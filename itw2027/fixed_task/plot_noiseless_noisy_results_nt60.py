#!/usr/bin/env python3
"""Plot the original noiseless results with the noisy nt=60 campaign."""
import argparse
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
from scipy.io import loadmat

from collections import defaultdict

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
            result = _completed_result(path)
            task = result['task']
            family, nt = str(task['family']), int(task['nt'])
            hits = np.atleast_1d(result['hits'])
            first_position, last_position = int(task['first_position']), int(task['positions'])
            if int(result['next_position']) != last_position + 1:
                raise ValueError(f'Incomplete position shard: {path}')
            config = result['config']
            group = groups.setdefault((family, nt), dict(
                T=int(config['T']), bound=float(config['bound']), messages=defaultdict(dict)))
            if group['T'] != int(config['T']) or group['bound'] != float(config['bound']):
                raise ValueError(f'Inconsistent noiseless configuration: {path}')
            first_message = int(task['first_message'])
            for offset, value in enumerate(hits):
                message = first_message + offset
                interval = (first_position, last_position)
                if interval in group['messages'][message]:
                    raise ValueError(f'Duplicate noiseless shard: {path}')
                group['messages'][message][interval] = int(value)
    expected_groups = {(family, nt) for family in FAMILIES for nt in EXPECTED_NT}
    if set(groups) != expected_groups:
        raise ValueError('Noiseless evidence does not cover every family and tag length')
    table = []
    for family in FAMILIES:
        for nt in EXPECTED_NT:
            group = groups[(family, nt)]
            expected_messages = set(range(1, EXPECTED_MESSAGES[family] + 1))
            if set(group['messages']) != expected_messages:
                raise ValueError(f'Incomplete message coverage: {(family, nt)}')
            probabilities = []
            for message in sorted(group['messages']):
                cursor, hits = 1, 0
                for (first, last), count in sorted(group['messages'][message].items()):
                    if first != cursor:
                        raise ValueError(f'Missing/overlapping positions: {(family, nt, message)}')
                    cursor, hits = last + 1, hits + count
                if cursor != group['T'] + 1:
                    raise ValueError(f'Partial enumeration: {(family, nt, message)}')
                probabilities.append(hits / group['T'])
            values = np.asarray(probabilities)
            table.append(dict(family=family, nt=nt, mean=float(values.mean()),
                              sample_max=float(values.max()), bound=group['bound']))
    return table


def _clean_axis(ax):
    ax.grid(axis='y', which='major', color='0.88', linewidth=.55)
    ax.tick_params(axis='both', which='both', direction='out', length=3)
    ax.set_axisbelow(True)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)


def _save(fig, out):
    fig.savefig(out / 'combined_results.pdf')
    fig.savefig(out / 'combined_results.png', dpi=300)
    plt.close(fig)


def _series(records, family, scheme):
    return sorted((r for r in records if r['family'] == family and r['scheme'] == scheme),
                  key=lambda r: r['snr_db'])


def collect_noisy(root, target_frames=10_000):
    """Aggregate and validate the noisy nt=60 result shards."""
    noisy = root / 'noisy_n_t_60'
    if not noisy.is_dir():
        raise FileNotFoundError(f'Missing noisy nt=60 result directory: {noisy}')

    groups = {}
    for path in sorted(noisy.glob('*.mat')):
        result = _completed_result(path)
        task = result['task']
        if int(task['nt']) != 60:
            raise ValueError(f'Not an nt=60 result: {path}')

        data = np.atleast_2d(result['per_frame'])
        frames = int(task['frames'])
        if len(data) != frames or int(result['frames_done']) != frames:
            raise ValueError(f'Frame-count mismatch: {path}')
        if not np.all(data[:, 0] == data[:, 1]):
            raise ValueError(f'Unbalanced class counts: {path}')

        key = (str(task['family']), str(task['scheme']), float(task['snr_db']))
        fp_bound = float(result['config']['bound'])
        group = groups.setdefault(
            key, {'data': [], 'frames': set(), 'fp_bound': fp_bound})
        if group['fp_bound'] != fp_bound:
            raise ValueError(f'Inconsistent FP bound: {path}')
        first = int(task['first_frame'])
        frame_ids = set(range(first, first + frames))
        if frame_ids & group['frames']:
            raise ValueError(f'Overlapping noisy shards: {path}')
        group['frames'].update(frame_ids)
        group['data'].append(data)

    expected_frames = set(range(1, target_frames + 1))
    records = []
    for (family, scheme, snr), group in sorted(groups.items()):
        if group['frames'] != expected_frames:
            raise ValueError(f'Incomplete frame coverage: {(family, scheme, snr)}')
        totals = np.concatenate(group['data']).sum(axis=0)
        records.append(dict(
            family=family, scheme=scheme, snr_db=snr, frames=len(group['frames']),
            negative_trials=int(totals[0]), positive_trials=int(totals[1]),
            balanced_error=(totals[2] + totals[3]) / (totals[0] + totals[1]),
            noiseless_balanced_error=.5 * totals[5] / totals[0],
            balanced_fp_bound=.5 * group['fp_bound'],
        ))

    expected_keys = {
        (family, scheme)
        for family in FAMILIES
        for scheme in (('bfc', 'conventional') if family == 'exact' else ('bfc',))
    }
    actual_keys = {(row['family'], row['scheme']) for row in records}
    if actual_keys != expected_keys:
        raise ValueError(f'Missing or extra noisy family/scheme groups: {actual_keys}')
    return records


def plot_combined(records, table, out):
    """Plot the unchanged noiseless panel with the noisy nt=60 results."""
    fig = plt.figure(figsize=FIGSIZE)
    outer = fig.add_gridspec(1, 2, width_ratios=[1., 1.], wspace=.18)
    noiseless_grid = outer[0, 0].subgridspec(3, 1, hspace=.10)
    noiseless_axes = [fig.add_subplot(noiseless_grid[i, 0]) for i in range(3)]
    noisy_grid = outer[0, 1].subgridspec(1, 2, width_ratios=[1.35, 1.], wspace=.09)
    bfc_ax = fig.add_subplot(noisy_grid[0, 0])
    conventional_ax = fig.add_subplot(noisy_grid[0, 1], sharey=bfc_ax)

    # Keep the noiseless panel identical to plot_noiseless_noisy_results.py.
    styles = {'mean': ('-', 'o', None), 'sample_max': ('--', 's', 'white'),
              'bound': (':', None, None)}
    limits = {'id': (6e-8, 1.5), 'rank': (1e-6, 1.5), 'exact': (3e-4, 1.5)}
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
        Line2D([], [], color='.25', lw=.8, ls='-', marker='o', ms=2, label='Mean'),
        Line2D([], [], color='.25', lw=.8, ls='--', marker='s', ms=2,
               markerfacecolor='white', label='Max'),
        Line2D([], [], color='.25', lw=.8, ls=':', label='Bound'),
    ], loc='upper right', bbox_to_anchor=(.99, 1.05), ncol=3, frameon=False,
       fontsize=4.4, handlelength=1.15, columnspacing=.55, handletextpad=.25,
       labelspacing=.05, borderaxespad=0)

    bfc_limits = (-5.05, -4.)
    conventional_limits = (1.5, 2.2)
    bfc_styles = {
        'id': dict(ls='-', marker='o', markerfacecolor=FAMILY_COLORS['id'],
                   markevery=(0, 3)),
        'rank': dict(ls='--', marker='^', markerfacecolor='white',
                     markevery=(1, 3)),
        'exact': dict(ls='-.', marker='s', markerfacecolor='white',
                      markevery=(2, 3)),
    }
    # The BFC waterfalls are almost coincident. A small horizontal dodge
    # separates them without changing any error-probability value.
    bfc_x_offsets = {'id': -.02, 'rank': 0., 'exact': .02}
    for family in FAMILIES:
        rows = _series(records, family, 'bfc')
        if not rows:
            raise ValueError(f'Missing noisy BFC rows for {family}')
        x = np.array([r['snr_db'] for r in rows])
        y = np.array([r['balanced_error'] for r in rows])
        color = FAMILY_COLORS[family]
        reference_row = max(rows, key=lambda r: r['frames'])
        empirical_floor = reference_row['noiseless_balanced_error']
        fp_bound = reference_row['balanced_fp_bound']
        mask = (x >= bfc_limits[0]) & (x <= bfc_limits[1]) & (y > 0)
        if empirical_floor > 0:
            mask &= y > empirical_floor
        bfc_ax.plot(x[mask] + bfc_x_offsets[family], y[mask],
                    color=color, lw=.8, ms=2.2,
                    markeredgecolor=color, markeredgewidth=.6,
                    **bfc_styles[family])
        # On the balanced-error scale, a noiseless FP bound contributes half
        # its value because negative and positive trials are equally weighted.
        bfc_ax.hlines(fp_bound, *bfc_limits, color=color, lw=.65, ls=':')

    conventional = _series(records, 'exact', 'conventional')
    if not conventional:
        raise ValueError('Missing conventional exact-threshold rows')
    x = np.array([r['snr_db'] for r in conventional])
    y = np.array([r['balanced_error'] for r in conventional])
    mask = ((x >= conventional_limits[0]) & (x <= conventional_limits[1])
            & (y > 0))
    conventional_ax.plot(
        x[mask], y[mask], color=FAMILY_COLORS['exact'], lw=.8, ls='--',
        marker='s', ms=2.2, markerfacecolor='white',
        markeredgecolor=FAMILY_COLORS['exact'], markeredgewidth=.6)
    for ax, segment_limits in ((bfc_ax, bfc_limits),
                               (conventional_ax, conventional_limits)):
        ax.set(yscale='log', ylim=(1e-7, .75), xlim=segment_limits)
        ax.tick_params(axis='both', which='both', labelsize=4.5, pad=1.2)
        _clean_axis(ax)
    bfc_ax.set_xticks([-5., -4.5, -4.])
    conventional_ax.set_xticks([1.5, 2., 2.2])
    bfc_ax.get_xticklabels()[-1].set_horizontalalignment('right')
    conventional_ax.get_xticklabels()[0].set_horizontalalignment('left')
    bfc_ax.set_xlabel('SNR', x=.84, fontsize=6, labelpad=1)
    bfc_ax.spines['right'].set_visible(False)
    conventional_ax.spines['left'].set_visible(False)
    conventional_ax.tick_params(axis='y', which='both', left=False, labelleft=False)
    for ax, xpos in ((bfc_ax, 1), (conventional_ax, 0)):
        ax.plot([xpos - .022, xpos + .022], [-.018, .018],
                transform=ax.transAxes, color='k', clip_on=False, lw=.8)
    fig.legend(handles=[
        Line2D([], [], color=FAMILY_COLORS['id'], lw=.8, ls='-', marker='o',
               ms=2.2, label=r'ID ($-0.02$ dB)'),
        Line2D([], [], color=FAMILY_COLORS['rank'], lw=.8, ls='--', marker='^',
               ms=2.2, markerfacecolor='white', label='Rank (0 dB)'),
        Line2D([], [], color=FAMILY_COLORS['exact'], lw=.8, ls='-.', marker='s',
               ms=2.2, markerfacecolor='white', label=r'Exact ($+0.02$ dB)'),
        Line2D([], [], color='.25', lw=.65, ls=':',
               label='Noiseless FP bound'),
        Line2D([], [], color='.25', lw=.8, ls='--', marker='s', ms=2,
               markerfacecolor='white', label='Conv.'),
    ], loc='center', bbox_to_anchor=(.85, .53), ncol=1, frameon=False,
       fontsize=4.3, handlelength=1.15, columnspacing=.4, handletextpad=.25,
       labelspacing=.05, borderaxespad=0)
    fig.text(.245, .975, '(a) Noiseless channel', ha='center', va='top', fontsize=7.1)
    fig.text(.755, .975, '(b) Noisy channel', ha='center', va='top', fontsize=7.1)
    fig.text(.025, .48, 'Error probability', rotation=90,
             ha='center', va='center', fontsize=6)
    fig.subplots_adjust(left=.105, right=.985, bottom=.16, top=.87)
    _save(fig, out)


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, default=here / 'results/production')
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
          f'{len(table)} noiseless rows; wrote {out / "combined_results.pdf"} '
          f'and {out / "combined_results.png"}.')


if __name__ == '__main__':
    main()
