#!/usr/bin/env python3
"""Generate, validate, summarize, and plot the nt=60 task-error campaign."""
import argparse
import csv
import json
import math
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat
from scipy.stats import beta

from campaign import save_json


SHARD_FRAMES = 10_000
BFC_SHARD_FRAMES = 2_500
TARGETS = (1e-5, 1e-6)

# Fixed before the confirmatory sample: cheap points locate each waterfall;
# one-million-frame points resolve the task-error tails.
PLANS = {
    ('rank', 'bfc'): {
        snr: 100_000 for snr in
        (-5.00, -4.90, -4.80, -4.70, -4.60, -4.50, -4.40, -4.30, -4.20)
    },
    ('rank', 'conventional'): {
        **{i/10: 1_000 for i in range(-50,18)},
        1.80: 10_000, 1.90: 10_000, 2.00: 50_000,
        2.10: 1_000_000, 2.20: 3_000_000,
    },
    ('exact', 'conventional'): {
        **{i/10: 1_000 for i in range(-50,-12)},
        -1.20: 10_000, -1.10: 10_000, -1.00: 10_000,
        -0.90: 250_000, -0.80: 3_000_000,
    },
}

# Refinement requested after the first complete 0.1 dB sweep. These are final
# total frame budgets, including reusable samples from that sweep.
WATERFALL_PLANS = {
    'rank': {1.80:10_000, 1.85:10_000, 1.90:10_000, 1.95:50_000,
             2.00:50_000, 2.05:250_000, 2.10:1_000_000,
             2.15:3_000_000, 2.20:3_000_000},
    'exact': {-1.20:10_000, -1.15:10_000, -1.10:10_000, -1.05:50_000,
              -1.00:1_000_000, -.95:1_000_000, -.90:3_000_000,
              -.85:5_000_000, -.80:30_000_000},
}


def _settings(family, scheme):
    if family == 'rank':
        return dict(m=150, rank_threshold=2000,
                    ldpc_rate=1 / 3 if scheme == 'bfc' else 5 / 6)
    if (family, scheme) == ('exact', 'conventional'):
        return dict(m=100, ldpc_rate=3 / 5)
    raise ValueError((family, scheme))


