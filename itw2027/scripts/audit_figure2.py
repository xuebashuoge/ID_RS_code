"""Frame-count audit: exact saved counts, including hidden isolated points."""
from pathlib import Path
import csv,json,math
import numpy as np
from scipy.io import loadmat
from scipy.stats import beta
root=Path(__file__).resolve().parents[1]
rows=[];events=[]
for p in sorted((root/'results/evidence/noisy').rglob('result*.mat')):
 r=loadmat(p,simplify_cells=True)['result'];pf=r['per_frame'];s=r['scenario'];N=r['frames']
 bad=np.asarray(pf['ldpc_error'],bool); fn=np.asarray(pf['coded_false_negative']);k=int(sum(bad))
 kind=p.relative_to(root/'results/evidence/noisy').parts[0]
 if kind not in ('waterfall','rate_pareto','threshold_nt40'):continue
 rows.append(dict(experiment=kind,family=r['bank_metadata']['func_type'],n_t=s['n'],snr_db=s['ebno_db'],
  frames=N,failed_frames=k,fn_count=int(sum(fn)),failed_frames_without_fn=int(sum(bad&(fn==0))),
  fer=k/N,fer_lower95=0 if k==0 else beta.ppf(.025,k,N-k+1),
  fer_upper95=1 if k==N else beta.ppf(.975,k+1,N-k),
  source=str(p.relative_to(root))))
 for i in np.flatnonzero(bad):
  events.append(dict(experiment=kind,family=r['bank_metadata']['func_type'],n_t=s['n'],snr_db=s['ebno_db'],
   frame=int(i+1),false_negatives=int(fn[i]),false_positives=int(pf['coded_false_positive'][i]),
   parity_failure=int(pf['parity_failure'][i])))
for name,data in [('figure2_frame_audit.csv',rows),('failed_frame_events.csv',events)]:
 with (root/'results/processed/tables'/name).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n');w.writeheader();w.writerows(data)
replacement=[r for r in rows if r['experiment']=='threshold_nt40']
if len(replacement)==22:
 selected=[r for r in rows if r['experiment']=='waterfall' and r['family']!='exact-threshold']+replacement
 comparison=[]
 for snr in sorted({round(r['snr_db'],6) for r in selected}):
  row={'snr_db':snr,'frames_per_function':2500}
  for family in ['id','rank','exact-threshold']:
   matches=[r for r in selected if r['family']==family and round(r['snr_db'],6)==snr]
   assert len(matches)==1 and matches[0]['n_t']==40
   for field in ['failed_frames','fn_count','fer']:
    row[family+'_'+field]=matches[0][field]
  comparison.append(row)
 with (root/'results/processed/tables/matched_nt40_comparison.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(comparison[0]),lineterminator='\n');w.writeheader();w.writerows(comparison)
print('one-sided zero-event upper95:',1-.05**(1/2500))
for p in [.001,.0004,.0001]:print('true FER',p,'P(0 failures in 2500)',(1-p)**2500,'frames for 100 expected failures',100/p)
