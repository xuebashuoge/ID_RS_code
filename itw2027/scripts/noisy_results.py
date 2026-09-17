#!/usr/bin/env python3
"""Validate the noisy evidence and build the existing noisy result figures."""
import math

import numpy as np
from scipy.io import loadmat
from scipy.stats import beta as beta_distribution

from rate_model import FAMILIES, packing, support
from results_common import (
    BOUND_STYLES,
    COLORS,
    EVIDENCE,
    LABELS,
    OUT,
    ROOT,
    clean_axis,
    csv_write,
    legend_line,
    savefig,
)
import matplotlib.pyplot as plt


def noisy():
    rows = []
    for path in sorted((EVIDENCE/'noisy').rglob('result*.mat')):
        result = loadmat(path, simplify_cells=True)['result']
        derived = result['derived']
        bank = result['bank_metadata']
        counts = result['counts']
        per_frame = result['per_frame']
        assert result['complete'] and result['frames'] == 2500
        assert result['stopping']['mode'] == 'fixed_frames'
        assert result['config']['ldpc']['algorithm'] == 'bp'
        family = bank['func_type']
        support_size = support(int(derived['m']), family)
        assert support_size == bank['S']
        assert derived['L'] == 2**derived['r']
        assert derived['rs_evaluation_order'] == 'extended-zero-first-v1'
        packed = packing(
            int(derived['n']), int(derived['m']),
            int(derived['ldpc_N']), int(derived['ldpc_K']),
        )
        assert abs(packed['R_eff']-derived['parallel_bfc_rate']) < 1e-12
        assert packed['G'] == derived['tuples_per_frame']

        actual_zero = np.asarray(per_frame['actual_zero'], dtype=float)
        actual_one = np.asarray(per_frame['actual_one'], dtype=float)
        frame_error = np.asarray(per_frame['ldpc_error'], dtype=float)
        false_positive = np.asarray(per_frame['coded_false_positive'], dtype=float)
        false_negative = np.asarray(per_frame['coded_false_negative'], dtype=float)
        intrinsic = np.asarray(per_frame['noiseless_false_positive'], dtype=float)
        assert len(false_positive) == result['frames']
        assert false_positive.sum() == counts['coded']['false_positive']
        assert false_negative.sum() == counts['coded']['false_negative']
        assert actual_zero.sum() == counts['coded']['actual_zero']
        assert actual_one.sum() == counts['coded']['actual_one']
        assert np.all(false_positive <= intrinsic+actual_zero*frame_error)
        assert np.all(false_negative <= actual_one*frame_error)
        assert np.all(false_negative[frame_error == 0] == 0)
        assert np.all(false_positive[frame_error == 0] == intrinsic[frame_error == 0])

        frames = len(frame_error)
        frame_errors = int(frame_error.sum())
        fer = frame_errors/frames
        fer_lower = (0 if frame_errors == 0 else
                     beta_distribution.ppf(.025, frame_errors, frames-frame_errors+1))
        fer_upper = (1 if frame_errors == frames else
                     beta_distribution.ppf(.975, frame_errors+1, frames-frame_errors))
        bound = support_size*(derived['K']-1)/derived['L']
        intervals = result['metrics']['coded']['cluster_conditional_ci95']
        fp_count = int(false_positive.sum())
        fn_count = int(false_negative.sum())
        negative_trials = int(actual_zero.sum())
        positive_trials = int(actual_one.sum())
        fpr = fp_count/negative_trials
        fnr = fn_count/positive_trials

        rows.append(dict(
            experiment=path.relative_to(EVIDENCE/'noisy').parts[0],
            family=family,
            n_t=int(derived['n']),
            m=int(derived['m']),
            K=int(derived['K']),
            T=int(derived['L']),
            S=support_size,
            bound=bound,
            **packed,
            ebno_db=result['scenario']['ebno_db'],
            frames=frames,
            frame_errors=frame_errors,
            fer=fer,
            fer_lower95=fer_lower,
            fer_upper95=fer_upper,
            fpr=fpr,
            fnr=fnr,
            noiseless_fpr=intrinsic.sum()/negative_trials,
            fpr_lower95=intervals['fpr'][0],
            fpr_upper95=intervals['fpr'][1],
            fnr_lower95=intervals['fnr'][0],
            fnr_upper95=intervals['fnr'][1],
            max_error=max(fpr, fnr),
            max_lower95=intervals['max'][0],
            max_upper95=intervals['max'][1],
            fp_count=fp_count,
            fn_count=fn_count,
            negative_trials=negative_trials,
            positive_trials=positive_trials,
            bad_frame_given_negative=(actual_zero*frame_error).sum()/negative_trials,
            bad_frame_given_positive=(actual_one*frame_error).sum()/positive_trials,
            zero_frame_upper95=-math.expm1(math.log(.05)/frames),
            fpr_zero_upper95=-math.expm1(math.log(.05)/frames)*frames*actual_zero.max()/negative_trials,
            fnr_zero_upper95=-math.expm1(math.log(.05)/frames)*frames*actual_one.max()/positive_trials,
            diagnostic_fp_envelope=min(1, bound+fer),
            runtime_hours=result['runtime_seconds']/3600,
            seed=result['scenario']['seed'],
            source=str(path.relative_to(ROOT)),
        ))

    replacement = [row for row in rows if row['experiment'] == 'threshold_nt40']
    legacy = [row for row in rows if row['experiment'] in ('waterfall', 'rate_pareto')]
    assert len(legacy) == 126
    assert sum(row['experiment'] == 'waterfall' for row in legacy) == 66
    csv_write('noisy_archived_and_new_points.csv', rows)
    if replacement:
        assert len(replacement) == 22, (
            'Incomplete n_t=40 replacement: export all 22 points before rebuilding.')
        assert all(row['family'] == 'exact-threshold' and row['n_t'] == 40
                   for row in replacement)
        assert {round(row['ebno_db'], 6) for row in replacement} == {
            round(.5+.1*index, 6) for index in range(22)}
        assert all((row['K'], row['m'], row['S'], row['G'], row['padding'], row['R_c'])
                   == (6, 120, 7140, 810, 0, .5) for row in replacement)
        rows = [row for row in legacy
                if not (row['experiment'] == 'waterfall'
                        and row['family'] == 'exact-threshold')]
        rows += [dict(row, experiment='waterfall', source_experiment='threshold_nt40')
                 for row in replacement]
    else:
        rows = legacy

    csv_write('noisy_all_points.csv', rows)
    representative = [row for row in rows
                      if row['experiment'] == 'waterfall'
                      and abs(row['ebno_db']-1.5) < 1e-8]
    csv_write('representative_1p5dB.csv', representative)
    table = []
    for row in sorted(representative, key=lambda item: FAMILIES.index(item['family'])):
        table.append({key: row[key] for key in [
            'family', 'n_t', 'm', 'K', 'T', 'S', 'bound', 'G', 'padding',
            'n_eff', 'R_eff', 'packing_gain']}
            | {'R_t': math.log2(row['m'])/row['n_t'],
               'R_asymptotic_noiseless': 1/6 if row['family'] == 'exact-threshold' else .5,
               'R_asymptotic_noisy': 1/12 if row['family'] == 'exact-threshold' else .25})
    csv_write('paper_parameters.csv', table)
    lines = [
        r'\begin{tabular}{lrrrrrr}', r'\hline',
        r'Function & $n_t$ & $m$ & $S$ & $R_t$ & $G$ & $R_{\rm eff}$\\',
        r'\hline',
    ]
    for row in table:
        label = {'id': 'ID', 'rank': 'Rank (20)',
                 'exact-threshold': r'Exact ($\beta=2$)'}[row['family']]
        lines.append(
            f"{label} & {row['n_t']} & {row['m']:,} & {row['S']:,} & "
            f"{row['R_t']:.3f} & {row['G']} & {row['R_eff']:.3f}"+r'\\')
    lines.extend([r'\hline', r'\end{tabular}'])
    (OUT/'tables/paper_parameters.tex').write_text('\n'.join(lines)+'\n')
    return rows, table


