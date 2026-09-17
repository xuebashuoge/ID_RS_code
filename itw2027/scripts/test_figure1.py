import unittest
from unittest.mock import patch
import build_results as plotting
import matplotlib.pyplot as plt
from matplotlib.legend import Legend


class Figure1(unittest.TestCase):
    def test_combined_panel_uses_mean_and_keeps_legends_inside(self):
        rows=[]
        rates=[]
        for i,family in enumerate(plotting.FAMILIES):
            rows.append(dict(family=family,n_t=24,bound=.1,
                             sample_mean=.01*(i+1),sample_max=.02*(i+1),median=.009))
            for sequence in ('fixed_E','vanishing_E'):
                rates.append(dict(family=family,sequence=sequence,n_t=24,rate=.2+.1*i))
        captured={}
        with patch.object(plotting,'savefig',side_effect=lambda fig,name: captured.update({name:fig})):
            plotting.figure_noiseless(rows,[],rates)
        try:
            fig=captured['figure1_noiseless']
            self.assertEqual(len(fig.axes),2)
            self.assertEqual(len(fig.axes[0].lines),9)
            self.assertEqual(fig.axes[0].lines[2].get_ydata()[0],.01)
            for i in range(3):
                self.assertEqual(fig.axes[0].lines[3*i+1].get_marker(),'s')
                self.assertEqual(fig.axes[0].lines[3*i+1].get_markerfacecolor(),'none')
                self.assertEqual(fig.axes[0].lines[3*i+2].get_marker(),'o')
            legends=[obj for ax in fig.axes for obj in ax.get_children() if isinstance(obj,Legend)]
            labels=[t.get_text() for legend in legends for t in legend.get_texts()]
            for label in ('Mean','Max','Bound'):
                self.assertIn(label,labels)
            panel_a_labels=[t.get_text() for t in fig.axes[0].get_legend().get_texts()]
            self.assertEqual(panel_a_labels,['Mean','Max','Bound'])
            for i in range(3):
                self.assertEqual(fig.axes[1].lines[2*i].get_marker(),'o')
                self.assertEqual(fig.axes[1].lines[2*i+1].get_marker(),'s')
            panel_b_labels=[t.get_text() for t in fig.axes[1].get_legend().get_texts()]
            self.assertEqual(panel_b_labels,[r'$E=0.1$',r'$E=n_t^{-1/2}$','Benchmark'])
            self.assertNotIn('Median',labels)
            self.assertFalse(fig.legends)
        finally:
            for fig in captured.values(): plt.close(fig)


if __name__=='__main__': unittest.main()
