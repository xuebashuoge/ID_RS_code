#!/usr/bin/env python3
"""Validate saved evidence and build all ITW figures, tables, and provenance."""
from pathlib import Path
import csv, hashlib, json, math, os, re
os.environ.setdefault('MPLCONFIGDIR', '/tmp/itw2027-matplotlib')
import numpy as np
from scipy.io import loadmat
from scipy.stats import beta as beta_distribution
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from rate_model import FAMILIES, support, theorem_design, certificate, packing

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path(os.environ.get('ITW_EVIDENCE_ROOT', ROOT/'results/evidence'))
OUT = Path(os.environ.get('ITW_OUTPUT_ROOT', ROOT/'results/processed'))
COLORS = dict(zip(FAMILIES, ['#0072B2','#D55E00','#009E73']))
LABELS = {'id':'ID', 'rank':'Rank (20)', 'exact-threshold':r'Exact threshold ($\beta=2$)'}
plt.rcParams.update({'font.size':8, 'axes.labelsize':8.5,'legend.fontsize':8,
                     'pdf.fonttype':42,'ps.fonttype':42,'axes.spines.top':False,
                     'axes.spines.right':False,'lines.linewidth':1.35})

def csv_write(name, rows):
    if not rows: raise ValueError(f'Empty output {name}')
    p=OUT/'tables'/name; p.parent.mkdir(parents=True,exist_ok=True)
    fields=list(dict.fromkeys(k for row in rows for k in row))
    with p.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows(rows)

def savefig(fig,name):
    d=OUT/'figures'; d.mkdir(parents=True,exist_ok=True)
    fig.savefig(d/(name+'.pdf'),bbox_inches='tight')
    fig.savefig(d/(name+'.png'),dpi=300,bbox_inches='tight')
    plt.close(fig)

def noiseless():
    groups={}; runs=[]; seeds=set()
    for p in sorted((EVIDENCE/'noiseless/finite_length').glob('*.mat')):
        x=loadmat(p,simplify_cells=True); md=x['metadata']; st=x['stat']
        f,n=md['func_type'],int(md['n']); key=(f,n)
        counts=np.atleast_1d(st['R_counts']); prob=np.atleast_1d(st['fpr_exact'])
        assert len(counts)==md['num_negative_messages']
        assert (f,n,md['seed']) not in seeds, 'Duplicate shard seed'
        seeds.add((f,n,md['seed']))
        S=support(int(md['m']),f)
        assert S==md['S'] and md['m']==md['r']*md['K']
        B=S*(md['K']-1)/md['L']
        assert np.allclose(prob,counts/md['L'],atol=0,rtol=0)
        assert np.all(prob<=B+1e-15)
        design=theorem_design(n,f)
        assert design['K']==md['K'], (f,n,'legacy design mismatch')
        groups.setdefault(key,[]).append((md,prob))
        runs.append(dict(file=str(p.relative_to(ROOT)),**md))
    assert len(groups)==27, f'Expected 27 noiseless cells, got {len(groups)}'
    rows=[]
    for (f,n),items in sorted(groups.items()):
        md=items[0][0]; probs=np.concatenate([a[1] for a in items])
        assert all(a[0]['K']==md['K'] for a in items)
        rows.append(dict(family=f,n_t=n,m=int(md['m']),r=int(md['r']),K=int(md['K']),
            T=int(md['L']),S=int(md['S']),R_t=math.log2(md['m'])/n,
            bound=md['theorem_bound'],count=len(probs),shards=len(items),
            q05=np.quantile(probs,.05),median=np.median(probs),q95=np.quantile(probs,.95),
            sample_max=probs.max(),sample_mean=probs.mean(),zero_count=int(sum(probs==0))))
    adversarial=[]
    for p in sorted((EVIDENCE/'noiseless/adversarial').glob('*.mat')):
        md=loadmat(p,simplify_cells=True)['metadata']
        if md['verified']:
            assert md['observed_R']==md['S']*(md['K']-1)
        adversarial.append(dict(**md,interpretation='arbitrary support of matching size; not the named rank/threshold function'))
    csv_write('noiseless_distribution.csv',rows);csv_write('noiseless_runs.csv',runs)
    csv_write('adversarial_verification.csv',adversarial)
    return rows,adversarial