def generate(out):
    if out.exists():
        raise ValueError('Use a fresh destination; results are never overwritten')
    all_snrs = sorted({snr for plan in PLANS.values() for snr in plan})
    snr_indices = {snr: i + 1 for i, snr in enumerate(all_snrs)}
    tasks = []
    for (family, scheme), plan in PLANS.items():
        settings = _settings(family, scheme)
        for snr, frames_per_point in sorted(plan.items()):
            shard_frames=min(frames_per_point, BFC_SHARD_FRAMES if scheme=='bfc' else SHARD_FRAMES)
            if frames_per_point % shard_frames:
                raise ValueError('Every frame budget must be a whole number of shards')
            for first in range(1, frames_per_point + 1, shard_frames):
                shard = (first - 1) // shard_frames
                tasks.append(dict(kind='task_comparison', family=family, scheme=scheme,
                    nt=60, G=360, frames_per_point=frames_per_point,
                    source_seed=20261001, position_seed=20261002,
                    noise_seed=20261003, snr_db=snr,
                    snr_index=snr_indices[snr], frames=shard_frames,
                    first_frame=first, runtime_limit=2400,
                    output=(f'results/{family}_{scheme}_{snr:+06.2f}_'
                            f'{shard:03d}_task_error_nt60.mat'), **settings))
    budgets = {
        f'{family}:{scheme}': {str(snr): frames for snr, frames in plan.items()}
        for (family, scheme), plan in PLANS.items()
    }
    tasks.sort(key=lambda t:(t['first_frame'], t['family'], t['scheme'], t['snr_db']))
    save_json(out / 'tasks.json', tasks)
    pilot=[]
    for family, scheme, snr in [('rank','bfc',-4.6), ('rank','bfc',-4.3),
                               ('rank','conventional',2.0), ('rank','conventional',2.10),
                               ('exact','conventional',-.9)]:
        task=next(t for t in tasks if (t['family'],t['scheme'],t['snr_db'],t['first_frame'])==
                  (family,scheme,snr,1)).copy()
        task.update(frames=1000, frames_per_point=1000,
                    source_seed=20261101, position_seed=20261102, noise_seed=20261103,
                    output=f'pilot/{family}_{scheme}_{snr:+06.2f}.mat')
        pilot.append(task)
    save_json(out/'pilot.json',pilot)
    save_json(out / 'design.json', dict(
        stage='fixed_task_error_comparison', primary_metric='balanced_task_error',
        targets=list(TARGETS), nt=60, G=360, Nb=64800, neff=180,
        rank=dict(m=150, threshold=2000, support=2001, K=5,
                  noiseless_fp_bound=8004 / 2**30,
                  balanced_fp_bound=4002 / 2**30,
                  bfc_rate=1 / 3, conventional_rate=5 / 6,
                  bfc_payload_bits=21600, conventional_payload_bits=54000),
        exact=dict(m=100, support=4950, K=4,
                   noiseless_fp_bound=14850 / 2**30,
                   balanced_fp_bound=7425 / 2**30,
                   conventional_rate=3 / 5, conventional_payload_bits=36000,
                   conventional_padding_bits=2880),
        frames_per_point=budgets, conventional_shard_frames=SHARD_FRAMES,
        bfc_shard_frames=BFC_SHARD_FRAMES,
        source_seed=20261001, position_seed=20261002, noise_seed=20261003,
        snr_definition='Es/N0', max_array_concurrency=128,
        recommended_array_concurrency=64, cpus_per_task=8,
        memory_gb=4, wall_time='00:45:00', runtime_limit_seconds=2400,
        fixed_before_sampling=True,
        rationale=('Budgets use existing independent campaigns only for design: '
                   '10k-500k frames locate each waterfall and 1M-3M frames resolve '
                   'balanced task error near 1e-5 and 1e-6.')))
    print(f'{len(tasks)} jobs; {sum(t["frames"] for t in tasks):,} fresh frames')


def extend_low_snr(out):
    """Add plateau points without changing running task indices or RNG streams."""
    tasks = json.loads((out/'tasks.json').read_text())
    template = next(t for t in tasks if (t['family'],t['scheme']) == ('rank','bfc'))
    existing = {t['snr_db'] for t in tasks if (t['family'],t['scheme']) == ('rank','bfc')}
    next_index = max(t['snr_index'] for t in tasks) + 1
    additions = []
    for snr in (-5., -4.9):
        if snr in existing: continue
        for shard, first in enumerate(range(1,100001,BFC_SHARD_FRAMES)):
            additions.append(dict(template, snr_db=snr, snr_index=next_index,
                frames_per_point=100000, frames=BFC_SHARD_FRAMES, first_frame=first,
                output=f'results/rank_bfc_{snr:+06.2f}_{shard:03d}_task_error_nt60.mat'))
        next_index += 1
    if not additions:
        raise ValueError('Low-SNR points already present')
    for name, values in [('low_snr_tasks.json', additions), ('report_tasks.json',tasks+additions)]:
        if (out/name).exists(): raise ValueError(f'Already exists: {out/name}')
    save_json(out/'low_snr_tasks.json', additions)
    save_json(out/'report_tasks.json', tasks+additions)
    save_json(out/'low_snr_extension.json', dict(reason='Align BFC starting SNR with ID/exact at -5 dB',
        snrs=[-5.,-4.9], frames_per_point=100000, original_manifest_unchanged=True,
        jobs=len(additions), total_frames=sum(t['frames'] for t in additions)))
    print(f'{len(additions)} additional jobs; original tasks and RNG streams unchanged')


