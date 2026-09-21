#!/usr/bin/env python3
"""Plot vertically separated noiseless and noisy nt=60 results."""
import argparse
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np

from noiseless_noisy_results import (
    FAMILIES,
    FAMILY_COLORS,
    FAMILY_LABELS,
    FIGSIZE,
    _clean_axis,
    _series,
    collect_noiseless,
)
from noiseless_noisy_results_nt60 import collect_noisy


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
            mask &= y > empirical_floor

        color = FAMILY_COLORS[family]
        ax.plot(x[mask], y[mask], color=color, lw=.8, ls='-', marker='o',
                ms=1.9, markerfacecolor=color, markeredgecolor=color,
                markeredgewidth=.6)
        ax.hlines(fp_bound, *bfc_limits, color=color, lw=.7, ls=':')
        ax.text(.025, .5, FAMILY_LABELS[family], transform=ax.transAxes,
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

    exact_bfc_ax.set_xticks([-5., -4.5, -4.])
    exact_conventional_ax.set_xticks([1.5, 2., 2.2])
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
    rank_ax = fig.add_subplot(noisy_grid[1, :], sharex=id_ax)
    exact_bfc_ax = fig.add_subplot(noisy_grid[2, 0], sharex=id_ax)
    exact_conventional_ax = fig.add_subplot(
        noisy_grid[2, 1], sharey=exact_bfc_ax)

    _plot_noiseless(noiseless_axes, table)
    _plot_noisy(
        (id_ax, rank_ax, exact_bfc_ax, exact_conventional_ax), records)

    fig.text(.245, .975, '(a) Noiseless channel', ha='center', va='top',
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

    out = args.noisy if args.out is None else args.out
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
