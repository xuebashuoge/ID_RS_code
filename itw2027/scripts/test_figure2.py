import unittest
from unittest.mock import patch
import numpy as np
import build_results as plotting
import matplotlib.pyplot as plt

class Figure2(unittest.TestCase):
    def test_actual_panels_preserve_isolated_events_and_zeros(self):
        rows=[]
        for family in plotting.FAMILIES:
            for x,y in [(1.7,0),(1.8,1e-6),(1.9,0)]:
                rows.append(dict(family=family,experiment='waterfall',ebno_db=x,
                                 fnr=y,fer=y,fpr=y,noiseless_fpr=1e-6,
                                 diagnostic_fp_envelope=.01))
        captured={}
        with patch.object(plotting,'savefig',side_effect=lambda fig,name: captured.update({name:fig})):
            plotting.figure_noisy(rows)
        try:
            fig=captured['figure2_noisy']
            self.assertEqual(len(fig.axes),6)
            self.assertAlmostEqual(fig.get_size_inches()[0],3.5)
            for i in range(3):
                fn=fig.axes[2*i].lines[1]
                fp=fig.axes[2*i+1].lines[2]
                np.testing.assert_array_equal(fn.get_ydata(),[0,1e-6,0])
                np.testing.assert_array_equal(fp.get_ydata(),[0,1e-6,0])
                self.assertEqual(fn.get_marker(),'o')
                self.assertEqual(fp.get_linestyle(),'None')
            self.assertFalse(any(ax.collections for ax in fig.axes))
            labels=[t.get_text() for legend in fig.legends for t in legend.get_texts()]
            for label in ('FN','FER','FP','Noiseless','Diagnostic'):
                self.assertIn(label,labels)
        finally:
            for fig in captured.values(): plt.close(fig)

if __name__=='__main__': unittest.main()