def align_grid(out, source_name=None, prefix='grid01'):
    """Reuse original on-grid records verbatim so checkpoints remain resumable."""
    source = out/(source_name or 'report_tasks.json')
    if not source.exists(): source = out/'tasks.json'
    original = json.loads(source.read_text())
    destination = out/f'{prefix}_tasks.json'
    if destination.exists(): raise ValueError(f'Already exists: {destination}')
    next_index = max(t['snr_index'] for t in original)+1
    tasks = []
    for (family, scheme), plan in PLANS.items():
        template = next(t for t in original if (t['family'],t['scheme'])==(family,scheme))
        for snr, frames in plan.items():
            existing = [t for t in original if
                (t['family'],t['scheme'],t['snr_db'])==(family,scheme,snr)]
            if existing:
                assert sum(t['frames'] for t in existing)==frames
                assert all(t['frames_per_point']==frames for t in existing)
                tasks.extend(existing)
                continue
            shard_frames = min(frames, BFC_SHARD_FRAMES if scheme=='bfc' else SHARD_FRAMES)
            for shard, first in enumerate(range(1,frames+1,shard_frames)):
                tasks.append(dict(template, snr_db=snr, snr_index=next_index,
                    frames_per_point=frames, frames=shard_frames, first_frame=first,
                    output=f'results/{family}_{scheme}_{snr:+06.2f}_{shard:03d}_task_error_nt60.mat'))
            next_index += 1
    tasks.sort(key=lambda t:(t['first_frame'],t['family'],t['scheme'],t['snr_db']))
    save_json(destination,tasks)
    save_json(out/f'{prefix}_design.json',dict(snr_step_db=.1,
        frames_per_point={f'{f}:{s}':plan for (f,s),plan in PLANS.items()},
        source_manifest=source.name, checkpoint_metadata_preserved=True,
        jobs=len(tasks),total_frames=sum(t['frames'] for t in tasks)))
    print(f'{len(tasks)} jobs; {sum(t["frames"] for t in tasks):,} frames; 0.1 dB grid')
    return tasks


def extend_conventional(out):
    original = json.loads((out/'grid01_tasks.json').read_text())
    paths = {t['output'] for t in original}
    combined = align_grid(out, source_name='grid01_tasks.json', prefix='full_grid')
    additions = [t for t in combined if t['output'] not in paths]
    save_json(out/'conventional_plateau_tasks.json', additions)
    print(f'{len(additions)} added conventional plateau jobs')


def extend_exact_tail(out, total_frames=30_000_000):
    """Continue the same independent frame sequence at exact conventional -0.8 dB."""
    original=json.loads((out/'full_grid_tasks.json').read_text())
    target=[t for t in original if
        (t['family'],t['scheme'],t['snr_db'])==('exact','conventional',-.8)]
    completed=sum(t['frames'] for t in target)
    assert {t['frames_per_point'] for t in target}=={completed}
    assert total_frames>completed and total_frames%SHARD_FRAMES==0
    if (out/'exact_tail_tasks.json').exists(): raise ValueError('Tail extension already exists')
    additions=[]
    for first in range(completed+1,total_frames+1,SHARD_FRAMES):
        shard=(first-1)//SHARD_FRAMES
        additions.append(dict(target[0],first_frame=first,frames=SHARD_FRAMES,
            frames_per_point=total_frames,
            output=f'results/exact_conventional_-00.80_{shard:03d}_task_error_nt60.mat'))
    save_json(out/'exact_tail_tasks.json',additions)
    save_json(out/'tail_report_tasks.json',original+additions)
    save_json(out/'exact_tail_design.json',dict(snr_db=-.8,previous_frames=completed,
        total_frames=total_frames,additional_frames=total_frames-completed,
        jobs=len(additions),fixed_extension_budget=True,
        rationale='Seek a nonzero tail estimate after zero errors in the initial 3M frames; a further zero result remains an upper limit.',
        original_task_metadata_preserved=True,source_and_noise_streams_continued=True))
    print(f'{len(additions)} jobs; {total_frames-completed:,} added frames; {total_frames:,} total at -0.8 dB')


