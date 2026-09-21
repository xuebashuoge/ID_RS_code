#!/usr/bin/env python3
"""Plot the three noiseless Boolean-function results in one horizontal row."""
import argparse
from collections import defaultdict
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
EXPECTED_NT = tuple(range(28, 47, 2))
EXPECTED_MESSAGES = {'id': 200, 'rank': 2000, 'exact': 2000}


def _completed_result(path):
    result = loadmat(path, simplify_cells=True)['result']
    if not result['complete']:
        raise ValueError(f'Incomplete result: {path}')
    return result


def collect_noiseless(roots):
    """Aggregate position shards and validate complete message coverage."""
    groups = {}
    for root in roots:
        for path in sorted((root / 'noiseless').glob('*.mat')):
            result = _completed_result(path)
            task = result['task']
            family, nt = str(task['family']), int(task['nt'])
            hits = np.atleast_1d(result['hits'])
            first_position = int(task['first_position'])
            last_position = int(task['positions'])
            if int(result['next_position']) != last_position + 1:
                raise ValueError(f'Incomplete position shard: {path}')
            config = result['config']
            group = groups.setdefault(
                (family, nt),
                dict(T=int(config['T']), bound=float(config['bound']),
                     messages=defaultdict(dict)))
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
                cursor = 1
                hits = 0
                for (first, last), count in sorted(group['messages'][message].items()):
                    if first != cursor:
                        raise ValueError(f'Missing/overlapping positions: {(family, nt, message)}')
                    cursor = last + 1
                    hits += count
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


FIGSIZE = (3.5, 1.7)


def _save(fig, out):
    stem = out / 'noiseless_results_horizontal'
    fig.savefig(stem.with_suffix('.pdf'))
    fig.savefig(stem.with_suffix('.png'), dpi=300)
    plt.close(fig)


def plot_noiseless(table, out):
    """Plot ID, Rank, and Exact from left to right."""
    fig, axes = plt.subplots(1, 3, figsize=FIGSIZE)
    styles = {'mean': ('-', 'o', None), 'sample_max': ('--', 's', 'white'),
              'bound': (':', None, None)}
    limits = {'id': (6e-8, 1.5), 'rank': (1e-6, 1.5),
              'exact': (3e-4, 1.5)}
    ticks = {'id': (1e-6, 1e-3, 1.), 'rank': (1e-5, 1e-2, 1.),
             'exact': (1e-3, 1e-1, 1.)}

    for ax, family in zip(axes, FAMILIES):
        rows = sorted((r for r in table if r['family'] == family),
                      key=lambda r: r['nt'])
        if not rows:
            raise ValueError(f'Missing noiseless rows for {family}')
        color = FAMILY_COLORS[family]
        for metric, (linestyle, marker, face) in styles.items():
            ax.plot([r['nt'] for r in rows], [r[metric] for r in rows],
                    color=color, lw=.9, ls=linestyle, marker=marker, ms=2.2,
                    markerfacecolor=color if face is None else face,
                    markeredgecolor=color, markeredgewidth=.6)
        ax.set(yscale='log', xlim=(27.3, 46.7), ylim=limits[family])
        ax.set_xticks([28, 34, 40, 46])
        ax.set_yticks(ticks[family])
        ax.text(.04, .02, FAMILY_LABELS[family], transform=ax.transAxes,
                color=color, fontsize=5.8, ha='left', va='bottom',
                bbox=dict(facecolor='white', edgecolor='none', pad=.15))
        ax.tick_params(axis='both', which='both', labelsize=5.2, pad=1.2)
        _clean_axis(ax)

    fig.legend(handles=[
        Line2D([], [], color='.25', lw=.9, ls='-', marker='o', ms=2.2,
               label='Sample mean'),
        Line2D([], [], color='.25', lw=.9, ls='--', marker='s', ms=2.2,
               markerfacecolor='white', label='Sample max'),
        Line2D([], [], color='.25', lw=.9, ls=':', label='FP Bound'),
    ], loc='upper center', bbox_to_anchor=(.5, .985), ncol=3,
       frameon=False, fontsize=5., handlelength=1.15, columnspacing=.65,
       handletextpad=.25, labelspacing=.05, borderaxespad=0)
    fig.text(.5, .01, r'$n_t$', ha='center', va='bottom', fontsize=6.5)
    fig.text(.025, .51, 'Error probability', rotation=90,
             ha='center', va='center', fontsize=6.5)
    fig.subplots_adjust(left=.11, right=.99, bottom=.14, top=.90, wspace=.28)
    _save(fig, out)


def main():
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path,
                        default=here / 'results/production')
    parser.add_argument('--extension', type=Path,
                        default=here / 'results/extension_20260918')
    parser.add_argument('--out', type=Path, default=None)
    args = parser.parse_args()

    default_out = here / 'figures'
    out = default_out if args.out is None else args.out
    out.mkdir(parents=True, exist_ok=True)
    table = collect_noiseless((args.base, args.extension))
    plot_noiseless(table, out)
    print(f'Validated {len(table)} noiseless rows; wrote '
          f'{out / "noiseless_results_horizontal.pdf"} and '
          f'{out / "noiseless_results_horizontal.png"}.')


if __name__ == '__main__':
    main()
