#!/usr/bin/env python3
"""Build a three-panel noisy figure with channel and FP references per family."""
import numpy as np

from rate_model import FAMILIES
from results_common import COLORS, LABELS, clean_axis, legend_line, savefig
from noisy_results import noisy
import matplotlib.pyplot as plt


def aggregate_error_probabilities(row):
    """Return FER, FN, and FP probabilities calculated from aggregate counts."""
    frames = int(row['frames'])
    positive_messages = int(row['positive_trials'])
    negative_messages = int(row['negative_trials'])
    if frames <= 0 or positive_messages <= 0 or negative_messages <= 0:
        raise ValueError('FER, FN, and FP denominators must all be positive')
    return (
        row['frame_errors']/frames,
        row['fn_count']/positive_messages,
        row['fp_count']/negative_messages,
    )


def figure_noisy_three_panel(rows):
    """Draw FER/FN/FP plus noiseless FP and its upper bound per family."""
    fig, axes = plt.subplots(3, 1, figsize=(3.5, 3.05), sharex=True, sharey=True)
    fig.subplots_adjust(left=.14, right=.99, bottom=.12, top=.96, hspace=.12)

    for index, (axis, family) in enumerate(zip(axes, FAMILIES)):
        selected = sorted(
            [row for row in rows
             if row['family'] == family and row['experiment'] == 'waterfall'],
            key=lambda row: row['ebno_db'],
        )
        if not selected:
            raise ValueError(f'No waterfall rows found for {family}')
        x_values = np.asarray([row['ebno_db'] for row in selected])
        probabilities = [aggregate_error_probabilities(row) for row in selected]
        fer, fn, fp = (np.asarray(values) for values in zip(*probabilities))
        noiseless_fp = np.asarray([row['noiseless_fpr'] for row in selected])
        fp_upper_bound = np.asarray(
            [row['diagnostic_fp_envelope'] for row in selected])
        color = COLORS[family]

        # These treatments mirror the existing noisy figure: hollow squares
        # for FER, filled circles and a solid line for FN, and hollow circles
        # for FP.  A light dotted connector makes the FP trend readable when
        # points do not coincide with FN.
        axis.plot(x_values, fer, color='0.3', ls='none', marker='s', ms=3.6,
                  markerfacecolor='none', markeredgewidth=.8, zorder=2)
        axis.plot(x_values, fn, color=color, lw=.75, marker='o', ms=1.9, zorder=4)
        axis.plot(x_values, fp, color=color, ls=':', lw=.65, marker='o', ms=2.8,
                  markerfacecolor='white', markeredgewidth=.8, zorder=3)
        axis.plot(x_values, noiseless_fp, color='0.25', ls='-', lw=.65,
                  zorder=1)
        axis.plot(x_values, fp_upper_bound, color='0.45', ls='--', lw=.7,
                  zorder=1)

        axis.set_yscale('symlog', linthresh=1e-6, linscale=.5)
        axis.set_ylim(-1.2e-7, 1.5)
        axis.set_xlim(.44, 2.66)
        axis.set_yticks([0, 1e-3, 1])
        endpoint_labels = axis.set_yticklabels(['0', r'$10^{-3}$', '1'])
        endpoint_labels[0].set_verticalalignment('bottom')
        endpoint_labels[-1].set_verticalalignment('top')
        axis.set_xticks([.5, 1.5, 2.5])
        clean_axis(axis)
        axis.text(.98, .91, LABELS[family], transform=axis.transAxes,
                  ha='right', va='top', fontsize=7, color=color)
        if index < len(FAMILIES)-1:
            axis.tick_params(labelbottom=False)

    axes[0].legend(handles=[
        legend_line('FER', color='0.3', ls='none', marker='s', ms=3.4,
                    markerfacecolor='none'),
        legend_line('FN', color='0.25', ls='-', marker='o', ms=2),
        legend_line('FP', color='0.25', ls=':', marker='o', ms=2.8,
                    markerfacecolor='white'),
        legend_line('Noiseless FP', color='0.25', ls='-', lw=.65),
        legend_line('FP bound', color='0.45', ls='--', lw=.7),
    ], loc='upper left', bbox_to_anchor=(.30, .98), ncol=3, frameon=False,
       fontsize=6.2, columnspacing=.7, labelspacing=.08, handlelength=1.2,
       handletextpad=.3, borderpad=.1)
    axes[1].set_ylabel('Error probability', labelpad=1)
    axes[-1].set_xlabel(r'$E_b/N_0$ (dB)')
    savefig(fig, 'figure2_noisy_three_panel')


def main():
    rows, _ = noisy()
    figure_noisy_three_panel(rows)
    print(f'Built three-panel noisy results from {len(rows)} selected points.')


if __name__ == '__main__':
    main()
