import json
import tempfile
import unittest
from pathlib import Path
import numpy as np
from scipy.io import savemat
from conventional_full import generate,bounds,summarize


class FullConventionalTest(unittest.TestCase):
    def test_grid_and_nonoverlapping_frame_ranges(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)/'run'; generate(out)
            design=json.loads((out/'design.json').read_text())
            tasks=json.loads((out/'tasks.json').read_text())
            self.assertEqual(len(tasks),2900); self.assertEqual(design['grid'][0],-5)
            self.assertEqual(design['concurrency'],64)
            self.assertFalse(design['pilot_included'])
            for snr in design['grid']:
                selected=[t for t in tasks if t['snr_db']==snr]
                self.assertEqual(sum(t['frames'] for t in selected),1000000)
                self.assertEqual([t['first_frame'] for t in selected],list(range(1,1000001,10000)))
            self.assertEqual(len({(t['snr_index'],t['first_frame']) for t in tasks}),len(tasks))

    def test_exact_confidence_threshold(self):
        self.assertLess(bounds(0,1000000,29)['fer_upper95_simultaneous'],1e-5)
        self.assertAlmostEqual(bounds(0,1000000,29)['fer_upper95'],1-.05**(1/1000000))
        self.assertLess(bounds(4,1000000,29)['fer_upper95'],1e-5)
        self.assertGreater(bounds(5,1000000,29)['fer_upper95'],1e-5)

    def test_strict_aggregation_and_fer_not_task_error(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)
            design=dict(grid=[-5.,-.8],frames_per_point=4,target_fer=.5)
            (out/'design.json').write_text(json.dumps(design))
            tasks=[]
            for snr in design['grid']:
                for start in (1,3):
                    t=dict(snr_db=snr,first_frame=start,frames=2,output=f'{snr}_{start}.mat')
                    tasks.append(t)
                    a=np.zeros((2,7),dtype=np.uint32); a[:,:2]=180
                    if snr==-5: a[:,4]=1; a[:,3]=1
                    r=dict(task=t,complete=True,frames_done=2,per_frame=a,
                           channel=dict(Rc=.6,Ni=38880),runtime_seconds=1.)
                    savemat(out/t['output'],{'result':r})
            (out/'tasks.json').write_text(json.dumps(tasks))
            report=summarize(out)
            self.assertEqual(report['first_empirical_below']['snr_db'],-.8)
            self.assertEqual(report['points'][0]['fer'],1.)
            self.assertAlmostEqual(report['points'][0]['balanced_error'],1/360)
            self.assertTrue((out/'summary.csv').exists())
            (out/'tasks.json').write_text(json.dumps(tasks+[tasks[0]]))
            with self.assertRaises(ValueError): summarize(out)


if __name__=='__main__': unittest.main()
