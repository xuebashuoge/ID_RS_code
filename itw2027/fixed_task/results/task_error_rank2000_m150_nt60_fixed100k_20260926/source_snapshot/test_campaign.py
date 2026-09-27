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
            for row in records:
                self.assertAlmostEqual(row['balanced_error'],.5*(row['fp']+row['fn']))
            production=Path(directory)/'production'
            campaign.manifests(production,'production',out)
            tasks=json.loads((production/'noisy.json').read_text())
            design=json.loads((production/'design.json').read_text())
            self.assertEqual(design['grids']['bfc'],design['grids']['conventional'])
            self.assertTrue(all(t['frames']==2500 and t['seed_group']==2 for t in tasks))
            tasks_n=json.loads((production/'noiseless.json').read_text())
            for family in campaign.FAMILIES:
                ranges=sorted((t['first_position'],t['positions']) for t in tasks_n
                              if t['family']==family and t['nt']==40 and t['first_message']==1)
                self.assertEqual(ranges,[(1,262144),(262145,524288),(524289,786432),(786433,1048576)])
            campaign.summarize(out)
            self.assertTrue((out/'noisy.pdf').exists())
            # Missing shards must never be silently omitted.
            (out/'noisy.json').write_text(json.dumps(json.loads((out/'noisy.json').read_text()) +
                [dict(json.loads((out/'noisy.json').read_text())[0],output='missing.mat')]))
            with self.assertRaises(ValueError): campaign.collect(out)

    def test_incremental_reuse_and_seed_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory)/'production'; base.mkdir()
            grids={s:[-4.4,-4.1] for s in ('bfc','conventional')}
            campaign.save_json(base/'design.json',dict(stage='production',grids=grids))
            tasks=[]
            for family in campaign.FAMILIES:
                for shard in range(4):
                    bank=base/f'banks/{family}_{shard:03d}.mat'
                    bank.parent.mkdir(exist_ok=True); bank.touch()
                for scheme in (('bfc','conventional') if family=='exact' else ('bfc',)):
                    for si,snr in enumerate(grids[scheme]):
                        for shard in range(4 if si==0 else 1):
                            t=dict(kind='noisy',family=family,scheme=scheme,snr_db=snr,snr_index=si+1,
                                   frames=2500,first_frame=shard*2500+1,seed_group=2,
                                   bank=f'banks/{family}_{shard:03d}.mat',runtime_limit=5400,
                                   output=f'noisy/{family}_{scheme}_{snr:+06.2f}_{shard:03d}.mat')
                            tasks.append(t); self.write_result(base,t)
            campaign.save_json(base/'noisy.json',tasks)
            campaign.save_json(base/'noiseless.json',[])
            out=Path(directory)/'extension'; campaign.extend(out,base)
            added=json.loads((out/'noisy.json').read_text())
            self.assertEqual(len(added),12)
            self.assertEqual({t['first_frame'] for t in added},{2501,5001,7501})
            self.assertTrue(all(t['snr_index']==2 and t['seed_group']==2 for t in added))
            self.assertTrue(all((out/t['bank']).exists() for t in added))
            with self.assertRaises(ValueError): campaign.collect(out)
            for task in added: self.write_result(out,task)
            records=campaign.collect(out)
            self.assertTrue(all(r['frames']==10000 and r['positive_trials']==2700000 for r in records))
            new_ns=json.loads((out/'noiseless.json').read_text()); self.assertEqual(len(new_ns),1344)
            for family in campaign.FAMILIES:
                probe=json.loads((out/f'probe_{family}.json').read_text())
                rest=json.loads((out/f'noiseless_{family}.json').read_text())
                self.assertEqual(len(probe),1); self.assertEqual(len(rest),447)
                self.assertEqual(probe[0]['nt'],46); self.assertNotIn(probe[0],rest)
                for nt in (42,44,46):
                    ranges=sorted((t['first_position'],t['positions']) for t in new_ns
                                  if t['family']==family and t['nt']==nt and t['first_message']==1)
                    cursor=1
                    for first,last in ranges:
                        self.assertEqual(first,cursor); cursor=last+1
                    self.assertEqual(cursor,2**(nt//2)+1)
            # Changing the old manifest must invalidate reuse, not silently resample.
            (base/'noisy.json').write_text((base/'noisy.json').read_text()+'\n')
            with self.assertRaises(ValueError): campaign.task_sources(out,'noisy')

    @staticmethod
    def write_result(root,task):
        a=np.zeros((task['frames'],7)); a[:,:2]=270
        a[0,2:5]=[1,2,1]
        path=root/task['output']; path.parent.mkdir(parents=True,exist_ok=True)
        savemat(path,{'result':dict(task=task,complete=True,frames_done=task['frames'],per_frame=a)})

    def test_noiseless_png_export(self):
        from figures import plot_noiseless
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)
            rows=[dict(family=f,nt=n,mean=.001,sample_max=.002,bound=.01)
                  for f in campaign.FAMILIES for n in (28,40,42,44,46)]
            plot_noiseless(rows,out)
            self.assertGreater((out/'noiseless.png').stat().st_size,1000)
            self.assertGreater((out/'noiseless.pdf').stat().st_size,1000)

    def test_combined_figure_export(self):
        from figures import plot_combined
        with tempfile.TemporaryDirectory() as directory:
            out=Path(directory)
            table=[dict(family=f,nt=n,mean=10**(-2-i),sample_max=2*10**(-2-i),
                        bound=10**(-i))
                   for f,i in zip(campaign.FAMILIES,(2,1,0)) for n in (28,34,40,46)]
            records=[]
            for f,i in zip(campaign.FAMILIES,(2,1,0)):
                for x,j in zip((-5.,-4.5,-4.),(0,1,2)):
                    records.append(dict(family=f,scheme='bfc',snr_db=x,frames=10000,
                                        balanced_error=10**(-j-1),
                                        noiseless_balanced_error=10**(-i-3)))
            for x,y in ((1.1,.5),(1.5,.2),(2.,1e-3),(2.5,0.)):
                records.append(dict(family='exact',scheme='conventional',snr_db=x,
                                    frames=10000,balanced_error=y,
                                    noiseless_balanced_error=1e-3))
            plot_combined(records,table,out)
            self.assertGreater((out/'combined_results.png').stat().st_size,1000)
            self.assertGreater((out/'combined_results.pdf').stat().st_size,1000)


if __name__=='__main__': unittest.main()
