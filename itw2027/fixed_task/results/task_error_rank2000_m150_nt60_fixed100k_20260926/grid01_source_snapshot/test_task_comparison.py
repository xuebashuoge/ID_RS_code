import json
import tempfile
import unittest
from pathlib import Path
import numpy as np
from scipy.io import savemat
from task_comparison import generate, summarize, _crossing, _upper95, coding_gains, plot, extend_low_snr, align_grid


class TaskComparisonTest(unittest.TestCase):
    def test_grid_alignment_preserves_checkpoints(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)/'run'; generate(out)
            tasks=json.loads((out/'tasks.json').read_text())
            original=[t for t in tasks if t['snr_db'] not in (2.2,-.8)]
            original.append(dict(original[0],snr_db=-4.45,output='excluded.mat'))
            (out/'tasks.json').write_text(json.dumps(original))
            before=(out/'tasks.json').read_bytes()
            align_grid(out)
            aligned=json.loads((out/'grid01_tasks.json').read_text())
            self.assertEqual((out/'tasks.json').read_bytes(),before)
            lookup={t['output']:t for t in original}
            for t in aligned:
                self.assertAlmostEqual(t['snr_db']*10,round(t['snr_db']*10))
                if t['output'] in lookup: self.assertEqual(t,lookup[t['output']])
            for family,scheme in { (t['family'],t['scheme']) for t in aligned }:
                snrs=sorted({t['snr_db'] for t in aligned if (t['family'],t['scheme'])==(family,scheme)})
                np.testing.assert_allclose(np.diff(snrs),.1)

    def test_low_snr_extension_preserves_running_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)/'run'; generate(out)
            tasks=json.loads((out/'tasks.json').read_text())
            old=[t for t in tasks if t['snr_db'] not in (-5.,-4.9)]
            (out/'tasks.json').write_text(json.dumps(old))
            original=(out/'tasks.json').read_bytes()
            extend_low_snr(out)
            self.assertEqual((out/'tasks.json').read_bytes(),original)
            merged=json.loads((out/'report_tasks.json').read_text())
            self.assertEqual(merged[:len(old)],old)
            new=merged[len(old):]
            self.assertEqual(len(new),80)
            self.assertGreater(min(t['snr_index'] for t in new),max(t['snr_index'] for t in old))
            for snr in (-5.,-4.9):
                group=[t for t in new if t['snr_db']==snr]
                self.assertEqual(sum(t['frames'] for t in group),100000)
                self.assertEqual([t['first_frame'] for t in group],list(range(1,100001,2500)))

    def test_budget_rate_and_independent_pilot(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)/'run'; generate(out)
            tasks=json.loads((out/'tasks.json').read_text())
            pilot=json.loads((out/'pilot.json').read_text())
            groups={}
            for t in tasks:
                key=(t['family'],t['scheme'],t['snr_db'])
                groups.setdefault(key,[]).append(t)
                payload=360*(60 if t['scheme']=='bfc' else t['m'])
                self.assertLessEqual(payload,round(64800*t['ldpc_rate']))
                if t['family']=='rank':
                    self.assertEqual((t['m'],t['rank_threshold']),(150,2000))
            for group in groups.values():
                cursor=1
                for t in sorted(group,key=lambda t:t['first_frame']):
                    self.assertEqual(t['first_frame'],cursor); cursor+=t['frames']
                self.assertEqual(cursor-1,group[0]['frames_per_point'])
            self.assertTrue(all(t['noise_seed']!=tasks[0]['noise_seed'] for t in pilot))
            self.assertEqual(max(t['frames_per_point'] for t in tasks),3000000)
            self.assertEqual({t['frames_per_point'] for t in tasks if t['scheme']=='bfc'}, {100000})

    def test_task_error_not_fer_and_reject_overlap(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)
            t=dict(family='rank',scheme='conventional',m=150,rank_threshold=2000,
                   ldpc_rate=5/6,G=360,nt=60,snr_db=2.1,frames=2,frames_per_point=2,
                   first_frame=1,output='one.mat')
            data=np.array([[180,180,0,1,1,1,0,50],[180,180,0,0,1,1,0,50]])
            r=dict(task=t,complete=True,frames_done=2,per_frame=data,runtime_seconds=1,
                   config=dict(m=150,nt=60,G=360,rank_threshold=2000,bound=8004/2**30),
                   channel=dict(Nb=64800,Rc=5/6))
            savemat(out/t['output'],dict(result=r))
            (out/'tasks.json').write_text(json.dumps([t]))
            row=summarize(out)[0]
            self.assertEqual(row['payload_FER'],1)
            self.assertEqual(row['balanced_error'],1/720)
            self.assertAlmostEqual(row['task_error_se'],1/720)
            self.assertEqual(row['task_error_frames'],1)
            (out/'tasks.json').write_text(json.dumps([t,t]))
            with self.assertRaisesRegex(ValueError,'overlapping'): summarize(out)

    def test_zero_limits_and_no_extrapolated_gain(self):
        self.assertLess(_upper95(np.zeros(3000000)),1e-6)
        rows=[dict(family='rank',scheme='bfc',snr_db=-4.5,balanced_error=1e-4),
              dict(family='rank',scheme='bfc',snr_db=-4.3,balanced_error=1e-5)]
        self.assertIsNone(_crossing(rows,1e-6))
        self.assertAlmostEqual(_crossing(rows,1e-5),-4.3)
        self.assertTrue(all(g['coding_gain_db'] is None for g in coding_gains(rows)))

    def test_standalone_has_both_comparisons(self):
        rows=[]
        for family in ('rank','exact'):
            for scheme in ('bfc','conventional'):
                for snr, pe in [(-4., .1), (-3., 1e-6)]:
                    rows.append(dict(family=family,scheme=scheme,snr_db=snr,
                                     balanced_error=pe))
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory); plot(rows,out)
            self.assertTrue((out/'task_error_comparison.pdf').exists())
            self.assertFalse((out/'combined_results_three_panels.pdf').exists())


if __name__=='__main__': unittest.main()
