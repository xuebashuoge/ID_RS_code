import unittest
from unittest.mock import patch
import numpy as np
import build_results as plotting
import matplotlib.pyplot as plt
from matplotlib.legend import Legend

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
            self.assertEqual(len(fig.axes),4)
            self.assertAlmostEqual(fig.get_size_inches()[0],3.5)
            for i in range(3):
                fer=fig.axes[i].lines[0]
                fn=fig.axes[i].lines[1]
                fp=fig.axes[3].lines[3*i+2]
                np.testing.assert_array_equal(fn.get_ydata(),[0,1e-6,0])
                np.testing.assert_array_equal(fp.get_ydata(),[0,1e-6,0])
                self.assertEqual(fn.get_marker(),'o')
                self.assertEqual(fer.get_marker(),'s')
                self.assertEqual(fer.get_linestyle(),'None')
                self.assertEqual(fp.get_marker(),'o')
                self.assertEqual(fp.get_linestyle(),'None')
            self.assertFalse(any(ax.collections for ax in fig.axes))
            legends=[obj for ax in fig.axes for obj in ax.get_children() if isinstance(obj,Legend)]
            labels=[t.get_text() for legend in legends for t in legend.get_texts()]
            for label in ('FN','FER','FP','Noiseless','Bound'):
                self.assertIn(label,labels)
            self.assertNotIn('Diagnostic',labels)
            self.assertFalse(fig.legends)
        finally:
            for fig in captured.values(): plt.close(fig)

if __name__=='__main__': unittest.main()
