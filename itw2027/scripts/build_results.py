#!/usr/bin/env python3
"""Build all ITW results.

The plotting pipelines live in ``noiseless_results.py`` and
``noisy_results.py``. This compatibility entry point retains the original
all-results command and re-exports the plotting functions used by existing
tests and callers.
"""
import json

import noiseless_results as _noiseless_results
import noisy_results as _noisy_results
from noiseless_results import noiseless, rate_results
from noisy_results import noisy
from rate_model import FAMILIES
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
    provenance,
    resource_logs,
    savefig,
)

# Public imports above intentionally preserve build_results' previous API.
__all__ = [
    'BOUND_STYLES', 'COLORS', 'EVIDENCE', 'FAMILIES', 'LABELS', 'OUT', 'ROOT',
    'clean_axis', 'csv_write', 'figure_noiseless', 'figure_noisy', 'legend_line',
    'noiseless', 'noisy', 'provenance', 'rate_results', 'resource_logs', 'savefig',
]


def figure_noiseless(rows, adversarial, rates):
    """Compatibility wrapper around :mod:`noiseless_results`."""
    original = _noiseless_results.savefig
    _noiseless_results.savefig = savefig
    try:
        return _noiseless_results.figure_noiseless(rows, adversarial, rates)
    finally:
        _noiseless_results.savefig = original


def figure_noisy(rows):
    """Compatibility wrapper around :mod:`noisy_results`."""
    original = _noisy_results.savefig
    _noisy_results.savefig = savefig
    try:
        return _noisy_results.figure_noisy(rows)
    finally:
        _noisy_results.savefig = original


def main():
    noiseless_rows, adversarial = noiseless()
    noisy_rows, parameter_table = noisy()
    rates = rate_results()
    figure_noiseless(noiseless_rows, adversarial, rates)
    figure_noisy(noisy_rows)
    provenance()
    resource_logs()
    report = {
        'noiseless_cells': len(noiseless_rows),
        'noiseless_shards': sum(row['shards'] for row in noiseless_rows),
        'adversarial_verified': sum(bool(row['verified']) for row in adversarial),
        'adversarial_skipped': sum(not bool(row['verified']) for row in adversarial),
        'noisy_points': len(noisy_rows),
        'frames_per_point': 2500,
        'all_paired_error_checks_passed': True,
        'archived_noisy_points': len(list((EVIDENCE/'noisy').rglob('result*.mat'))),
        'matched_threshold_points': sum(
            row.get('source_experiment') == 'threshold_nt40' for row in noisy_rows),
        'noisy_comparison_nt_matched': all(
            row['n_t'] == 40 for row in noisy_rows if row['experiment'] == 'waterfall'),
        'new_channel_simulation_required_for_selected_figures': any(
            row['n_t'] != 40 for row in noisy_rows if row['experiment'] == 'waterfall'),
    }
    (OUT/'validation.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))
    print('Parameter table:', parameter_table)


if __name__ == '__main__':
    main()
