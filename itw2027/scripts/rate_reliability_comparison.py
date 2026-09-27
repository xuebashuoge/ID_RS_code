#!/usr/bin/env python3
"""Plot the finite RS rate--reliability tradeoff and asymptotic rate gap.

Panel (a) retains the operational finite-length tradeoff from panel (b) of
``rate_results_revised.py``: at n_t=60 it plots the largest design rate

    R_exp = log2(m) / n_t

against the guaranteed error exponent E_2.  Panel (b) supplies the missing
information-theoretic context by comparing the asymptotic RS rate
1/[2(1+a)] with the previously known BFC achievability 1/(1+2a) for
S(m)=Theta(m**a).
"""
import numpy as np
import matplotlib.pyplot as plt

from rate_model import FAMILIES
from rate_results import _finite_rate
from rate_results_revised import FAMILY_LABELS, TRADEOFF_E2, TRADEOFF_N_T
from results_common import COLORS, clean_axis, csv_write, savefig


OUTPUT_NAME = 'rate_reliability_comparison'
EXPONENT_POINTS = 401
MAX_A = 4.0

RS_COLOR = '#0072B2'
BFC_COLOR = '#4D4D4D'


def rs_asymptotic_rate(a):
    """Zero-exponent intercept of the RS reliability boundary."""
    return 1.0 / (2.0 * (1.0 + np.asarray(a)))


def known_bfc_rate(a):
    """Known BFC achievable rate in the polynomial small-weight regime."""
    return 1.0 / (1.0 + 2.0 * np.asarray(a))


def comparison_data():
    """Build auditable data for both panels and write it as CSV."""
    rows = []
    for family in FAMILIES:
        for E_2 in TRADEOFF_E2:
            rows.append(dict(
                panel='finite-tradeoff', family=family,
                label=FAMILY_LABELS[family], a='', n_t=TRADEOFF_N_T,
                E_2=float(E_2),
                R_exp=_finite_rate(TRADEOFF_N_T, family, float(E_2)),
                target_bound=2.0 ** (-TRADEOFF_N_T * float(E_2)),
            ))

    for a in np.linspace(0.0, MAX_A, EXPONENT_POINTS):
        rows.append(dict(
            panel='rate-comparison', family='', label='', a=float(a),
            n_t='', E_2='', R_exp='', target_bound='',
            rs_rate=float(rs_asymptotic_rate(a)),
            known_bfc_rate=float(known_bfc_rate(a)),
        ))

    csv_write(OUTPUT_NAME + '.csv', rows)
    return rows


def figure_rate_reliability_comparison(rows):
    """Draw the finite tradeoff and the asymptotic rate comparison."""
    fig, axes = plt.subplots(1, 2, figsize=(3.5, 1.92))
    fig.subplots_adjust(left=.13, right=.995, bottom=.22, top=.88, wspace=.35)

    ax = axes[0]
    for family in FAMILIES:
        selected = [row for row in rows
                    if row['panel'] == 'finite-tradeoff'
                    and row['family'] == family]
        ax.plot([row['E_2'] for row in selected],
                [row['R_exp'] for row in selected],
                color=COLORS[family], lw=1.35)
        label_point = min(selected, key=lambda row: abs(row['E_2'] - .10))
        ax.annotate(
            FAMILY_LABELS[family],
            xy=(label_point['E_2'], label_point['R_exp']),
            xytext=(-4, {'id': 8, 'rank': -5,
                         'exact-threshold': -6}[family]),
            textcoords='offset points', color=COLORS[family],
            ha='right', va='center', fontsize=6.3,
        )

    ax.set_title(rf'(a) Finite tradeoff, $n_t={TRADEOFF_N_T}$',
                 fontsize=9, pad=3)
    ax.set_xlim(0, .26)
    ax.set_ylim(.08, .64)
    ax.set_xlabel(r'Error exponent $E_2$')
    ax.set_ylabel(r'Finite-blocklength rate')
    ax.set_xticks([0, 0.1, 0.2])
    ax.set_yticks([0.1, 0.2, .3, .4, .5, .6])
    # ax.set_yticklabels([r'$1/6$', r'$0.3$', r'$0.4$', r'$1/2$', r'$0.6$'])
    clean_axis(ax)

    ax = axes[1]
    selected = [row for row in rows if row['panel'] == 'rate-comparison']
    a = np.array([row['a'] for row in selected])
    rs_rate = np.array([row['rs_rate'] for row in selected])
    bfc_rate = np.array([row['known_bfc_rate'] for row in selected])
    # ax.fill_between(a, rs_rate, bfc_rate, color=RS_COLOR, alpha=.08, linewidth=0)
    ax.plot(a, bfc_rate, color=BFC_COLOR, ls='--', lw=1.25,
            label='BFC achievability')
    ax.plot(a, rs_rate, color=RS_COLOR, lw=1.35,
            label='RS tagging')

    task_a = np.array([0.0, 2.0])
    ax.plot(task_a, known_bfc_rate(task_a), ls='none', marker='o', ms=3.3,
            color=BFC_COLOR)
    ax.plot(task_a, rs_asymptotic_rate(task_a), ls='none', marker='s', ms=3.2,
            color=RS_COLOR)
    ax.axvline(2.0, color='0.72', ls=':', lw=.75)
    ax.text(.07, .95, 'ID / rank\n$a=0$', transform=ax.transAxes,
            fontsize=6.1, ha='left', va='top')
    ax.text(.54, .35, 'Exact\n$a=2$', transform=ax.transAxes,
            fontsize=6.1, ha='left', va='top')

    ax.set_title(r'(b) Small-weight regime', fontsize=9, pad=3)
    ax.set_xlim(-0.2, MAX_A+0.2)
    ax.set_ylim(0.07, 1.03)
    ax.set_xlabel(r'Parameter $a$')
    ax.set_ylabel(r'Asymptotic rate')
    ax.set_xticks([0, 1, 2, 3, 4])
    ax.set_yticks([0.1, 0.3, .5, 0.7, .9, 1.0])
    ax.legend(loc='upper right', frameon=False, fontsize=5.9,
              handlelength=1.5, handletextpad=.4, labelspacing=.2,
              borderaxespad=.25,
              bbox_to_anchor=(1.1, 0.8))
    clean_axis(ax)

    savefig(fig, OUTPUT_NAME)


def main():
    rows = comparison_data()
    figure_rate_reliability_comparison(rows)
    print(
        'Built the finite RS rate--reliability tradeoff and small-weight rate '
        f'comparison from {len(rows)} points.'
    )


if __name__ == '__main__':
    main()
