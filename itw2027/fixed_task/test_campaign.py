import json
import tempfile
import unittest
from pathlib import Path
import numpy as np
from scipy.io import savemat
import campaign


class CampaignTest(unittest.TestCase):
    def test_pilot_coverage_and_production_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)/'pilot'; campaign.manifests(out,'pilot')
            banks=json.loads((out/'banks.json').read_text())
            tasks=json.loads((out/'noisy.json').read_text())
            self.assertEqual(len(tasks),76)
            self.assertEqual(len(banks),3)
            for task in tasks:
                a=np.zeros((100,7)); a[:,:2]=270
                threshold=-4.3 if task['scheme']=='bfc' else 2.
                errors=100 if task['snr_db']<threshold else 0
                a[:errors,3:5]=1
                path=out/task['output']; path.parent.mkdir(parents=True,exist_ok=True)
                savemat(path,{'result':dict(task=task,complete=True,frames_done=100,per_frame=a)})
            records=campaign.collect(out)
            self.assertEqual(len(records),76)
            zero=next(r for r in records if r['fer']==0)
            self.assertAlmostEqual(zero['fer_hi95'],1-.05**.01)
            production=Path(directory)/'production'
            campaign.manifests(production,'production',out)
            tasks=json.loads((production/'noisy.json').read_text())
            design=json.loads((production/'design.json').read_text())
            self.assertEqual(design['grids']['bfc'],design['grids']['conventional'])
            self.assertTrue(all(t['frames']==250 and t['seed_group']==2 for t in tasks))
            campaign.summarize(out)
            self.assertTrue((out/'noisy.pdf').exists())
            # Missing shards must never be silently omitted.
            (out/'noisy.json').write_text(json.dumps(json.loads((out/'noisy.json').read_text()) +
                [dict(json.loads((out/'noisy.json').read_text())[0],output='missing.mat')]))
            with self.assertRaises(ValueError): campaign.collect(out)


if __name__=='__main__': unittest.main()