def noisy():
    rows=[]
    for p in sorted((EVIDENCE/'noisy').rglob('result*.mat')):
        r=loadmat(p,simplify_cells=True)['result']
        d,b,c,pf=r['derived'],r['bank_metadata'],r['counts'],r['per_frame']
        assert r['complete'] and r['frames']==2500 and r['stopping']['mode']=='fixed_frames'
        assert r['config']['ldpc']['algorithm']=='bp'
        f=b['func_type']; S=support(int(d['m']),f); assert S==b['S']
        assert d['L']==2**d['r'] and d['rs_evaluation_order']=='extended-zero-first-v1'
        pack=packing(int(d['n']),int(d['m']),int(d['ldpc_N']),int(d['ldpc_K']))
        assert abs(pack['R_eff']-d['parallel_bfc_rate'])<1e-12
        assert pack['G']==d['tuples_per_frame']
        n0=np.asarray(pf['actual_zero'],dtype=float);n1=np.asarray(pf['actual_one'],dtype=float)
        bad=np.asarray(pf['ldpc_error'],dtype=float)
        fp=np.asarray(pf['coded_false_positive'],dtype=float)
        fn=np.asarray(pf['coded_false_negative'],dtype=float)
        intrinsic=np.asarray(pf['noiseless_false_positive'],dtype=float)
        assert len(fp)==r['frames']
        assert fp.sum()==c['coded']['false_positive'] and fn.sum()==c['coded']['false_negative']
        assert n0.sum()==c['coded']['actual_zero'] and n1.sum()==c['coded']['actual_one']
        # Exact paired finite-sample inequalities; no FER-as-maximal-error claim.
        assert np.all(fp <= intrinsic+n0*bad) and np.all(fn<=n1*bad)
        assert np.all(fn[bad==0]==0) and np.all(fp[bad==0]==intrinsic[bad==0])
        fer=bad.mean();k=int(bad.sum());N=len(bad)
        ferlo=0 if k==0 else beta_distribution.ppf(.025,k,N-k+1)
        ferhi=1 if k==N else beta_distribution.ppf(.975,k+1,N-k)
        bound=S*(d['K']-1)/d['L']
        ci=r['metrics']['coded']['cluster_conditional_ci95']
        row=dict(experiment=p.relative_to(EVIDENCE/'noisy').parts[0],family=f,n_t=int(d['n']),
            m=int(d['m']),K=int(d['K']),T=int(d['L']),S=S,bound=bound,
            **pack,ebno_db=r['scenario']['ebno_db'],frames=N,frame_errors=k,
            fer=fer,fer_lower95=ferlo,fer_upper95=ferhi,
            fpr=fp.sum()/n0.sum(),fnr=fn.sum()/n1.sum(),noiseless_fpr=intrinsic.sum()/n0.sum(),
            fpr_lower95=ci['fpr'][0],fpr_upper95=ci['fpr'][1],fnr_lower95=ci['fnr'][0],fnr_upper95=ci['fnr'][1],
            max_error=max(fp.sum()/n0.sum(),fn.sum()/n1.sum()),max_lower95=ci['max'][0],max_upper95=ci['max'][1],
            fp_count=int(fp.sum()),fn_count=int(fn.sum()),negative_trials=int(n0.sum()),positive_trials=int(n1.sum()),
            bad_frame_given_negative=(n0*bad).sum()/n0.sum(),bad_frame_given_positive=(n1*bad).sum()/n1.sum(),
            zero_frame_upper95=-math.expm1(math.log(.05)/N),
            fpr_zero_upper95=-math.expm1(math.log(.05)/N)*N*n0.max()/n0.sum(),
            fnr_zero_upper95=-math.expm1(math.log(.05)/N)*N*n1.max()/n1.sum(),
            diagnostic_fp_envelope=min(1,bound+fer),
            runtime_hours=r['runtime_seconds']/3600,seed=r['scenario']['seed'],
            source=str(p.relative_to(ROOT)))
        rows.append(row)
    replacement=[r for r in rows if r['experiment']=='threshold_nt40']
    legacy=[r for r in rows if r['experiment'] in ('waterfall','rate_pareto')]
    assert len(legacy)==126 and sum(r['experiment']=='waterfall' for r in legacy)==66
    csv_write('noisy_archived_and_new_points.csv',rows)
    if replacement:
        assert len(replacement)==22, 'Incomplete n_t=40 replacement: export all 22 points before rebuilding.'
        assert all(r['family']=='exact-threshold' and r['n_t']==40 for r in replacement)
        assert {round(r['ebno_db'],6) for r in replacement}=={round(.5+.1*i,6) for i in range(22)}
        assert all((r['K'],r['m'],r['S'],r['G'],r['padding'],r['R_c'])==(6,120,7140,810,0,.5) for r in replacement)
        rows=[r for r in legacy if not (r['experiment']=='waterfall' and r['family']=='exact-threshold')]
        rows += [dict(r,experiment='waterfall',source_experiment='threshold_nt40') for r in replacement]
    else:
        rows=legacy
    csv_write('noisy_all_points.csv',rows)
    representative=[r for r in rows if r['experiment']=='waterfall' and abs(r['ebno_db']-1.5)<1e-8]
    csv_write('representative_1p5dB.csv',representative)
    table=[]
    for row in sorted(representative,key=lambda r:FAMILIES.index(r['family'])):
        table.append({k:row[k] for k in ['family','n_t','m','K','T','S','bound','G','padding','n_eff','R_eff','packing_gain']} |
                     {'R_t':math.log2(row['m'])/row['n_t'],'R_asymptotic_noiseless':1/6 if row['family']=='exact-threshold' else .5,
                      'R_asymptotic_noisy':1/12 if row['family']=='exact-threshold' else .25})
    csv_write('paper_parameters.csv',table)
    lines=[r'\begin{tabular}{lrrrrrr}',r'\hline',r'Function & $n_t$ & $m$ & $S$ & $R_t$ & $G$ & $R_{\rm eff}$\\',r'\hline']
    for r in table:
        label={'id':'ID','rank':'Rank (20)','exact-threshold':r'Exact ($\beta=2$)'}[r['family']]
        lines.append(f"{label} & {r['n_t']} & {r['m']:,} & {r['S']:,} & {r['R_t']:.3f} & {r['G']} & {r['R_eff']:.3f}"+r'\\')
    lines.extend([r'\hline',r'\end{tabular}'])
    (OUT/'tables/paper_parameters.tex').write_text('\n'.join(lines)+'\n')
    return rows,table

