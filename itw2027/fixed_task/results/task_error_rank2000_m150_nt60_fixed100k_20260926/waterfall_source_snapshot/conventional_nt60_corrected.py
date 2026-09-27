"""Only rerun the conventional nt=60 baseline with rate 3/5; reuse source banks."""
import argparse
import json
import os
from pathlib import Path
from scipy.io import loadmat
from campaign import save_json


def generate(base,out):
    base=base.resolve(); out=out.resolve()
    if out.exists(): raise ValueError('Use a new output directory')
    prior=json.loads((base/'noisy_n_t_60.json').read_text())
    for supplement in sorted(base.glob('noisy_snr*_n_t_60.json')):
        prior.extend(json.loads(supplement.read_text()))
    ids={}
    for t in prior:
        if t['snr_db'] in ids and ids[t['snr_db']]!=t['snr_index']:
            raise ValueError('Inconsistent existing SNR identifiers')
        ids[t['snr_db']]=t['snr_index']
    original_grid=sorted({t['snr_db'] for t in prior if t['scheme']=='conventional'})
    grid=sorted(set(original_grid+[round(i/10,1) for i in range(-20,1)]))
    next_id=max(ids.values())+1
    for snr in grid:
        if snr not in ids: ids[snr]=next_id; next_id+=1
    banks=[]
    for shard in range(4):
        path=base/f'banks_n_t_60/exact_{shard:03d}_n_t_60.mat'
        r=loadmat(path,simplify_cells=True)['result']
        assert r['complete'] and r['frames_done']==2500
        assert r['config']['nt']==60 and r['config']['G']==360 and r['config']['m']==100
        assert r['task']['seed_group']==3 and r['task']['first_frame']==shard*2500+1
        banks.append(os.path.relpath(path,out))
    tasks=[]
    for snr in grid:
        for shard in range(4):
            tasks.append(dict(kind='noisy',family='exact',scheme='conventional',nt=60,G=360,
                ldpc_rate=3/5,snr_db=snr,snr_index=ids[snr],frames=2500,
                first_frame=shard*2500+1,seed_group=3,runtime_limit=3000,bank=banks[shard],
                output=f'noisy_conventional_rc_3_5_n_t_60/exact_conventional_{snr:+06.2f}_{shard:03d}_rc_3_5_n_t_60.mat'))
    save_json(out/'noisy_conventional_rc_3_5_n_t_60.json',tasks)
    save_json(out/'pilot.json',[t for t in tasks if t['first_frame']==1 and
                               t['snr_db'] in (-1.4,-1.2,-1.,-.8,-.6)])
    save_json(out/'design.json',dict(nt=60,G=360,m=100,Nb=64800,Ni=38880,Rc=3/5,
        message_payload_bits=36000,payload_rate=36000/64800,padding_bits=2880,neff=180,
        frames_per_point=10000,grid=grid,source_banks=str(base),seed_group=3,
        replaces='Conventional nt=60 results at LDPC rate 5/6; BFC results unchanged',
        snr_definition='Es/N0',plots=False))
    print(f'{len(grid)} SNR points, {len(tasks)} conventional-only jobs; 4 banks validated and reused')


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--base',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args(); generate(args.base,args.out)
