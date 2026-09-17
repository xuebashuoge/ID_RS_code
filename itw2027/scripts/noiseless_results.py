#!/usr/bin/env python3
"""Validate the noiseless evidence and build the noiseless result figure."""
import math

import numpy as np
from scipy.io import loadmat

from rate_model import FAMILIES, support, theorem_design, certificate
from results_common import (
    BOUND_STYLES,
    COLORS,
    EVIDENCE,
    ROOT,
    clean_axis,
    csv_write,
    legend_line,
    savefig,
)
import matplotlib.pyplot as plt


def noiseless():
    groups = {}
    runs = []
    seeds = set()
    for path in sorted((EVIDENCE/'noiseless/finite_length').glob('*.mat')):
        data = loadmat(path, simplify_cells=True)
        metadata, stats = data['metadata'], data['stat']
        family, n_t = metadata['func_type'], int(metadata['n'])
        key = (family, n_t)
        counts = np.atleast_1d(stats['R_counts'])
        probabilities = np.atleast_1d(stats['fpr_exact'])
        assert len(counts) == metadata['num_negative_messages']
        assert (family, n_t, metadata['seed']) not in seeds, 'Duplicate shard seed'
        seeds.add((family, n_t, metadata['seed']))
        support_size = support(int(metadata['m']), family)
        assert support_size == metadata['S'] and metadata['m'] == metadata['r']*metadata['K']
        bound = support_size*(metadata['K']-1)/metadata['L']
        assert np.allclose(probabilities, counts/metadata['L'], atol=0, rtol=0)
        assert np.all(probabilities <= bound+1e-15)
        design = theorem_design(n_t, family)
        assert design['K'] == metadata['K'], (family, n_t, 'legacy design mismatch')
        groups.setdefault(key, []).append((metadata, probabilities))
        runs.append(dict(file=str(path.relative_to(ROOT)), **metadata))

    assert len(groups) == 27, f'Expected 27 noiseless cells, got {len(groups)}'
    rows = []
    for (family, n_t), items in sorted(groups.items()):
        metadata = items[0][0]
        probabilities = np.concatenate([item[1] for item in items])
        assert all(item[0]['K'] == metadata['K'] for item in items)
        rows.append(dict(
            family=family,
            n_t=n_t,
            m=int(metadata['m']),
            r=int(metadata['r']),
            K=int(metadata['K']),
            T=int(metadata['L']),
            S=int(metadata['S']),
            R_t=math.log2(metadata['m'])/n_t,
            bound=metadata['theorem_bound'],
            count=len(probabilities),
            shards=len(items),
            q05=np.quantile(probabilities, .05),
            median=np.median(probabilities),
            q95=np.quantile(probabilities, .95),
            sample_max=probabilities.max(),
            sample_mean=probabilities.mean(),
            zero_count=int(sum(probabilities == 0)),
        ))

    adversarial = []
    for path in sorted((EVIDENCE/'noiseless/adversarial').glob('*.mat')):
        metadata = loadmat(path, simplify_cells=True)['metadata']
        if metadata['verified']:
            assert metadata['observed_R'] == metadata['S']*(metadata['K']-1)
        adversarial.append(dict(
            **metadata,
            interpretation='arbitrary support of matching size; not the named rank/threshold function',
        ))

    csv_write('noiseless_distribution.csv', rows)
    csv_write('noiseless_runs.csv', runs)
    csv_write('adversarial_verification.csv', adversarial)
    return rows, adversarial


def rate_results():
    rows = []
    for family in FAMILIES:
        for n_t in sorted(set(range(24, 202, 2)) | {256, 512, 1024, 2048, 4096}):
            for name, exponent in [('fixed_E', .1), ('vanishing_E', 1/math.sqrt(n_t))]:
                design = theorem_design(n_t, family, exponent)
                if design:
                    rows.append({'family': family, 'sequence': name, **design})
    csv_write('rate_sequences.csv', rows)

    finite = []
    for family in FAMILIES:
        for n_t in range(12, 81):
            for aligned in (True, False):
                design = certificate(n_t, family, aligned=aligned)
                if design:
                    finite.append(dict(family=family, epsilon=.01, **design))
    csv_write('finite_rate_at_1percent.csv', finite)
    return rows