def rate_results():
    rows=[]
    for f in FAMILIES:
        for n in sorted(set(range(24,202,2))|{256,512,1024,2048,4096}):
            for name,E in [('fixed_E',.1),('vanishing_E',1/math.sqrt(n))]:
                d=theorem_design(n,f,E)
                if d:
                    # S,T,m may be huge: write as decimal strings, not floats.
                    rows.append({'family':f,'sequence':name,**d})
    csv_write('rate_sequences.csv',rows)
    finite=[]
    for f in FAMILIES:
        for n in range(12,81):
            for aligned in (True,False):
                d=certificate(n,f,aligned=aligned)
                if d: finite.append(dict(family=f,epsilon=.01,**d))
    csv_write('finite_rate_at_1percent.csv',finite)
    return rows

def legend_line(label, **kwargs):
    return Line2D([], [], label=label, **kwargs)


def clean_axis(ax):
    ax.grid(axis='y', which='major', color='0.88', linewidth=.55)
    ax.tick_params(axis='both', which='both', direction='out', length=3)
    ax.set_axisbelow(True)


def figure_noiseless(rows,adv,rates):
    # Three small panels separate overlapping family bounds without changing
    # coordinates. Nested markers distinguish coincident median and maximum.
    fig=plt.figure(figsize=(3.5,2.85))
    grid=fig.add_gridspec(3,2,left=.145,right=.99,bottom=.15,top=.75,
                         width_ratios=[1,1.04],hspace=.45,wspace=.46)
    panels=[]
    for i,f in enumerate(FAMILIES):
        ax=fig.add_subplot(grid[i,0]);panels.append(ax)
        rr=sorted([r for r in rows if r['family']==f],key=lambda x:x['n_t'])
        xx=[r['n_t'] for r in rr];cc=COLORS[f]
        ax.plot(xx,[r['bound'] for r in rr],color='0.25',ls='--',lw=.8,zorder=1)
        ax.plot(xx,[r['sample_max'] for r in rr],ls='none',marker='s',ms=4,
                markerfacecolor='none',markeredgecolor=cc,markeredgewidth=.8,zorder=3)
        ax.plot(xx,[r['median'] for r in rr],color=cc,lw=.7,marker='o',ms=1.8,zorder=4)
        # Common limits retain direct comparisons of magnitudes across rows.
        ax.set_yscale('log');ax.set_ylim(3e-7,.4)
        ax.set_yticks([1e-6,1e-3,1e-1]);ax.set_xlim(23,41)
        ax.set_xticks([24,32,40])
        ax.text(.98,1.025,{'id':'ID','rank':'Rank','exact-threshold':'Exact'}[f],ha='right',va='bottom',color=cc,
                transform=ax.transAxes,fontsize=8)
        if i<2: ax.tick_params(labelbottom=False)
        else: ax.set_xlabel(r'$n_t$')
        clean_axis(ax)
    panels[1].set_ylabel('FP probability',labelpad=1)
    fig.text(.31,.995,'(a) FP error',ha='center',va='top',fontsize=9)
    fig.legend(handles=[
        legend_line('Median',color='0.25',lw=.7,marker='o',markersize=2),
        legend_line('Sample max.',color='0.25',ls='none',marker='s',markersize=4,markerfacecolor='none'),
        legend_line(r'Bound $B$',color='0.25',ls='--')],
        loc='upper left',bbox_to_anchor=(.12,.945),ncol=1,frameon=False,
        handlelength=1.3,handletextpad=.4,labelspacing=.12,borderaxespad=0)

    ax=fig.add_subplot(grid[:,1])
    markers={'id':'o','rank':'s','exact-threshold':'^'}
    for i,f in enumerate(FAMILIES):
        for seq,style in [('fixed_E','-'),('vanishing_E','--')]:
            rr=[r for r in rates if r['family']==f and r['sequence']==seq]
            # Markers are spread across log(n), with alternating high-n
            # positions for the nearly coincident ID/rank curves.
            targets={'id':[32,64,128,512,2048],
                     'rank':[44,88,176,256,1024,4096],
                     'exact-threshold':[36,72,144,512,2048]}[f]
            ns=np.array([r['n_t'] for r in rr])
            positions=sorted({int(np.argmin(abs(np.log(ns)-np.log(t)))) for t in targets})
            ax.plot([r['n_t'] for r in rr],[r['rate'] for r in rr],style,
                    color=COLORS[f],lw=.85,marker=markers[f],ms=2.8,
                    markerfacecolor='white',markevery=positions)
    ax.axhline(.5,color='0.5',lw=.9,ls=':');ax.axhline(1/6,color='0.5',lw=.9,ls=':')
    ax.text(4300,.506,r'$1/2$',ha='right',va='bottom',fontsize=8)
    ax.text(4300,.174,r'$1/6$',ha='right',va='bottom',fontsize=8)
    ax.set(xscale='log',xlabel=r'$n_t$',ylabel=r'$R_t$',ylim=(.08,.62))
    ax.set_yticks([.2,.4,.6]);ax.set_xticks([100,1000]);ax.yaxis.labelpad=1
    clean_axis(ax)
    fig.text(.80,.995,'(b) Rate',ha='center',va='top',fontsize=9)
    fig.legend(handles=[
        legend_line(r'$E=0.1$',color='0.25',ls='-'),
        legend_line(r'$E=n_t^{-1/2}$',color='0.25',ls='--'),
        legend_line('Benchmarks',color='0.5',ls=':')],
        loc='upper left',bbox_to_anchor=(.635,.945),ncol=1,frameon=False,
        handlelength=1.3,handletextpad=.4,labelspacing=.12,borderaxespad=0)
    ax.legend(handles=[legend_line({'id':'ID','rank':'Rank','exact-threshold':'Exact'}[f],
              color=COLORS[f],ls='none',marker=markers[f],markerfacecolor='white',ms=2.8)
              for f in FAMILIES],loc='center right',bbox_to_anchor=(1.03,.41),
              frameon=False,handlelength=.9,handletextpad=.3,labelspacing=.15,borderpad=.1)
    savefig(fig,'figure1_noiseless')