def refine_waterfalls(out):
    original=json.loads((out/'full_grid_tasks.json').read_text())
    if (out/'waterfall_tasks.json').exists(): raise ValueError('Refinement already exists')
    next_index=max(t['snr_index'] for t in original)+1
    additions=[]
    for family, plan in WATERFALL_PLANS.items():
        template=next(t for t in original if (t['family'],t['scheme'])==(family,'conventional'))
        for snr,total in plan.items():
            old=[t for t in original if (t['family'],t['scheme'],t['snr_db'])==(family,'conventional',snr)]
            existing=sum(t['frames'] for t in old)
            assert existing<=total
            if old:
                template_point=old[0]
                assert {t['frames_per_point'] for t in old}=={existing}
            else:
                template_point=dict(template,snr_db=snr,snr_index=next_index)
                next_index+=1
            for first in range(existing+1,total+1,SHARD_FRAMES):
                shard=(first-1)//SHARD_FRAMES
                additions.append(dict(template_point,first_frame=first,frames=SHARD_FRAMES,
                    frames_per_point=total,
                    output=f'waterfall_results/{family}_conventional_{snr:+06.2f}_{shard:04d}.mat'))
    additions.sort(key=lambda t:(t['first_frame'],t['family'],t['snr_db']))
    save_json(out/'waterfall_tasks.json',additions)
    save_json(out/'waterfall_report_tasks.json',original+additions)
    save_json(out/'waterfall_design.json',dict(waterfall_step_db=.05,low_snr_step_db=.1,
        total_frames_per_point=WATERFALL_PLANS,original_manifest='full_grid_tasks.json',
        jobs=len(additions),additional_frames=sum(t['frames'] for t in additions),
        old_samples_preserved=True,new_snr_streams_above_original_max=True,
        fixed_refinement_budgets=True,
        note='Zero-error endpoints remain upper limits if no errors occur in the enlarged sample.'))
    print(f'{len(additions)} jobs; {sum(t["frames"] for t in additions):,} additional frames')


def _task_equal(saved, expected):
    return all(key in saved and saved[key] == value for key, value in expected.items())


def _upper95(values):
    """One-sided frame-cluster normal bound; exact event bound at zero."""
    values = np.asarray(values, dtype=float)
    mean = float(values.mean())
    if not np.any(values):
        return 1 - .05 ** (1 / len(values))
    se = float(values.std(ddof=1) / math.sqrt(len(values)))
    return min(1., mean + 1.6448536269514722 * se)


def _crossing(rows, target):
    rows = sorted(rows, key=lambda row: row['snr_db'])
    for left, right in zip(rows, rows[1:]):
        y0, y1 = left['balanced_error'], right['balanced_error']
        if y0 >= target >= y1 and y0 > 0 and y1 > 0 and y0 != y1:
            fraction = ((math.log10(target) - math.log10(y0)) /
                        (math.log10(y1) - math.log10(y0)))
            return left['snr_db'] + fraction * (right['snr_db'] - left['snr_db'])
    exact = [row['snr_db'] for row in rows if row['balanced_error'] == target]
    return exact[0] if exact else None


