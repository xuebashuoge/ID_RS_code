"""Publication and diagnostic plots; all probabilities come from saved counts."""
import numpy as np
import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

FAMILIES=('id','rank','exact')
TITLES={'id':'Identification','rank':'Rank','exact':'Exact threshold'}
COLORS={'bfc':'#1768ac','conventional':'#c04b26'}


def save(fig,out,name):
    fig.savefig(out/f'{name}.pdf',bbox_inches='tight')
    fig.savefig(out/f'{name}.png',dpi=600,bbox_inches='tight')
    plt.close(fig)


def series(records,family,scheme):
    return sorted((r for r in records if r['family']==family and r['scheme']==scheme),
                  key=lambda r:r['snr_db'])


def draw_overall(ax,records,family,limits=None):
    for scheme in ('bfc','conventional'):
        rows=series(records,family,scheme)
        if not rows: continue
        x=np.array([r['snr_db'] for r in rows]); y=np.array([r['balanced_error'] for r in rows])
        if limits is not None:
            mask=(x>=limits[0]) & (x<=limits[1])
            x=x[mask]; y=y[mask]
        ax.plot(x,np.where(y>0,y,np.nan),color=COLORS[scheme],
                marker='o' if scheme=='bfc' else 's',markersize=3,
                linestyle='-' if scheme=='bfc' else '--',
                label='BFC' if scheme=='bfc' else 'Conventional')
        if scheme=='bfc':
            # Largest source sample, not a pool of repeated banks across SNR.
            ref=max(rows,key=lambda r:r['frames'])['noiseless_balanced_error']
            if ref>0: ax.axhline(ref,color='0.45',ls=':',lw=1.2,label='Noiseless BFC')
    ax.set(yscale='log',ylim=(1e-7,.7))
    if limits: ax.set_xlim(*limits)
    ax.grid(True,which='major',alpha=.2)


def plot_noisy(records,out):
    fig=plt.figure(figsize=(11.2,3.45))
    outer=fig.add_gridspec(1,3,wspace=.28)
    first=[fig.add_subplot(outer[0,i]) for i in range(2)]
    broken=outer[0,2].subgridspec(1,2,width_ratios=[1.4,1.8],wspace=.08)
    left=fig.add_subplot(broken[0,0]); right=fig.add_subplot(broken[0,1],sharey=left)
    for ax,family in zip(first,FAMILIES[:2]):
        draw_overall(ax,records,family,(-5.,-3.6)); ax.set_title(TITLES[family])
        ax.set_xlabel('SNR $E_s/N_0$ (dB)'); ax.legend(fontsize=7,loc='upper right')
    for ax,limits in ((left,(-5.,-3.6)),(right,(1.1,2.9))):
        draw_overall(ax,records,'exact',limits)
    left.set_title('Exact threshold',x=1.15)
    left.spines['right'].set_visible(False); right.spines['left'].set_visible(False)
    right.tick_params(axis='y',which='both',left=False,labelleft=False)
    left.set_xticks([-5,-4.5,-4]); right.set_xticks([1.5,2,2.5])
    left.set_xlabel('SNR $E_s/N_0$ (dB)',x=1.15)
    for ax,xpos in ((left,1),(right,0)):
        for ypos in (0,1):
            ax.plot([xpos-.025,xpos+.025],[ypos-.018,ypos+.018],
                    transform=ax.transAxes,color='k',clip_on=False,lw=.9)
    left.legend(fontsize=6,loc='lower left',bbox_to_anchor=(-.04,.08))
    conventional=series(records,'exact','conventional')
    positive=[r['snr_db'] for r in conventional if r['balanced_error']>0]
    zero_tail=[r['snr_db'] for r in conventional if r['balanced_error']==0 and
               (not positive or r['snr_db']>max(positive))]
    if zero_tail:
        right.text(.97,.035,f'No errors observed\nfrom {min(zero_tail):g} dB',
                   transform=right.transAxes,ha='right',va='bottom',fontsize=6,color=COLORS['conventional'])
    first[0].set_ylabel('Balanced task error probability')
    fig.subplots_adjust(bottom=.19,top=.88)
    save(fig,out,'noisy')

    fig,axes=plt.subplots(1,3,figsize=(11.2,3.45),layout='constrained')
    for ax,family in zip(axes,FAMILIES):
        draw_overall(ax,records,family); ax.set_title(TITLES[family])
        ax.set_xlabel('SNR $E_s/N_0$ (dB)'); ax.legend(fontsize=6)
    axes[0].set_ylabel('Balanced task error probability')
    save(fig,out,'noisy_full_range')

    fig,axes=plt.subplots(1,3,figsize=(11.2,3.45),layout='constrained')
    colors={'fn':'#1768ac','fp':'#df8b25','fer':'#666666'}
    for ax,family in zip(axes,FAMILIES):
        for scheme in ('bfc','conventional'):
            rows=series(records,family,scheme)
            if not rows: continue
            for metric in ('fn','fp','fer'):
                y=np.array([r[metric] for r in rows])
                if not np.any(y>0): continue
                ax.plot([r['snr_db'] for r in rows],np.where(y>0,y,np.nan),
                    color=colors[metric],ls='-' if scheme=='bfc' else '--',
                    marker='o' if metric!='fer' else None,markersize=2,
                    label=f'{scheme} {metric.upper()}')
        ax.set(yscale='log',ylim=(1e-7,1.1),title=TITLES[family],xlabel='SNR $E_s/N_0$ (dB)')
        ax.grid(True,alpha=.2); ax.legend(fontsize=6)
    axes[0].set_ylabel('Conditional FN / FP and frame error probability')
    save(fig,out,'noisy_diagnostics')


def plot_noiseless(table,out):
    fig,axes=plt.subplots(1,3,figsize=(11.2,3.45),layout='constrained')
    for ax,family in zip(axes,FAMILIES):
        rows=sorted((r for r in table if r['family']==family),key=lambda r:r['nt'])
        for metric,label,style in [('mean','Mean FP','o-'),('sample_max','Sample maximum','s-'),
                                   ('bound','Worst-case bound','--')]:
            ax.plot([r['nt'] for r in rows],[r[metric] for r in rows],style,markersize=3,label=label)
        ax.set(yscale='log',xlabel='$n_t$',title=TITLES[family]); ax.grid(True,alpha=.2)
        ax.set_xticks([r['nt'] for r in rows]); ax.legend(fontsize=7)
    axes[0].set_ylabel('Noiseless FP probability')
    save(fig,out,'noiseless')


def replot_from_tables(source,out):
    """Render existing complete CSV evidence into a fresh output directory."""
    out.mkdir(parents=True,exist_ok=True)
    records=[]
    for raw in csv.DictReader((source/'summary.csv').open()):
        row={k:(v if k in ('family','scheme') else float(v)) for k,v in raw.items()}
        if row['positive_trials']!=row['negative_trials']:
            raise ValueError('Balanced plotting requires equal class counts')
        row['balanced_error']=(row['fp_events']+row['fn_events'])/(row['positive_trials']+row['negative_trials'])
        row['noiseless_balanced_error']=.5*row['noiseless_fp']
        records.append(row)
    table=[{k:(v if k=='family' else float(v)) for k,v in raw.items()}
           for raw in csv.DictReader((source/'noiseless_summary.csv').open())]
    plot_noisy(records,out); plot_noiseless(table,out)
    (out/'README.txt').write_text('Reformatted existing production data; original frame counts and nt coverage.\n'
                                'Extended nt=42,44,46 and uniform 10000-frame figures follow after extension jobs complete.\n')
