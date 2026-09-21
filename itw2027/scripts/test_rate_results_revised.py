import unittest
from unittest.mock import patch

import matplotlib.pyplot as plt

import rate_results_revised as plotting


class RevisedRateResults(unittest.TestCase):
    def test_panel_b_is_rate_vs_E2_at_fixed_n_t(self):
        with patch.object(plotting, 'csv_write'):
            rows = plotting.revised_rate_sequences()

        tradeoff = [row for row in rows if row['panel'] == 'tradeoff']
        self.assertTrue(tradeoff)
        self.assertEqual({row['n_t'] for row in tradeoff}, {plotting.TRADEOFF_N_T})
        self.assertEqual({row['family'] for row in tradeoff}, set(plotting.FAMILIES))

        captured = {}
        with patch.object(
                plotting, 'savefig',
                side_effect=lambda fig, name: captured.update({name: fig})):
            plotting.figure_rate_results_revised(rows)
        try:
            fig = captured['rate_results_revised']
            self.assertEqual(tuple(fig.get_size_inches()), (3.5, 1.92))
            self.assertEqual(len(fig.axes), 2)
            self.assertEqual(fig.axes[1].get_xlabel(), r'$E_2$')
            self.assertIn(rf'$n_t={plotting.TRADEOFF_N_T}$', fig.axes[1].get_title())
            self.assertTrue(all(line.get_marker() in ('None', None, '')
                                for line in fig.axes[1].lines))
        finally:
            for fig in captured.values():
                plt.close(fig)


if __name__ == '__main__':
    unittest.main()