def _read_groups(out, tasks):
    groups = {}
    for task in tasks:
        path = out / task['output']
        if not path.exists():
            raise ValueError(f'Missing shard: {path}')
        result = loadmat(path, simplify_cells=True)['result']
        if not result['complete'] or int(result['frames_done']) != task['frames']:
            raise ValueError(f'Incomplete shard: {path}')
        if not _task_equal(result['task'], task):
            raise ValueError(f'Task metadata mismatch: {path}')
        config=result['config']; channel=result['channel']
        if (config['m']!=task['m'] or config['nt']!=60 or config['G']!=360 or
            channel['Nb']!=64800 or abs(channel['Rc']-task['ldpc_rate'])>1e-12):
            raise ValueError(f'Configuration mismatch: {path}')
        if task['family']=='rank' and config['rank_threshold']!=2000:
            raise ValueError(f'Wrong rank threshold: {path}')
        data = np.atleast_2d(result['per_frame'])
        if (data.shape != (task['frames'], 8) or not np.all(np.isfinite(data)) or
            np.any(data<0) or np.any(data!=np.floor(data))):
            raise ValueError(f'Invalid per-frame data: {path}')
        half = task['G'] // 2
        if not np.all(data[:, :2] == half) or np.any(data[:, 2:4] > half):
            raise ValueError(f'Invalid class/error counts: {path}')
        if not np.all(np.isin(data[:, 4:6], [0, 1])):
            raise ValueError(f'Invalid FER indicators: {path}')
        if task['scheme'] == 'conventional':
            if np.any((data[:, 2] + data[:, 3] > 0) & (data[:, 4] == 0)):
                raise ValueError(f'Conventional task error without payload error: {path}')
            if np.any(data[:, 6]):
                raise ValueError(f'Conventional noiseless FP must be zero: {path}')
        else:
            correct = data[:, 4] == 0
            if np.any(data[correct, 2] != data[correct, 6]) or np.any(data[correct, 3]):
                raise ValueError(f'Incorrect BFC payload-correct identity: {path}')
        key = (task['family'], task['scheme'], float(task['snr_db']))
        group = groups.setdefault(key, dict(totals=np.zeros(8), n=0,
                                             sum_squares=0., events=0, ranges=[], runtime=0.,
                                             fp_bound=float(result['config']['bound'])))
        if group['fp_bound'] != float(result['config']['bound']):
            raise ValueError(f'Inconsistent FP bound: {path}')
        values = (data[:,2].astype(float)+data[:,3]) / task['G']
        group['totals'] += data.sum(axis=0, dtype=np.float64)
        group['n'] += len(data)
        group['sum_squares'] += float(np.dot(values,values))
        group['events'] += int(np.count_nonzero(values))
        group['ranges'].append((task['first_frame'], task['first_frame'] + task['frames'] - 1))
        group['runtime'] += float(result['runtime_seconds'])
    return groups


def collect_exact_bfc(root):
    """Read only the unchanged exact BFC reference, never the old rank task."""
    groups = {}
    for path in sorted((root / 'noisy_n_t_60').glob('exact_bfc_*.mat')):
        result = loadmat(path, simplify_cells=True)['result']
        task, config = result['task'], result['config']
        if (not result['complete'] or result['frames_done'] != task['frames'] or
            task['family'] != 'exact' or task['scheme'] != 'bfc' or
            config['nt'] != 60 or config['m'] != 100 or config['G'] != 360):
            raise ValueError(f'Invalid exact BFC reference: {path}')
        data = np.atleast_2d(result['per_frame'])
        if len(data) != task['frames'] or not np.all(data[:, :2] == 180):
            raise ValueError(f'Invalid reference counts: {path}')
        group = groups.setdefault(float(task['snr_db']), dict(data=[], ranges=[]))
        group['data'].append(data)
        group['ranges'].append((int(task['first_frame']), int(task['frames'])))
    if not groups:
        raise ValueError(f'No exact BFC reference in {root}')
    rows = []
    for snr, group in sorted(groups.items()):
        if abs(snr*10-round(snr*10)) > 1e-8: continue
        cursor = 1
        for first, count in sorted(group['ranges']):
            if first != cursor:
                raise ValueError(f'Incomplete/overlapping reference at {snr}')
            cursor += count
        data = np.concatenate(group['data'])
        if len(data) != 10000:
            raise ValueError(f'Expected 10000 archived exact BFC frames at {snr}')
        values = (data[:, 2] + data[:, 3]) / 360
        events = int(np.count_nonzero(values))
        rows.append(dict(family='exact', scheme='bfc', snr_db=snr,
            frames=len(data), balanced_error=float(values.mean()),
            task_error_se=float(values.std(ddof=1)/np.sqrt(len(data))),
            task_error_upper95_conservative=float(beta.ppf(.95, events+1, len(data)-events))
                if events < len(data) else 1.,
            source=str(root), task_error_frames=events))
    return rows


