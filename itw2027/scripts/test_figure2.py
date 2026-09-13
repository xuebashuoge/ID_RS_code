import unittest
import matplotlib.pyplot as plt
import numpy as np
from build_results import plot_error

class Figure2(unittest.TestCase):
    def test_isolated_events_and_zero_estimates_are_preserved(self):
        rows=[dict(ebno_db=x,fnr=y,fnr_lower95=0,fnr_upper95=2*y) for x,y in [(1.7,0),(1.8,1e-6),(1.9,0)]]
        fig,ax=plt.subplots()
        plot_error(ax,rows,'fnr','blue','-',None)
        line=ax.lines[0]
        np.testing.assert_array_equal(line.get_ydata(),[0,1e-6,0])
        self.assertEqual(line.get_marker(),'o')
        self.assertTrue(np.all(np.isfinite(line.get_ydata())))
        plt.close(fig)
if __name__=='__main__':unittest.main()
