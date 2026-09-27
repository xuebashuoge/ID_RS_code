import unittest
from unittest.mock import patch

import matplotlib.pyplot as plt

import rate_reliability_comparison as plotting


class RateReliabilityComparison(unittest.TestCase):
    def test_finite_tradeoff_and_comparison(self):
        self.assertAlmostEqual(plotting.rs_asymptotic_rate(0), 0.5)
        self.assertAlmostEqual(plotting.rs_asymptotic_rate(2), 1/6)
        self.assertAlmostEqual(plotting.known_bfc_rate(0), 1)
        self.assertAlmostEqual(plotting.known_bfc_rate(2), 1/5)

        with patch.object(plotting, 'csv_write'):
            rows = plotting.comparison_data()
        tradeoff = [row for row in rows
                    if row['panel'] == 'finite-tradeoff']
        comparison = [row for row in rows
                      if row['panel'] == 'rate-comparison']
        self.assertEqual({row['family'] for row in tradeoff},
                         set(plotting.FAMILIES))
        self.assertEqual({row['n_t'] for row in tradeoff},
                         {plotting.TRADEOFF_N_T})
        self.assertEqual(len(tradeoff),
                         len(plotting.FAMILIES) * len(plotting.TRADEOFF_E2))
        self.assertEqual(len(comparison), plotting.EXPONENT_POINTS)
        self.assertTrue(all(row['rs_rate'] <= row['known_bfc_rate']
                            for row in comparison))

    def test_two_information_theoretic_panels(self):
        with patch.object(plotting, 'csv_write'):
            rows = plotting.comparison_data()

        captured = {}
        with patch.object(
                plotting, 'savefig',
                side_effect=lambda fig, name: captured.update({name: fig})):
            plotting.figure_rate_reliability_comparison(rows)
        try:
            fig = captured[plotting.OUTPUT_NAME]
            self.assertEqual(tuple(fig.get_size_inches()), (3.5, 1.92))
            self.assertEqual(len(fig.axes), 2)
            self.assertIn(r'P_{\rm FP}', fig.axes[0].get_xlabel())
            self.assertIn('R_{\\rm exp}', fig.axes[0].get_ylabel())
            self.assertIn(rf'$n_t={plotting.TRADEOFF_N_T}$',
                          fig.axes[0].get_title())
            self.assertEqual(fig.axes[1].get_xlabel(), r'Weight exponent $a$')
            self.assertEqual(len(fig.axes[0].lines), len(plotting.FAMILIES))
        finally:
            for fig in captured.values():
                plt.close(fig)


if __name__ == '__main__':
    unittest.main()