def summarize(out, manifest='tasks.json', exact_root=None):
    tasks = json.loads((out / manifest).read_text())
    groups = _read_groups(out, tasks)
    rows = []
    for (family, scheme, snr), group in sorted(groups.items()):
        cursor = 1
        for first, last in sorted(group['ranges']):
            if first != cursor:
                raise ValueError(f'Missing or overlapping frames: {(family, scheme, snr)}')
            cursor = last + 1
        n = group['n']
        planned={t['frames_per_point'] for t in tasks if
                 (t['family'],t['scheme'],t['snr_db'])==(family,scheme,snr)}
        # A declared extension preserves the original shards' saved metadata;
        # new shards carry the enlarged budget. Frame ranges must still tile 1..n.
        if max(planned)!=n: raise ValueError(f'Incomplete planned sample: {(family,scheme,snr)}')
        events = group['events']
        event_upper = 1. if events == n else float(beta.ppf(.95, events + 1, n - events))
        totals = group['totals']
        mean = float((totals[2]+totals[3])/(totals[0]+totals[1]))
        se = math.sqrt(max(0.,group['sum_squares']-n*mean**2)/(n-1)/n)
        rows.append(dict(family=family, scheme=scheme, snr_db=snr, frames=n,
            fp_count=int(totals[2]), fn_count=int(totals[3]),
            negative_trials=int(totals[0]), positive_trials=int(totals[1]),
            FP=totals[2]/totals[0], FN=totals[3]/totals[1],
            balanced_error=mean, task_error_frames=events,
            task_error_se=se,
            task_error_upper95_approx=(event_upper if events==0 else min(1.,mean+1.6448536269514722*se)),
            task_error_upper95_conservative=event_upper,
            payload_FER=totals[4]/n, information_FER=totals[5]/n,
            noiseless_balanced_error=totals[6]/(totals[0]+totals[1]),
            balanced_fp_bound=.5*group['fp_bound'],
            mean_iterations=totals[7]/n, runtime_job_hours=group['runtime']/3600))
    with (out / 'task_error_summary.csv').open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader(); writer.writerows(rows)
    if exact_root is not None:
        rows.extend(collect_exact_bfc(exact_root))
    thresholds = []
    for family, scheme in sorted({(r['family'], r['scheme']) for r in rows}):
        curve = [r for r in rows if (r['family'], r['scheme']) == (family, scheme)]
        for target in TARGETS:
            below = next((r for r in curve if r['balanced_error'] < target), None)
            thresholds.append(dict(family=family, scheme=scheme, target=target,
                crossing_snr_db=_crossing(curve, target),
                first_empirical_below_db=None if below is None else below['snr_db'],
                tail_needs_more_frames=bool(below is not None and
                    below['task_error_frames'] < 30 and
                    below['task_error_upper95_conservative'] >= target)))
    report = dict(metric='balanced task error (FP+FN)/(360*frames)', points=rows,
        thresholds=thresholds,
        coding_gains=coding_gains(rows),
        uncertainty=('Messages within one LDPC frame are correlated. SE and approximate '
                     'normal bounds use independent frame means; normal bounds are unreliable '
                     'with few error-bearing frames. The conservative exact binomial upper '
                     'bound uses the probability of any task error in a frame, which bounds '
                     'the mean task error. Zero observations are upper limits, not zero risk.'),
        coding_gain_note='Interpolate only between positive measured probabilities bracketing the target; never extrapolate across the BFC floor.')
    save_json(out / 'task_error_report.json', report)
    print(json.dumps(thresholds, indent=2))
    return rows


