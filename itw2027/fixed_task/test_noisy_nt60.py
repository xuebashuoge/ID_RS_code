import json
import tempfile
import unittest
from pathlib import Path
from noisy_nt60 import generate


class Noisy60Test(unittest.TestCase):
    def test_fresh_banks_all_frames_and_stable_snr_indices(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory)/'base'; base.mkdir()
            grids={'bfc':[-4.5,2.], 'conventional':[-4.5,2.]}
            (base/'design.json').write_text(json.dumps(dict(grids=grids)))
            old=[dict(family=f,scheme=s,snr_db=x,snr_index=i+7)
                 for f in ('id','rank','exact')
                 for s in (('bfc','conventional') if f=='exact' else ('bfc',))
                 for i,x in enumerate(grids[s])]
            (base/'noisy.json').write_text(json.dumps(old))
            out=Path(directory)/'new_n_t_60'; generate(base,out)
            banks=json.loads((out/'banks_n_t_60.json').read_text())
            tasks=json.loads((out/'noisy_n_t_60.json').read_text())
            self.assertEqual(len(banks),12); self.assertEqual(len(tasks),32)
            self.assertFalse((out/'noiseless.json').exists())
            for task in tasks:
                self.assertEqual((task['nt'],task['G'],task['frames']),(60,360,2500))
                self.assertTrue(task['output'].endswith('_n_t_60.mat'))
                self.assertIn(task['bank'],[b['output'] for b in banks])
                self.assertEqual(task['snr_index'],7 if task['snr_db']==-4.5 else 8)
            self.assertEqual({t['first_frame'] for t in tasks},{1,2501,5001,7501})
            with self.assertRaises(ValueError): generate(base,out)


if __name__=='__main__': unittest.main()
