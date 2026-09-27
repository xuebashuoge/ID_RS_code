"""Fresh noisy-only manifests; rate 3/5 fits the conventional 36000-bit payload."""
import argparse
import json
from pathlib import Path
from campaign import save_json


def generate(base,out):
    if out.exists():
        raise ValueError('Use a fresh destination; existing results must not be overwritten')
    design=json.loads((base/'design.json').read_text())
    grids=design['grids']
    # Preserve the existing SNR identifiers, which are part of the noise seed.
    old=json.loads((base/'noisy.json').read_text())
    indices={(t['family'],t['scheme'],t['snr_db']):t['snr_index'] for t in old}
    banks=[]; noisy=[]
    for family in ('id','rank','exact'):
        for shard in range(4):
            banks.append(dict(kind='bank',family=family,nt=60,G=360,frames=2500,
                first_frame=2500*shard+1,seed_group=3,runtime_limit=6600,
                output=f'banks_n_t_60/{family}_{shard:03d}_n_t_60.mat'))
        for scheme in (('bfc','conventional') if family=='exact' else ('bfc',)):
            for snr in grids[scheme]:
                for shard in range(4):
                    noisy.append(dict(kind='noisy',family=family,scheme=scheme,nt=60,G=360,
                        ldpc_rate=1/3 if scheme=='bfc' else 3/5,
                        snr_db=snr,snr_index=indices[(family,scheme,snr)],frames=2500,
                        first_frame=2500*shard+1,seed_group=3,runtime_limit=3000,
                        bank=f'banks_n_t_60/{family}_{shard:03d}_n_t_60.mat',
                        output=f'noisy_n_t_60/{family}_{scheme}_{snr:+06.2f}_{shard:03d}_n_t_60.mat'))
    save_json(out/'banks_n_t_60.json',banks)
    save_json(out/'noisy_n_t_60.json',noisy)
    save_json(out/'design_n_t_60.json',dict(nt=60,G=360,neff=180,Nb=64800,
        bfc_Ni=21600,bfc_Rc=1/3,conventional_Ni=38880,conventional_Rc=3/5,
        conventional_payload=36000,conventional_padding=2880,
        frames_per_point=10000,seed_group=3,grids=grids,snr_definition='Es/N0',
        source_design=str(base.resolve()),plots=False,noiseless_simulation=False))
    print(f'Generated {len(banks)} source-bank tasks and {len(noisy)} noisy tasks in {out}')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--base',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args(); generate(args.base,args.out)