def figure_noiseless(rows, adversarial, rates):
    """Draw the two-panel noiseless false-positive and rate figure."""
    del adversarial  # Retained in the API because it is validated with the plotted data.
    fig, axes = plt.subplots(1, 2, figsize=(3.5, 1.92))
    fig.subplots_adjust(left=.12, right=.995, bottom=.16, top=.94, wspace=.31)

    ax = axes[0]
    for family in FAMILIES:
        selected = sorted(
            [row for row in rows if row['family'] == family],
            key=lambda row: row['n_t'],
        )
        x_values = [row['n_t'] for row in selected]
        color = COLORS[family]
        ax.plot(x_values, [row['bound'] for row in selected], color=color,
                linestyle=BOUND_STYLES[family], lw=.75, zorder=1)
        ax.plot(x_values, [row['sample_max'] for row in selected], ls='none',
                marker='s', ms=4, markerfacecolor='none', markeredgecolor=color,
                markeredgewidth=.8, zorder=3)
        means = [row['sample_mean'] for row in selected]
        ax.plot(x_values, means, color=color, lw=.75, marker='o', ms=2.2, zorder=4)
        ax.annotate(
            {'id': 'ID', 'rank': 'Rank', 'exact-threshold': 'Exact'}[family],
            xy=(x_values[-1], means[-1]),
            xytext={'id': (-4, -2), 'rank': (0, 15), 'exact-threshold': (-2, -4)}[family],
            textcoords='offset points', color=color, ha='right', va='center', fontsize=6.3,
        )
    ax.set(yscale='log', ylim=(3e-7, .4), xlim=(23, 40.5),
           xlabel=r'$n_t$', ylabel='FP probability')
    ax.set_yticks([1e-6, 1e-3, 1e-1])
    ax.set_xticks([24, 32, 40])
    ax.yaxis.labelpad = 1
    ax.set_title('(a) FP error', fontsize=9, pad=2)
    clean_axis(ax)
    ax.legend(handles=[
        legend_line('Mean', color='0.25', lw=.75, marker='o', markersize=2),
        legend_line('Max', color='0.25', ls='none', marker='s', markersize=4,
                    markerfacecolor='none'),
        legend_line('Bound', color='0.25', ls=BOUND_STYLES['exact-threshold'], lw=.75),
    ], loc='lower left', bbox_to_anchor=(.01, .02), frameon=False, fontsize=6.5,
       handlelength=1.2, handletextpad=.35, labelspacing=.08, borderaxespad=0)

    ax = axes[1]
    for family in FAMILIES:
        for sequence, style, marker, face in [
                ('fixed_E', '-', 'o', COLORS[family]),
                ('vanishing_E', '--', 's', 'white')]:
            selected = [row for row in rates
                        if row['family'] == family and row['sequence'] == sequence]
            targets = {
                'id': [32, 64, 128, 512, 2048],
                'rank': [44, 88, 176, 256, 1024, 4096],
                'exact-threshold': [36, 72, 144, 512, 2048],
            }[family]
            n_values = np.array([row['n_t'] for row in selected])
            positions = sorted({int(np.argmin(abs(np.log(n_values)-np.log(target))))
                                for target in targets})
            ax.plot(n_values, [row['rate'] for row in selected], style,
                    color=COLORS[family], lw=.85, marker=marker, ms=2.8,
                    markerfacecolor=face, markeredgecolor=COLORS[family],
                    markevery=positions)
        ax.annotate(
            {'id': 'ID', 'rank': 'Rank', 'exact-threshold': 'Exact'}[family],
            xy=(selected[0]['n_t'], selected[0]['rate']),
            xytext={'id': (5, 25), 'rank': (15, -5), 'exact-threshold': (20, -8)}[family],
            textcoords='offset points', color=COLORS[family], ha='right', va='center',
            fontsize=6.3,
        )
    ax.axhline(.5, color='0.5', lw=.9, ls=':')
    ax.axhline(1/6, color='0.5', lw=.9, ls=':')
    ax.text(4300, .506, r'$1/2$', ha='right', va='bottom', fontsize=8)
    ax.text(4300, .174, r'$1/6$', ha='right', va='bottom', fontsize=8)
    ax.set(xscale='log', xlabel=r'$n_t$', ylabel=r'$R_t$', ylim=(.08, .62))
    ax.set_yticks([.2, .4, .6])
    ax.set_xticks([100, 1000])
    ax.yaxis.labelpad = 1
    ax.set_title('(b) Rate', fontsize=9, pad=2)
    clean_axis(ax)
    ax.legend(handles=[
        legend_line(r'$E=0.1$', color='0.25', ls='-', marker='o', ms=2.4),
        legend_line(r'$E=n_t^{-1/2}$', color='0.25', ls='--', marker='s', ms=3,
                    markerfacecolor='white'),
        legend_line('Asymptotic', color='0.5', ls=':'),
    ], loc='center', bbox_to_anchor=(.55, .38), frameon=False, fontsize=6.3,
       handlelength=1.1, handletextpad=.3, labelspacing=.08, borderpad=.1)
    savefig(fig, 'figure1_noiseless')


def main():
    rows, adversarial = noiseless()
    rates = rate_results()
    figure_noiseless(rows, adversarial, rates)
    print(f'Built noiseless results from {len(rows)} cells and {len(rates)} rate points.')


if __name__ == '__main__':
    main()
