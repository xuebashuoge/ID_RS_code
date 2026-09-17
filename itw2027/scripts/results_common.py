"""Shared configuration and output helpers for the ITW result builders."""
from pathlib import Path
import csv
import hashlib
import os
import re

os.environ.setdefault('MPLCONFIGDIR', '/tmp/itw2027-matplotlib')

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

from rate_model import FAMILIES


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path(os.environ.get('ITW_EVIDENCE_ROOT', ROOT/'results/evidence'))
OUT = Path(os.environ.get('ITW_OUTPUT_ROOT', ROOT/'results/processed'))
COLORS = dict(zip(FAMILIES, ['#0072B2', '#D55E00', '#009E73']))
BOUND_STYLES = {
    'id': (0, (4, 4)),
    'rank': (3, (4, 4)),
    'exact-threshold': (0, (4, 4)),
}
LABELS = {
    'id': 'ID',
    'rank': 'Rank (20)',
    'exact-threshold': r'Exact threshold ($\beta=2$)',
}

plt.rcParams.update({
    'font.size': 8,
    'axes.labelsize': 8.5,
    'legend.fontsize': 8,
    'pdf.fonttype': 42,
    'ps.fonttype': 42,
    'axes.spines.top': False,
    'axes.spines.right': False,
    'lines.linewidth': 1.35,
})


def csv_write(name, rows):
    if not rows:
        raise ValueError(f'Empty output {name}')
    path = OUT/'tables'/name
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


def savefig(fig, name):
    directory = OUT/'figures'
    directory.mkdir(parents=True, exist_ok=True)
    save_options = {'bbox_inches': 'tight', 'pad_inches': .01}
    fig.savefig(directory/(name+'.pdf'), **save_options)
    fig.savefig(directory/(name+'.png'), dpi=300, **save_options)
    plt.close(fig)


def legend_line(label, **kwargs):
    return Line2D([], [], label=label, **kwargs)


def clean_axis(ax):
    ax.grid(axis='y', which='major', color='0.88', linewidth=.55)
    ax.tick_params(axis='both', which='both', direction='out', length=3)
    ax.set_axisbelow(True)


def provenance():
    rows = []
    for path in sorted((ROOT/'results/source').rglob('*')):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT/'results/source')
        base = ('/home/yangshuo/Git/ID_RS_code/conference_results/raw/'
                if relative.parts[0] == 'noiseless'
                else '/home/yangshuo/Downloads/ID_RS_code/results/noisy_channel_confirmatory_bp/')
        if relative.parts[:2] == ('noisy', 'threshold_nt40'):
            base = '/home/yangshuo/Git/itw2027_nt40_20260913/itw2027/results/source/noisy/'
        if relative.parts[0] not in ('noisy', 'noiseless'):
            continue
        rows.append(dict(
            local=str(path.relative_to(ROOT)),
            remote=base+str(Path(*relative.parts[1:])),
            bytes=path.stat().st_size,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            reuse='source_bank_copy_on_server' if 'source_banks' in path.parts else 'completed_evidence',
        ))
    if rows:
        csv_write('reuse_manifest.csv', rows)

    rows = []
    for path in sorted(EVIDENCE.rglob('*.mat')):
        rows.append(dict(
            file=str(path.relative_to(ROOT)),
            bytes=path.stat().st_size,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        ))
    csv_write('evidence_manifest.csv', rows)


def resource_logs():
    path = ROOT/'results/server_resource_logs.txt'
    rows = []
    for block in re.split(r'(?=^/home/)', path.read_text(), flags=re.M):
        if not block.strip():
            continue
        name = block.splitlines()[0]
        memory = re.search(r'\[(\d+)MB of', block)
        timing = re.search(r'Wall-clock time\s*:\s*([\d:-]+) /', block)
        cpus = re.search(r'Allocated CPUs\s*:\s*(\d+)', block)
        if not memory or not timing or not cpus:
            continue
        elapsed = timing[1]
        days = 0
        if '-' in elapsed:
            days, elapsed = elapsed.split('-')
        hours, minutes, seconds = map(int, elapsed.split(':'))
        kind = ('noisy_bank' if '/bp_bank_' in name else
                'noisy_point' if '/bp_conf_' in name else
                'adversarial' if 'adversarial' in name else 'noiseless')
        rows.append(dict(
            log=name,
            kind=kind,
            wall_hours=int(days)*24+hours+minutes/60+seconds/3600,
            memory_mb=int(memory[1]),
            cpus=int(cpus[1]),
        ))
    csv_write('server_resource_usage.csv', rows)
