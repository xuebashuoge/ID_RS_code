#!/usr/bin/env python3
"""Build the two-panel finite-rate comparison used for the ITW results.

Panel (a) compares two fixed design exponents, while panel (b) shows the
vanishing exponent E_2(n_t)=n_t^{-1/2} together with the asymptotic rates.
The plotted tag lengths run from 24 through 10^4, where the vanishing exponent
is 10^-2.
"""
import math

import numpy as np

from rate_model import FAMILIES
from results_common import COLORS, clean_axis, csv_write, legend_line, savefig
import matplotlib.pyplot as plt


FIXED_E2 = (1e-1, 1e-2)
MIN_N_T = 24
MAX_N_T = 10_000


def _even_grid(count=70):
    """Log-spaced even tag lengths including both requested endpoints."""
    values = np.geomspace(MIN_N_T, MAX_N_T, count)
    result = {max(MIN_N_T, 2 * int(round(value / 2))) for value in values}
    result.update((MIN_N_T, MAX_N_T))
    return sorted(result)


def _finite_rate(n_t, family, E_2, rank=20, beta=2):
    """Evaluate the theorem design rate without constructing 2**500000.

    This is the logarithmic form of the inequalities in ``theorem_design``.
    When K is small enough to be represented exactly as a float, flooring is
    retained.  At larger K, omitting the floor changes the plotted rate by
    less than machine precision.
    """
    r = n_t / 2
    log2_budget = n_t * (0.5 - E_2)
    if family == 'id':
        log2_K = log2_budget
    elif family == 'rank':
        log2_K = log2_budget - math.log2(rank + 1)
    elif family == 'exact-threshold':
        log2_K = (
            math.log2(math.factorial(beta))
            + log2_budget
            - beta * math.log2(r)
        ) / (beta + 1)
    else:
        raise ValueError(family)

    log2_K = min(log2_K, n_t / 2)
    if log2_K < 0:
        return None
    if log2_K < 52:
        K = math.floor(2.0 ** log2_K)
        if K < 1:
            return None
        log2_K = math.log2(K)
    return (math.log2(r) + log2_K) / n_t


def _marker_positions(rows):
    """Mark representative lengths, leaving the first plotted point unmarked."""
    n_values = np.array([row['n_t'] for row in rows])
    targets = (32, 100, 320, 1_000, 3_200, 10_000)
    return sorted({int(np.argmin(abs(np.log(n_values) - math.log(target))))
                   for target in targets})


def rate_sequences():
    """Return the fixed- and vanishing-E_2 rate sequences for all families."""
    rows = []
    for family in FAMILIES:
        asymptotic = 1 / 6 if family == 'exact-threshold' else 1 / 2
        for E_2 in FIXED_E2:
            for n_t in _even_grid():
                rows.append(dict(
                    panel='fixed', family=family, sequence=f'E2={E_2:g}',
                    n_t=n_t, E_2=E_2,
                    rate=_finite_rate(n_t, family, E_2),
                    asymptotic=asymptotic,
                ))
        for n_t in _even_grid():
            E_2 = 1 / math.sqrt(n_t)
            rows.append(dict(
                panel='vanishing', family=family, sequence='E2=n_t^-1/2',
                n_t=n_t, E_2=E_2,
                rate=_finite_rate(n_t, family, E_2),
                asymptotic=asymptotic,
            ))
    csv_write('rate_results.csv', rows)
    return rows


def figure_rate_results(rows):
    """Draw fixed-E_2 and vanishing-E_2 rate comparisons against n_t."""
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
            positions = _marker_positions(selected)
            ax.plot(
                [row['n_t'] for row in selected],
                [row['rate'] for row in selected],
                color=COLORS[family], lw=1.0, ls=style['ls'],
                marker=style['marker'], ms=3.0,
                markerfacecolor=(COLORS[family] if style['markerfacecolor'] is None
                                 else style['markerfacecolor']),
                markeredgecolor=COLORS[family], markevery=positions,
            )
    ax.set_title(r'(a) Fixed $E_2$', fontsize=9, pad=3)
    ax.legend(handles=[
        legend_line(r'$E_2=10^{-1}$', color='0.25', ls='-', marker='o', ms=3),
        legend_line(r'$E_2=10^{-2}$', color='0.25', ls='--', marker='s', ms=3,
                    markerfacecolor='white'),
    ], loc='center', bbox_to_anchor=(.67, .39), frameon=False, fontsize=6.2,
       handlelength=1.35, handletextpad=.35, labelspacing=.08, borderaxespad=.2)
    for family in FAMILIES:
        selected = [row for row in rows
                    if row['panel'] == 'fixed'
                    and row['family'] == family
                    and row['E_2'] == 1e-1]
        label_point = min(selected, key=lambda row: abs(row['n_t'] - 100))
        ax.annotate(
            {'id': 'ID', 'rank': 'Rank', 'exact-threshold': 'Exact'}[family],
            xy=(label_point['n_t'], label_point['rate']),
            xytext={'id': (-2, 25), 'rank': (2, -10),
                    'exact-threshold': (0, -7)}[family],
            textcoords='offset points', color=COLORS[family],
            ha='right', va='center', fontsize=6.3,
        )

    ax = axes[1]
    for family in FAMILIES:
        selected = [row for row in rows
                    if row['panel'] == 'vanishing' and row['family'] == family]
        positions = _marker_positions(selected)
        ax.plot(
            [row['n_t'] for row in selected],
            [row['rate'] for row in selected],
            color=COLORS[family], lw=1.05, marker='s', ms=3,
            markerfacecolor='white', markeredgecolor=COLORS[family],
            markevery=positions,
        )
        ax.axhline(selected[0]['asymptotic'], color=COLORS[family], lw=.9, ls=':')
    ax.set_title(r'(b) Vanishing $E_2$', fontsize=9, pad=3)
    ax.legend(handles=[
        legend_line(r'$E_2=n_t^{-1/2}$', color='0.25', ls='-', marker='s', ms=3,
                    markerfacecolor='white'),
        legend_line('Asymptotic', color='0.25', ls=':'),
    ], loc='center right', frameon=False, fontsize=6.2,
       handlelength=1.35, handletextpad=.35, labelspacing=.08, borderaxespad=.2)
    for family in FAMILIES:
        selected = [row for row in rows
                    if row['panel'] == 'vanishing' and row['family'] == family]
        label_point = min(selected, key=lambda row: abs(row['n_t'] - 100))
        ax.annotate(
            {'id': 'ID', 'rank': 'Rank', 'exact-threshold': 'Exact'}[family],
            xy=(label_point['n_t'], label_point['rate']),
            xytext={'id': (-8, -8), 'rank': (5, -15),
                    'exact-threshold': (0, 7)}[family],
            textcoords='offset points', color=COLORS[family],
            ha='right', va='center', fontsize=6.3,
        )

    for ax in axes:
        ax.set_xscale('log')
        ax.set_xlim(19, 1.35e4)
        ax.set_ylim(.08, .64)
        ax.set_xlabel(r'$n_t$')
        ax.set_xticks([1e2, 1e3, 1e4])
        ax.set_yticks([1 / 6, .3, .4, .5, .6])
        ax.set_yticklabels([r'$1/6$', r'$0.3$', r'$0.4$', r'$1/2$', r'$0.6$'])
        clean_axis(ax)
    axes[0].set_ylabel(r'$R_t$')

    savefig(fig, 'rate_results')


def main():
    rows = rate_sequences()
    figure_rate_results(rows)
    print(f'Built rate results from {len(rows)} design points through n_t={MAX_N_T}.')


if __name__ == '__main__':
    main()