def figure_noisy(rows):
    fig,axes=plt.subplots(3,2,figsize=(3.5,2.95),sharex=True,sharey=True)
    fig.subplots_adjust(left=.14,right=.99,bottom=.15,top=.74,hspace=.45,wspace=.25)
    fig.text(.32,.995,'(a) FN / FER',ha='center',va='top',fontsize=9)
    fig.text(.81,.995,'(b) FP',ha='center',va='top',fontsize=9)
    fig.legend(handles=[
        legend_line('FN',color='0.25',ls='-',marker='o',ms=2),
        legend_line('FER',color='0.3',ls='--',marker='s',ms=3.5,markerfacecolor='none')],
        loc='upper left',bbox_to_anchor=(.145,.94),frameon=False,
        labelspacing=.15,handlelength=1.3,handletextpad=.4,borderaxespad=0)
    fig.legend(handles=[
        legend_line('FP',color='0.25',ls='none',marker='o',ms=2.8,markerfacecolor='white'),
        legend_line('Noiseless',color='0.25',ls='-',lw=.7),
        legend_line('Diagnostic',color='0.3',ls='--')],
        loc='upper left',bbox_to_anchor=(.64,.94),frameon=False,
        labelspacing=.15,handlelength=1.3,handletextpad=.4,borderaxespad=0)
    for i,f in enumerate(FAMILIES):
        rr=sorted([r for r in rows if r['family']==f and r['experiment']=='waterfall'],key=lambda x:x['ebno_db'])
        xx=np.array([r['ebno_db'] for r in rr]);cc=COLORS[f]
        left,right=axes[i]
        # A hollow large square surrounds the smaller FN dot if they coincide.
        left.plot(xx,[r['fer'] for r in rr],color='0.3',ls='--',lw=.7,
                  marker='s',ms=3.4,markerfacecolor='none',zorder=2)
        left.plot(xx,[r['fnr'] for r in rr],color=cc,lw=.75,
                  marker='o',ms=1.8,zorder=3)
        right.plot(xx,[r['diagnostic_fp_envelope'] for r in rr],color='0.3',ls='--',lw=.8,zorder=1)
        right.plot(xx,[r['noiseless_fpr'] for r in rr],color='0.2',lw=.7,zorder=2)
        # Points on a reference line explicitly show agreement, without a
        # second coincident line. No horizontal offsets or artificial floors.
        right.plot(xx,[r['fpr'] for r in rr],color=cc,ls='none',marker='o',ms=2.7,
                   markerfacecolor='white',markeredgewidth=.8,zorder=4)
        for ax in (left,right):
            ax.set_yscale('symlog',linthresh=1e-6,linscale=.5)
            ax.set_ylim(-1.2e-7,1.5);ax.set_xlim(.44,2.66)
            ax.set_yticks([0,1e-3,1]);ax.set_yticklabels(['0',r'$10^{-3}$','1'])
            ax.set_xticks([.5,1.5,2.5]);clean_axis(ax)
            ax.text(.98,1.025,{'id':'ID','rank':'Rank','exact-threshold':'Exact'}[f],transform=ax.transAxes,
                    ha='right',va='bottom',fontsize=8,color=cc)
    axes[1,0].set_ylabel('Error probability',labelpad=1)
    for ax in axes[-1]: ax.set_xlabel(r'$E_b/N_0$ (dB)')
    savefig(fig,'figure2_noisy')

    with plt.rc_context({'font.size':10,'axes.labelsize':10,'legend.fontsize':10}):
        fig,ax=plt.subplots(figsize=(3.5,2.7),layout='constrained')
        for f in FAMILIES:
            rr=sorted([r for r in rows if r['family']==f and r['experiment']=='rate_pareto' and abs(r['ebno_db']-1.5)<1e-8],key=lambda x:x['n_eff'])
            ax.plot([r['n_eff'] for r in rr],[r['max_error'] for r in rr],'-o',color=COLORS[f],ms=3,label=LABELS[f])
        ax.set(yscale='log',xlabel=r'Effective uses $N_b/G$',ylabel=r'$\max(\widehat P_{\rm FP},\widehat P_{\rm FN})$',title='Optional: rate tradeoff at 1.5 dB')
        ax.legend(fontsize=10);ax.grid(alpha=.2);savefig(fig,'optional_rate_tradeoff')