def coding_gains(rows):
    gains=[]
    for family in ('rank','exact'):
        for target in TARGETS:
            bfc=_crossing([r for r in rows if (r['family'],r['scheme'])==(family,'bfc')],target)
            conventional=_crossing([r for r in rows if (r['family'],r['scheme'])==(family,'conventional')],target)
            gains.append(dict(family=family,target=target,bfc_snr_db=bfc,
                conventional_snr_db=conventional,
                coding_gain_db=None if bfc is None or conventional is None else conventional-bfc))
    return gains


def plot(rows, out, preliminary=False):
    fig, axes = plt.subplots(1, 2, figsize=(8, 3), sharey=True)
    for ax, family in zip(axes, ('rank', 'exact')):
        for scheme, style in (('bfc', 'o-'), ('conventional', 's--')):
            curve = sorted((r for r in rows if r['family']==family and r['scheme']==scheme),
                           key=lambda r:r['snr_db'])
            if scheme == 'bfc':
                curve = [r for r in curve if -5.00 <= r['snr_db'] <= -4.20]
            if not curve: continue
            positive = [r for r in curve if r['balanced_error']>0]
            ax.semilogy([r['snr_db'] for r in positive],
                        [r['balanced_error'] for r in positive], style, label=scheme)
            zero = [r for r in curve if r['balanced_error']==0]
            if zero:
                ax.semilogy([r['snr_db'] for r in zero],
                    [r['task_error_upper95_conservative'] for r in zero],
                    'v', fillstyle='none', label='zero errors: 95% upper limit')
        title = 'Rank ≤ 2000, m=150' if family == 'rank' else 'Exact weight = 2, m=100'
        ax.set(title=title, xlabel='Es/N0 (dB)', ylim=(1e-8,1))
        ax.grid(which='major', alpha=.25); ax.legend(fontsize=7, loc='upper center')
    axes[0].set_ylabel('Balanced task error probability')
    if preliminary:
        fig.suptitle('PRELIMINARY: rank pilots (1,000 frames); exact archived measurements', fontsize=9)
    fig.tight_layout(); fig.savefig(out/'task_error_comparison.pdf')
    fig.savefig(out/'task_error_comparison.png', dpi=200); plt.close(fig)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['generate','summarize','preview','extend-low-snr','align-grid','extend-conventional','extend-exact-tail','refine-waterfalls'])
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--manifest', default='tasks.json')
    here = Path(__file__).resolve().parent
    parser.add_argument('--exact-bfc', type=Path, default=here/'results/production_n_t_60')
    args=parser.parse_args()
    if args.action=='generate': generate(args.out)
    elif args.action=='extend-low-snr': extend_low_snr(args.out)
    elif args.action=='align-grid': align_grid(args.out)
    elif args.action=='extend-conventional': extend_conventional(args.out)
    elif args.action=='extend-exact-tail': extend_exact_tail(args.out)
    elif args.action=='refine-waterfalls': refine_waterfalls(args.out)
    elif args.action=='summarize':
        plot(summarize(args.out, args.manifest, args.exact_bfc), args.out)
    else:
        rows = collect_exact_bfc(args.exact_bfc)
        sources = [(here/'results/task_error_rank2000_m150_nt60_20260926/task_error_summary.csv', 'rank'),
                   (here/'results/conventional_million_rc_3_5_n_t_60/summary.csv', 'exact')]
        for path, family in sources:
            for row in csv.DictReader(path.open()):
                if family == 'rank' and row['family'] != 'rank': continue
                if family == 'exact' and not -1.2 <= float(row['snr_db']) <= -.84: continue
                item = {k: float(row[k]) for k in ('snr_db','balanced_error','task_error_upper95_conservative')}
                item.update(family=family, scheme=row.get('scheme', 'conventional'))
                rows.append(item)
        args.out.mkdir(parents=True, exist_ok=True)
        plot(rows, args.out, preliminary=True)


if __name__=='__main__': main()
