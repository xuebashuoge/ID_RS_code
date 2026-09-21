#!/usr/bin/env python3
"""Build the revised two-panel finite-rate figure.

Panel (a) retains the fixed-E_2 rate sequences from ``rate_results.py``.
Panel (b) directly displays the rate--error-exponent trade-off at n_t=40.
"""
import numpy as np

from rate_model import FAMILIES
from rate_results import (
    FIXED_E2,
    MAX_N_T,
    _even_grid,
    _finite_rate,
    _marker_positions,
)
from results_common import COLORS, clean_axis, csv_write, legend_line, savefig
import matplotlib.pyplot as plt


TRADEOFF_N_T = 40
TRADEOFF_E2 = np.linspace(.01, .25, 97)
FAMILY_LABELS = {'id': 'ID', 'rank': 'Rank', 'exact-threshold': 'Exact'}


def revised_rate_sequences():
    """Return the fixed-length sequences and the n_t=40 E_2 trade-off."""
    rows = []
    for family in FAMILIES:
        for E_2 in FIXED_E2:
            for n_t in _even_grid():
                rows.append(dict(
                    panel='fixed', family=family, sequence=f'E2={E_2:g}',
                    n_t=n_t, E_2=E_2,
                    rate=_finite_rate(n_t, family, E_2),
                    target_bound=2.0 ** (-n_t * E_2),
                ))
        for E_2 in TRADEOFF_E2:
            rows.append(dict(
                panel='tradeoff', family=family, sequence='fixed_n_t',
                n_t=TRADEOFF_N_T, E_2=float(E_2),
                rate=_finite_rate(TRADEOFF_N_T, family, float(E_2)),
                target_bound=2.0 ** (-TRADEOFF_N_T * float(E_2)),
            ))
    csv_write('rate_results_revised.csv', rows)
    return rows


def figure_rate_results_revised(rows):
    """Draw the fixed-E_2 sequences and direct rate--E_2 trade-off."""
    fig, axes = plt.subplots(1, 2, figsize=(3.5, 1.92), sharey=True)
    fig.subplots_adjust(left=.13, right=.995, bottom=.21, top=.91, wspace=.18)

    fixed_styles = {
        1e-1: dict(ls='-', marker='o', markerfacecolor=None),
        1e-2: dict(ls='--', marker='s', markerfacecolor='white'),
    }
    ax = axes[0]
    for family in FAMILIES:
        for E_2 in FIXED_E2:
            selected = [row for row in rows
                        if row['panel'] == 'fixed'
                        and row['family'] == family
                        and row['E_2'] == E_2]
            style = fixed_styles[E_2]
            ax.plot(
                [row['n_t'] for row in selected],
                [row['rate'] for row in selected],
                color=COLORS[family], lw=1.0, ls=style['ls'],
                # marker=style['marker'], ms=3.0,
                # markerfacecolor=(COLORS[family] if style['markerfacecolor'] is None
                #                  else style['markerfacecolor']),
                # markeredgecolor=COLORS[family],
                # markevery=_marker_positions(selected),
            )
    ax.set_title(r'(a) Fixed $E_2$', fontsize=9, pad=3)
    ax.legend(handles=[
        legend_line(r'$E_2=10^{-1}$', color='0.25', ls='-', 
                    # marker='o', ms=3
                    ),
        legend_line(r'$E_2=10^{-2}$', color='0.25', ls='--', 
                    # marker='s', ms=3,
                    # markerfacecolor='white'
                    ),
    ], loc='center', bbox_to_anchor=(.67, .39), frameon=False, fontsize=6.2,
       handlelength=1.6, handletextpad=.35, labelspacing=.08, borderaxespad=.2)
    for family in FAMILIES:
        selected = [row for row in rows
                    if row['panel'] == 'fixed'
                    and row['family'] == family
                    and row['E_2'] == 1e-1]
        label_point = min(selected, key=lambda row: abs(row['n_t'] - 100))
        ax.annotate(
            FAMILY_LABELS[family], xy=(label_point['n_t'], label_point['rate']),
            xytext={'id': (-2, 25), 'rank': (2, -10),
                    'exact-threshold': (0, -7)}[family],
            textcoords='offset points', color=COLORS[family],
            ha='right', va='center', fontsize=6.3,
        )
    ax.set_xscale('log')
    ax.set_xlim(19, 1.35e4)
    ax.set_xlabel(r'$n_t$')
    ax.set_xticks([1e2, 1e3, 1e4])

    ax = axes[1]
    for family in FAMILIES:
        selected = [row for row in rows
                    if row['panel'] == 'tradeoff' and row['family'] == family]
        ax.plot(
            [row['E_2'] for row in selected],
            [row['rate'] for row in selected],
            color=COLORS[family], lw=1.05, ls='-',
        )
        label_point = min(selected, key=lambda row: abs(row['E_2'] - .10))
        ax.annotate(
            FAMILY_LABELS[family], xy=(label_point['E_2'], label_point['rate']),
            xytext=(-4, {'id': 8, 'rank': -5, 'exact-threshold': -6}[family]),
            textcoords='offset points', color=COLORS[family],
            ha='right', va='center', fontsize=6.3,
        )
    ax.set_title(r'(b) Fixed $n_t=40$', fontsize=9, pad=3)
    ax.set_xlim(0, .26)
    ax.set_xlabel(r'$E_2$')
    ax.set_xticks([.05, .10, .15, .20, .25])

    for ax in axes:
        ax.set_ylim(.08, .64)
        ax.set_yticks([1 / 6, .3, .4, .5, .6])
        ax.set_yticklabels([r'$1/6$', r'$0.3$', r'$0.4$', r'$1/2$', r'$0.6$'])
        clean_axis(ax)
    axes[0].set_ylabel(r'$R_t$')
    savefig(fig, 'rate_results_revised')


def main():
    rows = revised_rate_sequences()
    figure_rate_results_revised(rows)
    print(
        f'Built revised rate results from {len(rows)} design points; '
        f'panel (b) uses n_t={TRADEOFF_N_T}.'
    )


if __name__ == '__main__':
    main()
