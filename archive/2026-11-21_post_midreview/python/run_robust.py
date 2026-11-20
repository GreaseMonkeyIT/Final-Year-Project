"""Ideas B and C under sensor noise, and the trade-off of the two tolerances (task T8).

1. Robust ceiling. Each sensor has a relative error of at most delta. The gap
   test then compares V1 (1 + delta) x I2 (1 + delta) with P_best (1 - 2 delta).
   The random sets run with Gaussian noise of 0, 0.5, 1 and 2 % (standard
   deviation, on V and on I), with delta = 0 and with delta = 3 x the noise.
2. Tolerance sweep. eps in {0, 0.01, 0.02, 0.05}, tol in {0.005, 0.01, 0.02},
   no noise and delta = 0.

The three random sets of run_all.py (panel, edge, group, 300 patterns each, the
same seeds) are pooled: 900 cases. A miss is a final power below 98 % of the GMPP.
A search miss is a case where the hand-over duty is not on the global hill: P&O
with no noise, from the hand-over duty, ends below 98 % of the GMPP. The other
misses come from the noise in the P&O stage, not from the search.
Writes results_robust.md and results_robust.json. Run time: about 3 min.
"""
import json, sys
import numpy as np
import algos as A
import runrand as RR
from pvarray import array_curve

sys.stdout.reconfigure(encoding='utf-8')
lines = []


def emit(s=''):
    print(s)
    lines.append(s)


KINDS = ['panel', 'edge', 'group']
N = 300
SEED = 1                                      # As runrand.run
CURVES = []
for kind in KINDS:
    rng = np.random.default_rng(SEED)
    CURVES.extend(array_curve(RR.gen(kind, rng))[:2] for _ in range(N))


def pooled(f, noise):
    """Run f on the 900 pooled cases, with the noise sequence of runrand.run."""
    fi, g, e, fs = [], [], [], []
    for c, (V, I) in enumerate(CURVES):
        if c % N == 0:
            nr = np.random.default_rng(SEED + 7)
        pl = A.Plant(V, I, noise=noise, rng=nr)
        f(pl)
        s = A.summarize(pl)
        fi.append(s['final']); g.append(s['glob']); e.append(s['eff1s'])
        dh = next(r[1] for r in pl.log if r[0] == 'local')     # Hand-over duty
        p2 = A.Plant(V, I)
        A.po_local(p2, dh)
        fs.append(A.summarize(p2)['final'])
    fi, g, e, fs = map(np.array, (fi, g, e, fs))
    return dict(miss=float((fi < 0.98).mean() * 100), nmiss=int((fi < 0.98).sum()),
                nsearchmiss=int((fs < 0.98).sum()), worst=float(fi.min() * 100),
                glob=float(g.mean()), globmax=int(g.max()), eff1s=float(e.mean() * 100))


out = {'robust': {}, 'tolerance': {}}

emit('## Robust ceiling under sensor noise (900 random cases)\n')
emit('Noise: standard deviation of the relative error of V and of I. delta: the error bound in the ceiling test.\n')
emit('| Method | Noise | delta | Misses (< 98 %) | Search misses | Worst case | Mean search probes | Max probes | Power in first 1 s |')
emit('|---|---|---|---|---|---|---|---|---|')
for name, mk in [('Idea B', lambda d: (lambda pl: A.direct_certified(pl, eps=0.02, tol=0.01, delta=d))),
                 ('Idea C', lambda d: (lambda pl: A.bsp_bound(pl, eps=0.02, tol=0.01, delta=d)))]:
    for noise in [0.0, 0.005, 0.01, 0.02]:
        for dmul in ([0] if noise == 0 else [0, 3]):
            delta = dmul * noise
            x = pooled(mk(delta), noise)
            out['robust'][f'{name}, noise {noise}, delta {delta}'] = x
            emit(f"| {name} | {noise*100:.1f} % | {delta*100:.1f} % | {x['nmiss']} ({x['miss']:.1f} %) | "
                 f"{x['nsearchmiss']} | {x['worst']:.1f} % | {x['glob']:.1f} | {x['globmax']} | {x['eff1s']:.1f} % |")

emit('\n## Tolerance sweep, no noise (900 random cases)\n')
emit('Cells: mean search probes / misses (< 98 %) / worst case. With no noise, every miss is a search miss.\n')
TOLS = [0.005, 0.01, 0.02]
for name, mk in [('Idea B', lambda e, t: (lambda pl: A.direct_certified(pl, eps=e, tol=t))),
                 ('Idea C', lambda e, t: (lambda pl: A.bsp_bound(pl, eps=e, tol=t)))]:
    emit(f'\n### {name}\n')
    emit('| eps | ' + ' | '.join(f'tol = {t}' for t in TOLS) + ' |')
    emit('|---' * (len(TOLS) + 1) + '|')
    for eps in [0.0, 0.01, 0.02, 0.05]:
        cells = []
        for tol in TOLS:
            x = pooled(mk(eps, tol), 0.0)
            out['tolerance'][f'{name}, eps {eps}, tol {tol}'] = x
            cells.append(f"{x['glob']:.1f} / {x['nmiss']} / {x['worst']:.1f} %")
        emit(f'| {eps} | ' + ' | '.join(cells) + ' |')

json.dump(out, open('results_robust.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
with open('results_robust.md', 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(lines) + '\n')
