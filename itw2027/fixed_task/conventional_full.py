"""Fixed one-million-frame conventional FER sweep and exact-binomial report."""
import argparse
import csv
import json
from pathlib import Path
import numpy as np
from scipy.io import loadmat
from scipy.stats import beta
from campaign import save_json


def generate(out):
    if out.exists(): raise ValueError('Use a fresh destination')
    grid=sorted(set([-5.,-4.,-3.,-2.,-1.5,-1.2,-1.1,0.]+
                    [round(i/100,2) for i in range(-100,-59,2)]))
    tasks=[]
    for si,snr in enumerate(grid,1):
        for shard in range(100):
            tasks.append(dict(kind='conventional_full',family='exact',scheme='conventional',
                ldpc_rate=3/5,nt=60,G=360,frames_per_point=1000000,
                source_seed=20260922,noise_seed=20260923,snr_db=snr,snr_index=si,
                frames=10000,first_frame=shard*10000+1,runtime_limit=3000,
                output=f'noisy_conventional_rc_3_5_n_t_60/exact_{snr:+06.2f}_{shard:03d}_million_rc_3_5_n_t_60.mat'))
    save_json(out/'tasks.json',tasks)
    save_json(out/'design.json',dict(stage='conventional_million',grid=grid,
        frames_per_point=1000000,shard_frames=10000,target_fer=1e-5,
        nt=60,G=360,m=100,neff=180,Nb=64800,Ni=38880,ldpc_rate=3/5,
        payload_bits=36000,padding_bits=2880,source_seed=20260922,noise_seed=20260923,
        snr_definition='Es/N0',pilot_included=False,source_banks_reused=False,
        concurrency=64,plots=False))
    print(f'{len(grid)} SNRs, {len(tasks)} jobs, {len(grid)*1000000:,} fresh frames; range {grid[0]} to {grid[-1]} dB')


def bounds(k,n,points):
    lower=0. if k==0 else float(beta.ppf(.025,k,n-k+1))
    upper=1. if k==n else float(beta.ppf(.975,k+1,n-k))
    one=1. if k==n else float(beta.ppf(.95,k+1,n-k))
    simultaneous=1. if k==n else float(beta.ppf(1-.05/points,k+1,n-k))
    return dict(fer_lo95=lower,fer_hi95=upper,fer_upper95=one,fer_upper95_simultaneous=simultaneous)


def summarize(out):
    design=json.loads((out/'design.json').read_text())
    tasks=json.loads((out/'tasks.json').read_text()); groups={}
    for t in tasks:
        path=out/t['output']
        if not path.exists(): raise ValueError(f'Missing shard: {path}')
        r=loadmat(path,simplify_cells=True)['result']
        if not r['complete'] or r['frames_done']!=t['frames']:
            raise ValueError(f'Incomplete shard: {path}')
        if r['task']!=t: raise ValueError(f'Task metadata mismatch: {path}')
        if r['channel']['Rc']!=.6 or r['channel']['Ni']!=38880:
            raise ValueError(f'Wrong channel code: {path}')
        a=np.atleast_2d(r['per_frame'])
        if a.shape!=(t['frames'],7) or not np.all(np.isfinite(a)):
            raise ValueError(f'Invalid frame records: {path}')
        if not np.all(a[:,:2]==180) or np.any(a[:,2:4]>180) or not np.all(np.isin(a[:,4],[0,1])):
            raise ValueError(f'Invalid error counts: {path}')
        if np.any((a[:,2]+a[:,3]>0)&(a[:,4]==0)):
            raise ValueError(f'Task error without a frame error: {path}')
        group=groups.setdefault(t['snr_db'],dict(counts=np.zeros(7,dtype=np.uint64),ranges=[],runtime=0.))
        group['counts']+=a.astype(np.uint64).sum(axis=0)
        group['ranges'].append((t['first_frame'],t['first_frame']+t['frames']-1))
        group['runtime']+=r['runtime_seconds']
    if set(groups)!=set(design['grid']): raise ValueError('Missing or extra SNR points')
    rows=[]
    for snr,g in sorted(groups.items()):
        cursor=1
        for first,last in sorted(g['ranges']):
            if first!=cursor: raise ValueError('Missing or overlapping frame ranges')
            cursor=last+1
        n=cursor-1
        if n!=design['frames_per_point']: raise ValueError('Incomplete planned sample')
        c=g['counts']; k=int(c[4])
        row=dict(snr_db=snr,frames=n,frame_errors=k,fer=k/n,
                 negative_trials=int(c[0]),positive_trials=int(c[1]),
                 fp_count=int(c[2]),fn_count=int(c[3]),FP=float(c[2]/c[0]),FN=float(c[3]/c[1]),
                 balanced_error=float((c[2]+c[3])/(c[0]+c[1])),mean_iterations=float(c[6]/n),
                 runtime_job_hours=g['runtime']/3600,**bounds(k,n,len(groups)))
        rows.append(row)
    target=design['target_fer']
    def first(column):
        return next((r for r in rows if r[column]<target),None)
    report=dict(complete=True,target_fer=target,metric='LDPC FER, not balanced task error',
        first_empirical_below=first('fer'),first_pointwise95_below=first('fer_upper95'),
        first_simultaneous95_below=first('fer_upper95_simultaneous'),
        confidence_method='Exact binomial, one-sided 95%; simultaneous bounds use Bonferroni across the fixed SNR grid',
        grid_resolution_db=.02,points=rows)
    with (out/'summary.csv').open('w',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=rows[0].keys(),lineterminator='\n')
        writer.writeheader(); writer.writerows(rows)
    save_json(out/'fer_threshold_report.json',report)
    lines=['# Conventional rate-3/5 FER threshold','',
           f'Each point contains {design["frames_per_point"]:,} fresh independent frames. The first SNR is -5 dB.',
           'Metric: any error in the decoded 38880-bit LDPC information block, including padding.','']
    for label,key in [('Empirical FER < 1e-5','first_empirical_below'),
                      ('Pointwise one-sided 95% upper bound < 1e-5','first_pointwise95_below'),
                      ('Simultaneous one-sided 95% upper bound < 1e-5','first_simultaneous95_below')]:
        r=report[key]
        lines.append(f'- {label}: '+(f'{r["snr_db"]:.2f} dB ({r["frame_errors"]}/{r["frames"]}; FER {r["fer"]:.7g}).' if r else 'not established on this grid.'))
    lines.extend(['','These are the smallest qualifying tested SNRs, not exact continuous thresholds.',
                  'Zero events are reported as observations with nonzero confidence upper bounds.','',
                  '| SNR (dB) | Frame errors | Frames | FER | One-sided 95% upper | Simultaneous upper |',
                  '|---:|---:|---:|---:|---:|---:|'])
    lines.extend(f'| {r["snr_db"]:.2f} | {r["frame_errors"]} | {r["frames"]} | {r["fer"]:.7g} | {r["fer_upper95"]:.7g} | {r["fer_upper95_simultaneous"]:.7g} |' for r in rows)
    (out/'fer_threshold_report.md').write_text('\n'.join(lines)+'\n')
    print('\n'.join(lines[:9]))
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('action',choices=['generate','summarize'])
    parser.add_argument('--out',type=Path,required=True); args=parser.parse_args()
    if args.action=='generate': generate(args.out)
    else: summarize(args.out)
