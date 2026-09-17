import unittest
from unittest.mock import patch

import matplotlib.pyplot as plt
import numpy as np

import noisy_results_three_panel as plotting


class ThreePanelNoisyResults(unittest.TestCase):
    def test_probabilities_use_aggregate_counts(self):
        row = dict(
            frames=20,
            frame_errors=5,
            positive_trials=50,
            fn_count=10,
            negative_trials=200,
            fp_count=4,
            # Deliberately inconsistent cached rates ensure they are not used.
            fer=.99,
            fnr=.98,
            fpr=.97,
        )
        self.assertEqual(
            plotting.aggregate_error_probabilities(row),
            (.25, .2, .02),
        )

    def test_one_family_per_panel_and_three_metrics_per_panel(self):
        rows = []
        for family in plotting.FAMILIES:
            for ebno, scale in [(1.0, 1), (1.5, 2)]:
                rows.append(dict(
                    family=family,
                    experiment='waterfall',
                    ebno_db=ebno,
                    frames=100,
                    frame_errors=scale,
                    positive_trials=200,
                    fn_count=2*scale,
                    negative_trials=400,
                    fp_count=3*scale,
                    noiseless_fpr=.005*scale,
                    diagnostic_fp_envelope=.1*scale,
                ))
        captured = {}
        with patch.object(
                plotting, 'savefig',
                side_effect=lambda fig, name: captured.update({name: fig})):
            plotting.figure_noisy_three_panel(rows)
        try:
            fig = captured['figure2_noisy_three_panel']
            self.assertEqual(len(fig.axes), 3)
            for axis in fig.axes:
                self.assertEqual(len(axis.lines), 5)
                np.testing.assert_allclose(axis.lines[0].get_ydata(), [.01, .02])
                np.testing.assert_allclose(axis.lines[1].get_ydata(), [.01, .02])
                np.testing.assert_allclose(axis.lines[2].get_ydata(), [.0075, .015])
                np.testing.assert_allclose(axis.lines[3].get_ydata(), [.005, .01])
                np.testing.assert_allclose(axis.lines[4].get_ydata(), [.1, .2])
                self.assertEqual(axis.lines[0].get_marker(), 's')
                self.assertEqual(axis.lines[1].get_marker(), 'o')
                self.assertEqual(axis.lines[2].get_markerfacecolor(), 'white')
        finally:
            for fig in captured.values():
                plt.close(fig)


if __name__ == '__main__':
    unittest.main()
