import unittest
from unittest.mock import patch

import matplotlib.pyplot as plt

import rate_results as plotting


class RateResults(unittest.TestCase):
    def test_two_rate_panels_and_common_endpoints(self):
        with patch.object(plotting, 'csv_write'):
            rows = plotting.rate_sequences()

        self.assertEqual(min(row['n_t'] for row in rows), 24)
        self.assertEqual(max(row['n_t'] for row in rows), 10_000)
        endpoint = [row for row in rows
                    if row['panel'] == 'vanishing' and row['n_t'] == 10_000]
        self.assertEqual(len(endpoint), len(plotting.FAMILIES))
        self.assertTrue(all(abs(row['E_2'] - 1e-2) < 1e-15 for row in endpoint))

        captured = {}
        with patch.object(
                plotting, 'savefig',
                side_effect=lambda fig, name: captured.update({name: fig})):
            plotting.figure_rate_results(rows)
        try:
            fig = captured['rate_results']
            self.assertEqual(len(fig.axes), 2)
            panel_a = [text.get_text() for text in fig.axes[0].get_legend().get_texts()]
            panel_b = [text.get_text() for text in fig.axes[1].get_legend().get_texts()]
            self.assertEqual(panel_a, [r'$E_2=10^{-1}$', r'$E_2=10^{-2}$'])
            self.assertEqual(panel_b, [r'$E_2=n_t^{-1/2}$', 'Asymptotic'])
            for axis in fig.axes:
                for line in axis.lines[:3]:
                    markevery = line.get_markevery()
                    if markevery is not None:
                        self.assertNotIn(0, markevery)
        finally:
            for fig in captured.values():
                plt.close(fig)


if __name__ == '__main__':
    unittest.main()
