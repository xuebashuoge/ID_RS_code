"""Publication and diagnostic plots; all probabilities come from saved counts."""
import numpy as np
import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

FAMILIES=('id','rank','exact')
TITLES={'id':'Identification','rank':'Rank','exact':'Exact threshold'}
COLORS={'bfc':'#1768ac','conventional':'#c04b26'}
FAMILY_COLORS={'id':'#0072B2','rank':'#D55E00','exact':'#009E73'}
FAMILY_LABELS={'id':'ID','rank':'Rank','exact':'Exact'}


def save(fig,out,name,*,dpi=600,tight=True):
    options={'bbox_inches':'tight'} if tight else {}
    fig.savefig(out/f'{name}.pdf',**options)
    fig.savefig(out/f'{name}.png',dpi=dpi,**options)
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


def _clean_combined_axis(ax):
    """Apply the compact publication styling used by the rate figure."""
    ax.grid(axis='y',which='major',color='0.88',linewidth=.55)
    ax.tick_params(axis='both',which='both',direction='out',length=3)
    ax.set_axisbelow(True)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)


def plot_combined(records,table,out):
    """Combine all three functions in noiseless and noisy channel panels.

    Function families are encoded by color throughout.  Panel (a) uses line
    style and marker fill for the three noiseless quantities.  Panel (b) uses
    line style and marker shape for the BFC, noiseless-BFC, and conventional
    results; its broken x axis keeps the two simulated waterfall regions at
    their actual SNR values without drawing a line across the omitted range.
    """
    fig=plt.figure(figsize=(3.5,1.92))
    outer=fig.add_gridspec(1,2,width_ratios=[1.,1.12],wspace=.37)
    noiseless_grid=outer[0,0].subgridspec(3,1,hspace=.10)
    noiseless_axes=[fig.add_subplot(noiseless_grid[i,0]) for i in range(3)]
    noisy_grid=outer[0,1].subgridspec(1,2,width_ratios=[1.35,1.],wspace=.09)
    bfc_ax=fig.add_subplot(noisy_grid[0,0])
    conventional_ax=fig.add_subplot(noisy_grid[0,1],sharey=bfc_ax)

    noiseless_styles={
        'mean':dict(ls='-',marker='o',mfc=None),
        'sample_max':dict(ls='--',marker='s',mfc='white'),
        'bound':dict(ls=':',marker=None,mfc=None),
    }
    noiseless_limits={'id':(6e-8,.9),'rank':(1e-6,.9),'exact':(3e-4,1.5)}
    noiseless_ticks={'id':(1e-6,1e-3),'rank':(1e-5,1e-2),'exact':(1e-3,1e-1)}
    for ax,family in zip(noiseless_axes,FAMILIES):
        rows=sorted((r for r in table if r['family']==family),key=lambda r:r['nt'])
        if not rows:
            raise ValueError(f'Missing noiseless rows for {family}')
        for metric,style in noiseless_styles.items():
            color=FAMILY_COLORS[family]
            ax.plot(
                [r['nt'] for r in rows],[r[metric] for r in rows],
                color=color,lw=.8,ls=style['ls'],marker=style['marker'],ms=1.9,
                markerfacecolor=(color if style['mfc'] is None else style['mfc']),
                markeredgecolor=color,markeredgewidth=.6,
            )
        ax.set(yscale='log',xlim=(27.3,46.7),ylim=noiseless_limits[family])
        ax.set_yticks(noiseless_ticks[family])
        ax.text(.025,.13,FAMILY_LABELS[family],transform=ax.transAxes,
                color=FAMILY_COLORS[family],fontsize=5.1,ha='left',va='bottom')
        ax.tick_params(axis='both',which='both',labelsize=4.5,pad=1.2)
        _clean_combined_axis(ax)
    for ax in noiseless_axes[:-1]:
        ax.tick_params(axis='x',which='both',bottom=False,labelbottom=False)
    noiseless_axes[-1].set_xticks([28,34,40,46])
    noiseless_axes[-1].set_xlabel(r'$n_t$',fontsize=6,labelpad=1)
    noiseless_axes[0].legend(handles=[
        Line2D([],[],color='.25',lw=.8,ls='-',marker='o',ms=2,label='Mean'),
        Line2D([],[],color='.25',lw=.8,ls='--',marker='s',ms=2,
               markerfacecolor='white',label='Max'),
        Line2D([],[],color='.25',lw=.8,ls=':',label='Bound'),
    ],loc='upper right',bbox_to_anchor=(.99,1.05),ncol=3,frameon=False,
       fontsize=4.4,handlelength=1.15,columnspacing=.55,handletextpad=.25,
       labelspacing=.05,borderaxespad=0)

    noisy_segments=((bfc_ax,(-5.05,-3.5)),(conventional_ax,(1.5,2.2)))
    for family in FAMILIES:
        rows=series(records,family,'bfc')
        if not rows:
            raise ValueError(f'Missing noisy BFC rows for {family}')
        x=np.array([r['snr_db'] for r in rows])
        y=np.array([r['balanced_error'] for r in rows])
        color=FAMILY_COLORS[family]
        # Every point uses the same paired noiseless source sample after
        # aggregation; select the largest validated frame count explicitly.
        reference=max(rows,key=lambda r:r['frames'])['noiseless_balanced_error']
        if reference<=0:
            raise ValueError(f'Non-positive noiseless BFC reference for {family}')
        for ax,limits in noisy_segments:
            mask=(x>=limits[0]) & (x<=limits[1])
            ax.plot(x[mask],np.where(y[mask]>0,y[mask],np.nan),color=color,
                    lw=.8,ls='-',marker='o',ms=1.9)
            ax.hlines(reference,*limits,color=color,lw=.75,ls=':')

        label_x={'id':1.78,'rank':1.76,'exact':1.74}[family]
        label_scale={'id':1.7,'rank':1.7,'exact':1.7}[family]
        conventional_ax.text(label_x,reference*label_scale,FAMILY_LABELS[family],
                             color=color,fontsize=4.8,ha='left',va='center')

    conventional=series(records,'exact','conventional')
    if not conventional:
        raise ValueError('Missing conventional exact-threshold rows')
    x=np.array([r['snr_db'] for r in conventional])
    y=np.array([r['balanced_error'] for r in conventional])
    for ax,limits in noisy_segments:
        mask=(x>=limits[0]) & (x<=limits[1])
        ax.plot(x[mask],np.where(y[mask]>0,y[mask],np.nan),
                color=FAMILY_COLORS['exact'],lw=.8,ls='--',
                marker='s',ms=1.9,markerfacecolor='white',
                markeredgecolor=FAMILY_COLORS['exact'],markeredgewidth=.6)

    for ax,limits in noisy_segments:
        ax.set(yscale='log',ylim=(1e-7,.75),xlim=limits)
        ax.tick_params(axis='both',which='both',labelsize=4.5,pad=1.2)
        _clean_combined_axis(ax)
    bfc_ax.set_xticks([-5.,-4.5,-4.])
    conventional_ax.set_xticks([1.5,2.,2.2])
    bfc_ax.set_xlabel('SNR',x=.84,fontsize=6,labelpad=1)

    bfc_ax.spines['right'].set_visible(False)
    conventional_ax.spines['left'].set_visible(False)
    conventional_ax.tick_params(axis='y',which='both',left=False,labelleft=False)
    for ax,xpos in ((bfc_ax,1),(conventional_ax,0)):
        ax.plot([xpos-.022,xpos+.022],[-.018,.018],
                transform=ax.transAxes,color='k',clip_on=False,lw=.8)

    bfc_ax.legend(handles=[
        Line2D([],[],color='.25',lw=.8,ls='-',marker='o',ms=2,label='BFC'),
        Line2D([],[],color='.25',lw=.75,ls=':',label='Noiseless'),
        Line2D([],[],color='.25',lw=.8,ls='--',marker='s',ms=2,
               markerfacecolor='white',label='Conv.'),
    ],loc='center right',bbox_to_anchor=(1.0,.83),ncol=1,frameon=False,
       fontsize=4.3,handlelength=1.15,columnspacing=.4,handletextpad=.25,
       labelspacing=.05,borderaxespad=0)

    fig.text(.245,.975,'(a) Noiseless channel',ha='center',va='top',fontsize=7.1)
    fig.text(.755,.975,'(b) Noisy channel',ha='center',va='top',fontsize=7.1)
    fig.text(.025,.48,'Error probability',rotation=90,ha='center',va='center',fontsize=6)
    fig.subplots_adjust(left=.105,right=.985,bottom=.16,top=.87)
    # Preserve the native 3.5 x 1.92 inch canvas and 300-dpi raster dimensions
    # used by rate_results rather than expanding the output with a tight crop.
    save(fig,out,'combined_results',dpi=300,tight=False)


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
    plot_noisy(records,out); plot_noiseless(table,out); plot_combined(records,table,out)
    (out/'README.txt').write_text('Reformatted existing production data; original frame counts and nt coverage.\n'
                                'Extended nt=42,44,46 and uniform 10000-frame figures follow after extension jobs complete.\n')
