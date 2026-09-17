#!/usr/bin/env python3
"""Manifest generation, strict aggregation, and plots. Run in conda torch28."""
import argparse
import csv
import json
from pathlib import Path
import numpy as np
from scipy.io import loadmat

FAMILIES = ('id', 'rank', 'exact')


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def manifests(out, stage, pilot=None):
    group = 1 if stage == 'pilot' else 2
    if stage == 'pilot':
        grids = {s: np.round(np.arange(-5.5, 3.51, .5), 2).tolist()
                 for s in ('bfc', 'conventional')}
        budgets = {s: {str(x): 100 for x in grid} for s, grid in grids.items()}
        shard_size = 100
    else:
        if pilot is None:
            raise ValueError('Production requires --pilot pointing to completed pilot results')
        records = collect(pilot)
        grids, budgets = {}, {}
        for scheme in ('bfc', 'conventional'):
            selected = [r for r in records if r['scheme'] == scheme and r['family'] == 'exact']
            selected.sort(key=lambda r: r['snr_db'])
            high_error = [r['snr_db'] for r in selected if r['fer'] >= .5]
            low_error = [r['snr_db'] for r in selected if r['fer'] <= .02]
            if not high_error or not low_error or max(high_error) >= min(low_error):
                raise ValueError(f'{scheme}: pilot does not bracket one clear waterfall; extend/review pilot')
            low, high = max(high_error), min(low_error)
            last_nonzero = max(r['snr_db'] for r in selected if r['fer'] > .02)
            tail_points = {round(last_nonzero + offset, 2) for offset in (.1, .2, .3)}
            grid = sorted(set(np.round(np.arange(low-.4, high+.41, .1), 2).tolist()
                              + [-5.5, -3., 0., 3.5]))
            grids[scheme] = grid
            budgets[scheme] = {str(x): (10000 if x in tail_points else 2500) for x in grid}
        # Both schemes use the same x samples in the comparison panel.
        combined = sorted(set(grids['bfc'] + grids['conventional']))
        for scheme in grids:
            for x in combined:
                budgets[scheme].setdefault(str(x), 2500)
            grids[scheme] = combined
        shard_size = 2500
    banks, noisy, noiseless = [], [], []
    max_frames = max(max(v.values()) for v in budgets.values())
    for family in FAMILIES:
        for shard in range(max_frames // shard_size):
            bank_name = f'banks/{family}_{shard:03d}.mat'
            banks.append(dict(kind='bank', family=family, frames=shard_size,
                              first_frame=shard*shard_size+1, seed_group=group,
                              output=bank_name, runtime_limit=5400))
        schemes = ('bfc', 'conventional') if family == 'exact' else ('bfc',)
        for scheme in schemes:
            for si, snr in enumerate(grids[scheme]):
                for shard in range(budgets[scheme][str(snr)] // shard_size):
                    noisy.append(dict(kind='noisy', family=family, scheme=scheme,
                                      snr_db=snr, snr_index=si+1, frames=shard_size,
                                      first_frame=shard*shard_size+1, seed_group=group,
                                      bank=f'banks/{family}_{shard:03d}.mat',
                                      output=f'noisy/{family}_{scheme}_{snr:+06.2f}_{shard:03d}.mat',
                                      runtime_limit=5400))
        nts = [40] if stage == 'pilot' else list(range(28, 41, 2))
        count = 2 if stage == 'pilot' else (200 if family == 'id' else 2000)
        chunk_messages = 2 if stage == 'pilot' else (25 if family == 'id' else 250)
        for nt in nts:
            for shard in range(count // chunk_messages):
                total_positions=512 if stage=='pilot' else 2**(nt//2)
                for start in range(1,total_positions+1,262144):
                    noiseless.append(dict(kind='noiseless', family=family, nt=nt,
                                      messages=chunk_messages, first_message=shard*chunk_messages+1,
                                      seed_group=group, first_position=start,
                                      positions=min(start+262143,total_positions),
                                      chunk_size=64, runtime_limit=2700 if stage == 'pilot' else 18000,
                                      output=f'noiseless/{family}_{nt}_{shard:03d}_{start:07d}.mat'))
    for name, tasks in [('banks', banks), ('noisy', noisy), ('noiseless', noiseless)]:
        save_json(out / f'{name}.json', tasks)
    save_json(out / 'design.json', dict(stage=stage, grids=grids, frames_per_point=budgets,
                                       snr_definition='Es/N0', shard_frames=shard_size))
    print(f'{out}: {len(banks)} bank, {len(noisy)} channel, {len(noiseless)} noiseless tasks')


def read_result(out, task):
    path = out / task['output']
    if not path.exists():
        raise ValueError(f'Missing result: {path}')
    result = loadmat(path, simplify_cells=True)['result']
    if not result['complete']:
        raise ValueError(f'Incomplete result: {path}')
    for key, value in task.items():
        if result['task'][key] != value:
            raise ValueError(f'Metadata mismatch: {path}: {key}')
    return result


def interval(values, denominator, rng):
    # Independent sampling unit is the whole LDPC frame.
    frames = len(values)
    if np.sum(values) == 0:
        return 0., 1 - .05**(1/frames)
    draws = np.empty(2000)
    for j in range(len(draws)):
        indices = rng.integers(0, frames, frames)
        draws[j] = values[indices].sum() / denominator[indices].sum()
    return tuple(np.quantile(draws, [.025, .975]))


def collect(out):
    tasks = json.loads((out / 'noisy.json').read_text())
    groups = {}
    for task in tasks:
        result = read_result(out, task)
        data = np.atleast_2d(result['per_frame'])
        if len(data) != task['frames'] or result['frames_done'] != task['frames']:
            raise ValueError('Frame count mismatch')
        key = (task['family'], task['scheme'], task['snr_db'])
        group = groups.setdefault(key, {'data': [], 'frames': set()})
        ids = set(range(task['first_frame'], task['first_frame'] + task['frames']))
        if ids & group['frames']:
            raise ValueError('Overlapping frame shards')
        group['frames'].update(ids); group['data'].append(data)
    records = []
    rng = np.random.default_rng(1739)
    for (family, scheme, snr), group in sorted(groups.items()):
        a = np.concatenate(group['data']); totals = a.sum(axis=0)
        record = dict(family=family, scheme=scheme, snr_db=snr, frames=len(a),
                      negative_trials=int(totals[0]), positive_trials=int(totals[1]),
                      fp=totals[2]/totals[0], fn=totals[3]/totals[1], fer=totals[4]/len(a),
                      noiseless_fp=totals[5]/totals[0], mean_iterations=totals[6]/len(a))
        for metric, col, denom in [('fp', 2, a[:, 0]), ('fn', 3, a[:, 1]), ('fer', 4, np.ones(len(a)))]:
            lo, hi = interval(a[:, col], denom, rng)
            record[metric+'_lo95'], record[metric+'_hi95'] = lo, hi
            record[metric+'_events'] = int(totals[col])
        records.append(record)
    return records


def summarize(out):
    records = collect(out)
    with (out / 'summary.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=records[0].keys(), lineterminator='\n')
        writer.writeheader(); writer.writerows(records)
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(1, 3, figsize=(10, 3.1), layout='constrained')
    for ax, family in zip(axes, FAMILIES):
        for scheme in ('bfc', 'conventional'):
            rows = sorted([r for r in records if r['family']==family and r['scheme']==scheme],
                          key=lambda r:r['snr_db'])
            if not rows: continue
            for metric, marker in [('fn','o'),('fp','s')]:
                x=np.array([r['snr_db'] for r in rows]); y=np.array([r[metric] for r in rows])
                line,=ax.plot(x,np.where(y>0,y,np.nan),marker=marker,markersize=3,
                              linestyle='-' if scheme=='bfc' else '--',label=f'{scheme} {metric.upper()}')
                for r in rows:
                    if r[metric]==0:
                        ax.scatter(r['snr_db'],r[metric+'_hi95'],marker='v',s=18,color=line.get_color())
            if scheme=='bfc':
                # Each point uses its actual source sample; do not pool repeated banks across SNR.
                ax.plot([r['snr_db'] for r in rows],[r['noiseless_fp'] or np.nan for r in rows],
                        ':',color='gray',label='paired noiseless FP')
        ax.set(yscale='log',xlabel='SNR $E_s/N_0$ (dB)',title=family,ylim=(1e-7,1.1))
        ax.grid(True,alpha=.2); ax.legend(fontsize=6)
    axes[0].set_ylabel('Conditional task error probability')
    fig.savefig(out/'noisy.pdf'); fig.savefig(out/'noisy.png',dpi=200); plt.close(fig)
    design=json.loads((out/'design.json').read_text())
    if design['stage']=='production':
        groups={}
        for task in json.loads((out/'noiseless.json').read_text()):
            result=read_result(out,task)
            key=(task['family'],task['nt'])
            expected=200 if task['family']=='id' else 2000
            g=groups.setdefault(key,{'hits':np.zeros(expected),'ranges':[[] for _ in range(expected)],'bound':result['config']['bound']})
            first=task.get('first_position',1); last=task['positions']
            if result['next_position']!=last+1: raise ValueError('Incomplete position range')
            for offset,hits in enumerate(np.atleast_1d(result['hits'])):
                index=task['first_message']-1+offset
                g['hits'][index]+=hits; g['ranges'][index].append((first,last))
        fig,axes=plt.subplots(1,3,figsize=(10,3.1),layout='constrained')
        table=[]
        for ax,family in zip(axes,FAMILIES):
            for nt in range(28,41,2):
                g=groups[(family,nt)]; T=2**(nt//2)
                for ranges in g['ranges']:
                    next_position=1
                    for first,last in sorted(ranges):
                        if first!=next_position: raise ValueError('Missing or overlapping position ranges')
                        next_position=last+1
                    if next_position!=T+1: raise ValueError('Partial enumeration is not paper evidence')
                v=g['hits']/T
                table.append(dict(family=family,nt=nt,mean=v.mean(),sample_max=v.max(),bound=g['bound'],messages=len(v),
                                  fn=0,fp_count=int(g['hits'].sum()),negative_trials=len(v)*T))
            rows=[r for r in table if r['family']==family]
            for metric in ('mean','sample_max','bound'):
                ax.plot([r['nt'] for r in rows],[r[metric] for r in rows],'o-',label=metric)
            ax.set(yscale='log',xlabel='$n_t$',title=family); ax.grid(True,alpha=.2); ax.legend(fontsize=7)
        axes[0].set_ylabel('Noiseless FP probability')
        fig.savefig(out/'noiseless.pdf'); plt.close(fig)
        with (out/'noiseless_summary.csv').open('w',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=table[0].keys(),lineterminator='\n'); writer.writeheader(); writer.writerows(table)
    print(f'Validated {len(records)} channel points; wrote summary.csv and plots to {out}')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['pilot','production','summarize'])
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--pilot',type=Path)
    args=parser.parse_args()
    if args.action=='summarize': summarize(args.out)
    else: manifests(args.out,args.action,args.pilot)