def figure_noisy(rows):
    """Draw the existing noisy result figure and optional rate tradeoff."""
    fig = plt.figure(figsize=(3.5, 1.92))
    grid = fig.add_gridspec(
        3, 2, left=.14, right=.99, bottom=.20, top=.88,
        width_ratios=[1, 1], hspace=.12, wspace=.31,
    )
    left_axes = [fig.add_subplot(grid[index, 0]) for index in range(3)]
    right = fig.add_subplot(grid[:, 1])
    for index, family in enumerate(FAMILIES):
        selected = sorted(
            [row for row in rows
             if row['family'] == family and row['experiment'] == 'waterfall'],
            key=lambda row: row['ebno_db'],
        )
        x_values = np.array([row['ebno_db'] for row in selected])
        color = COLORS[family]
        left = left_axes[index]
        left.plot(x_values, [row['fer'] for row in selected], color='0.3',
                  ls='none', marker='s', ms=3.4, markerfacecolor='none', zorder=2)
        left.plot(x_values, [row['fnr'] for row in selected], color=color,
                  lw=.75, marker='o', ms=1.8, zorder=3)
        right.plot(x_values, [row['diagnostic_fp_envelope'] for row in selected],
                   color=color, linestyle=BOUND_STYLES[family], lw=.75, zorder=1)
        right.plot(x_values, [row['noiseless_fpr'] for row in selected],
                   color=color, lw=.7, zorder=2)
        fpr = [row['fpr'] for row in selected]
        right.plot(x_values, fpr, color=color, ls='none', marker='o', ms=2.7,
                   markerfacecolor='white', markeredgewidth=.8, zorder=4)
        right.annotate(
            {'id': 'ID', 'rank': 'Rank', 'exact-threshold': 'Exact'}[family],
            xy=(x_values[-1], fpr[-1]),
            xytext={'id': (-4, 5), 'rank': (0, 5), 'exact-threshold': (0, -6)}[family],
            textcoords='offset points', color=color, ha='right', va='center', fontsize=6.3,
        )
        left.set_yscale('symlog', linthresh=1e-6, linscale=.5)
        left.set_ylim(-1.2e-7, 1.5)
        left.set_xlim(.44, 2.66)
        left.set_yticks([0, 1e-3, 1])
        endpoint_labels = left.set_yticklabels(['0', r'$10^{-3}$', '1'])
        endpoint_labels[0].set_verticalalignment('bottom')
        endpoint_labels[-1].set_verticalalignment('top')
        left.set_xticks([.5, 1.5, 2.5])
        clean_axis(left)
        left.text(.97, .91, {'id': 'ID', 'rank': 'Rank',
                             'exact-threshold': 'Exact'}[family],
                  transform=left.transAxes, ha='right', va='top',
                  fontsize=7, color=color)
        if index < 2:
            left.tick_params(labelbottom=False)
    left_axes[0].set_title('(a) FN / FER', fontsize=9, pad=2)
    left_axes[0].legend(handles=[
        legend_line('FN', color='0.25', ls='-', marker='o', ms=2),
        legend_line('FER', color='0.3', ls='none', marker='s', ms=3.2,
                    markerfacecolor='none'),
    ], loc='upper right', bbox_to_anchor=(1.05, .75), frameon=False,
       fontsize=6.5, ncol=1, columnspacing=.6, labelspacing=.08,
       handlelength=1.1, handletextpad=.3, borderpad=.1)
    left_axes[1].set_ylabel('Error probability', labelpad=1)
    left_axes[-1].set_xlabel(r'$E_b/N_0$ (dB)')

    right.set_yscale('symlog', linthresh=1e-6, linscale=.5)
    right.set_ylim(-1.2e-7, 1.5)
    right.set_xlim(.44, 2.66)
    right.set_yticks([0, 1e-3, 1])
    right.set_yticklabels(['0', r'$10^{-3}$', '1'])
    right.set_xticks([.5, 1.5, 2.5])
    right.set_xlabel(r'$E_b/N_0$ (dB)')
    right.set_title('(b) FP', fontsize=9, pad=2)
    clean_axis(right)
    right.legend(handles=[
        legend_line('FP', color='0.25', ls='none', marker='o', ms=2.8,
                    markerfacecolor='white'),
        legend_line('Noiseless', color='0.25', ls='-', lw=.7),
        legend_line('Bound', color='0.25', ls=BOUND_STYLES['exact-threshold'], lw=.75),
    ], loc='center', bbox_to_anchor=(.52, .48), ncol=3, frameon=False,
       fontsize=6.2, columnspacing=.55, labelspacing=.08, handlelength=1.2,
       handletextpad=.25, borderpad=.1)
    savefig(fig, 'figure2_noisy')

    with plt.rc_context({'font.size': 10, 'axes.labelsize': 10, 'legend.fontsize': 10}):
        fig, ax = plt.subplots(figsize=(3.5, 2.7), layout='constrained')
        for family in FAMILIES:
            selected = sorted(
                [row for row in rows
                 if row['family'] == family and row['experiment'] == 'rate_pareto'
                 and abs(row['ebno_db']-1.5) < 1e-8],
                key=lambda row: row['n_eff'],
            )
            ax.plot([row['n_eff'] for row in selected],
                    [row['max_error'] for row in selected], '-o',
                    color=COLORS[family], ms=3, label=LABELS[family])
        ax.set(yscale='log', xlabel=r'Effective uses $N_b/G$',
               ylabel=r'$\max(\widehat P_{\rm FP},\widehat P_{\rm FN})$',
               title='Optional: rate tradeoff at 1.5 dB')
        ax.legend(fontsize=10)
        ax.grid(alpha=.2)
        savefig(fig, 'optional_rate_tradeoff')


def main():
    rows, _ = noisy()
    figure_noisy(rows)
    print(f'Built noisy results from {len(rows)} selected points.')


if __name__ == '__main__':
    main()
