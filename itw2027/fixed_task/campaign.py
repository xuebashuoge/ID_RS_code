#!/usr/bin/env python3
"""Manifest generation, strict aggregation, and plots. Run in conda torch28."""
import argparse
import csv
import json
import hashlib
import os
from pathlib import Path
import numpy as np
from scipy.io import loadmat

FAMILIES = ('id', 'rank', 'exact')


def task_sources(out, name):
    """Read-only reuse of original manifests without rewriting task metadata."""
    reuse_path=out/'reuse.json'
    sources=[]
    if reuse_path.exists():
        reuse=json.loads(reuse_path.read_text())
        base=(out/reuse['base']).resolve()
        source=base/f'{name}.json'
        if hashlib.sha256(source.read_bytes()).hexdigest()!=reuse['sha256'][name]:
            raise ValueError(f'Reused manifest changed: {source}')
        sources.extend((base,t) for t in json.loads(source.read_text()))
    sources.extend((out,t) for t in json.loads((out/f'{name}.json').read_text()))
    return sources


def extend(out, base):
    """Only missing channel shards and nt=42,44,46; original seeds unchanged."""
    out=out.resolve(); base=base.resolve()
    if out==base or (out/'design.json').exists():
        raise ValueError('Extension requires a fresh output directory')
    old_design=json.loads((base/'design.json').read_text())
    if old_design['stage']!='production' or (base/'reuse.json').exists():
        raise ValueError('Expected the original production campaign')
    records=collect(base)  # Validate every existing noisy result before reuse.
    for task in json.loads((base/'noiseless.json').read_text()):
        read_result(base,task)
    original=json.loads((base/'noisy.json').read_text())
    groups={}
    for task in original:
        groups.setdefault((task['family'],task['scheme'],task['snr_db']),[]).append(task)
    noisy=[]
    for key,tasks in sorted(groups.items()):
        template=min(tasks,key=lambda t:t['first_frame'])
        if template['frames']!=2500 or template['seed_group']!=2:
            raise ValueError('Unexpected source sampling design')
        existing={t['first_frame'] for t in tasks}
        if existing not in ({1},{1,2501,5001,7501}):
            raise ValueError(f'Unexpected existing frame coverage: {key}')
        for first in (1,2501,5001,7501):
            if first in existing: continue
            shard=(first-1)//2500
            bank=base/f"banks/{template['family']}_{shard:03d}.mat"
            if not bank.exists(): raise ValueError(f'Missing reusable bank: {bank}')
            task=dict(template,first_frame=first,runtime_limit=3000,
                      bank=os.path.relpath(bank,out),
                      output=f"noisy/{template['family']}_{template['scheme']}_{template['snr_db']:+06.2f}_{shard:03d}.mat")
            noisy.append(task)
    noiseless=[]
    limits={'id':6600,'rank':3000,'exact':1500}
    for family in FAMILIES:
        messages=25 if family=='id' else 250
        for nt in (42,44,46):
            for shard in range(8):
                for start in range(1,2**(nt//2)+1,262144):
                    noiseless.append(dict(kind='noiseless',family=family,nt=nt,
                        messages=messages,first_message=shard*messages+1,seed_group=2,
                        first_position=start,positions=min(start+262143,2**(nt//2)),
                        chunk_size=64,runtime_limit=limits[family],
                        output=f'noiseless/{family}_{nt}_{shard:03d}_{start:07d}.mat'))
    save_json(out/'noisy.json',noisy)
    save_json(out/'noiseless.json',noiseless)
    for family in FAMILIES:
        tasks=[t for t in noiseless if t['family']==family]
        probe=next(t for t in tasks if t['nt']==46)
        save_json(out/f'probe_{family}.json',[probe])
        save_json(out/f'noiseless_{family}.json',[t for t in tasks if t!=probe])
    save_json(out/'reuse.json',dict(base=os.path.relpath(base,out),sha256={
        name:hashlib.sha256((base/f'{name}.json').read_bytes()).hexdigest()
        for name in ('noisy','noiseless')}))
    save_json(out/'design.json',dict(stage='extension',target_frames=10000,
        grids=old_design['grids'],noiseless_nt=list(range(28,47,2)),
        snr_definition='Es/N0',shard_frames=2500,
        reused_channel_frames=sum(r['frames'] for r in records),
        new_channel_frames=sum(t['frames'] for t in noisy)))
    print(f'{out}: {len(noisy)} new channel jobs, {len(noiseless)} new noiseless jobs; banks reused')


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
    groups = {}
    for source,task in task_sources(out,'noisy'):
        result = read_result(source, task)
        data = np.atleast_2d(result['per_frame'])
        if len(data) != task['frames'] or result['frames_done'] != task['frames']:
            raise ValueError('Frame count mismatch')
        key = (task['family'], task['scheme'], task['snr_db'])
        group = groups.setdefault(key, {'data': [], 'frames': set()})
        ids = set(range(task['first_frame'], task['first_frame'] + task['frames']))
        if ids & group['frames']:
            raise ValueError('Overlapping frame shards')
        group['frames'].update(ids); group['data'].append(data)
    design=json.loads((out/'design.json').read_text())
    if design.get('target_frames'):
        expected={(f,s,x) for f in FAMILIES for s in (('bfc','conventional') if f=='exact' else ('bfc',))
                  for x in design['grids'][s]}
        if set(groups)!=expected: raise ValueError('Missing or extra SNR/task combinations')
        for group in groups.values():
            if group['frames']!=set(range(1,design['target_frames']+1)):
                raise ValueError('Incomplete target frame coverage')
    records = []
    rng = np.random.default_rng(1739)
    for (family, scheme, snr), group in sorted(groups.items()):
        a = np.concatenate(group['data']); totals = a.sum(axis=0)
        if not np.all(a[:,0]==a[:,1]): raise ValueError('Balanced-error plot requires balanced classes')
        record = dict(family=family, scheme=scheme, snr_db=snr, frames=len(a),
                      negative_trials=int(totals[0]), positive_trials=int(totals[1]),
                      fp=totals[2]/totals[0], fn=totals[3]/totals[1], fer=totals[4]/len(a),
                      noiseless_fp=totals[5]/totals[0], mean_iterations=totals[6]/len(a),
                      balanced_error=(totals[2]+totals[3])/(totals[0]+totals[1]),
                      noiseless_balanced_error=.5*totals[5]/totals[0])
        for metric, values, denom in [('fp', a[:,2], a[:,0]), ('fn', a[:,3], a[:,1]),
                ('fer', a[:,4], np.ones(len(a))), ('balanced_error',a[:,2]+a[:,3],a[:,0]+a[:,1])]:
            lo, hi = interval(values, denom, rng)
            record[metric+'_lo95'], record[metric+'_hi95'] = lo, hi
            record[metric+'_events'] = int(values.sum())
        records.append(record)
    return records


def summarize(out):
    records = collect(out)
    with (out / 'summary.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=records[0].keys(), lineterminator='\n')
        writer.writeheader(); writer.writerows(records)
    from figures import plot_noisy, plot_noiseless
    plot_noisy(records,out)
    design=json.loads((out/'design.json').read_text())
    if design['stage'] in ('production','extension'):
        groups={}
        for source,task in task_sources(out,'noiseless'):
            result=read_result(source,task)
            key=(task['family'],task['nt'])
            expected=200 if task['family']=='id' else 2000
            g=groups.setdefault(key,{'hits':np.zeros(expected),'ranges':[[] for _ in range(expected)],'bound':result['config']['bound']})
            first=task.get('first_position',1); last=task['positions']
            if result['next_position']!=last+1: raise ValueError('Incomplete position range')
            for offset,hits in enumerate(np.atleast_1d(result['hits'])):
                index=task['first_message']-1+offset
                g['hits'][index]+=hits; g['ranges'][index].append((first,last))
        table=[]
        for family in FAMILIES:
            for nt in design.get('noiseless_nt',list(range(28,41,2))):
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
        plot_noiseless(table,out)
        with (out/'noiseless_summary.csv').open('w',newline='') as f:
            writer=csv.DictWriter(f,fieldnames=table[0].keys(),lineterminator='\n'); writer.writeheader(); writer.writerows(table)
    print(f'Validated {len(records)} channel points; wrote summary.csv and plots to {out}')


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('action',choices=['pilot','production','extension','summarize','replot'])
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--pilot',type=Path)
    parser.add_argument('--base',type=Path)
    args=parser.parse_args()
    if args.action=='summarize': summarize(args.out)
    elif args.action=='replot':
        if args.base is None: parser.error('replot requires --base')
        from figures import replot_from_tables
        replot_from_tables(args.base,args.out)
    elif args.action=='extension':
        if args.base is None: parser.error('extension requires --base')
        extend(args.out,args.base)
    else: manifests(args.out,args.action,args.pilot)