def provenance():
    rows=[]
    for p in sorted((ROOT/'results/source').rglob('*')):
        if not p.is_file(): continue
        rel=p.relative_to(ROOT/'results/source')
        base='/home/yangshuo/Git/ID_RS_code/conference_results/raw/' if rel.parts[0]=='noiseless' else '/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/'
        if rel.parts[:2]==('noisy','threshold_nt40'):
            base='/home/yangshuo/Git/itw2027_nt40_20260913/itw2027/results/source/noisy/'
        if rel.parts[0] not in ('noisy','noiseless'): continue
        rows.append(dict(local=str(p.relative_to(ROOT)),remote=base+str(Path(*rel.parts[1:])),bytes=p.stat().st_size,
                         sha256=hashlib.sha256(p.read_bytes()).hexdigest(),reuse='source_bank_copy_on_server' if 'source_banks' in p.parts else 'completed_evidence'))
    if rows: csv_write('reuse_manifest.csv',rows)
    rows=[]
    for p in sorted(EVIDENCE.rglob('*.mat')):
        rows.append(dict(file=str(p.relative_to(ROOT)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    csv_write('evidence_manifest.csv',rows)

def resource_logs():
    p=ROOT/'results/server_resource_logs.txt'
    rows=[]
    for block in re.split(r'(?=^/home/)',p.read_text(),flags=re.M):
        if not block.strip(): continue
        name=block.splitlines()[0]
        mem=re.search(r'\[(\d+)MB of',block)
        timing=re.search(r'Wall-clock time\s*:\s*([\d:-]+) /',block)
        cpu=re.search(r'Allocated CPUs\s*:\s*(\d+)',block)
        if not mem or not timing or not cpu: continue
        t=timing[1]; days=0
        if '-' in t: days,t=t.split('-')
        h,m,s=map(int,t.split(':'))
        kind='noisy_bank' if '/bp_bank_' in name else 'noisy_point' if '/bp_conf_' in name else 'adversarial' if 'adversarial' in name else 'noiseless'
        rows.append(dict(log=name,kind=kind,wall_hours=int(days)*24+h+m/60+s/3600,
                         memory_mb=int(mem[1]),cpus=int(cpu[1])))
    csv_write('server_resource_usage.csv',rows)

if __name__=='__main__':
    a,b=noiseless();c,t=noisy();r=rate_results()
    figure_noiseless(a,b,r);figure_noisy(c);provenance();resource_logs()
    report={'noiseless_cells':len(a),'noiseless_shards':sum(x['shards'] for x in a),
            'adversarial_verified':sum(bool(x['verified']) for x in b),
            'adversarial_skipped':sum(not bool(x['verified']) for x in b),
            'noisy_points':len(c),'frames_per_point':2500,'all_paired_error_checks_passed':True,
            'archived_noisy_points':len(list((EVIDENCE/'noisy').rglob('result*.mat'))),
            'matched_threshold_points':sum(x.get('source_experiment')=='threshold_nt40' for x in c),
            'noisy_comparison_nt_matched':all(x['n_t']==40 for x in c if x['experiment']=='waterfall'),
            'new_channel_simulation_required_for_selected_figures':any(x['n_t']!=40 for x in c if x['experiment']=='waterfall')}
    (OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2));print('Parameter table:',t)
