"""Final cross-check tables. Writes results_all.md and results_all.json, and prints the tables."""
import json, sys, numpy as np
import algos as A
from pvarray import array_curve
from patterns import PATS
import runrand as RR

sys.stdout.reconfigure(encoding='utf-8')     # The method names have Greek letters (Windows console)
lines = []


def emit(s=''):
    print(s)
    lines.append(s)


curves = {k: array_curve(G) for k, G in PATS.items()}
# Lipschitz constant of the baselines (task T7): 1.2 x the largest |dP/dD| of the nine patterns.
K_LIP = 1.2 * A.max_slope([(V, I) for V, I, P in curves.values()])

def pso_seed(pl):
    """Seed of the PSO random numbers, fixed by the curve, so every run repeats."""
    return 1 + int(round(pl.gmpp * 1000)) % 1000003


METHODS = {
 'P&O, start D = 0.30':               lambda pl: A.po_from_start(pl),
 'M1 Zaki 2023 (r = 0.8)':            lambda pl: A.m1_zaki(pl, r=0.8),
 'M2 Alombah 2025, ideal [Va,Vb], λd 0.05': lambda pl: A.m2_oracle(pl, lam=0.05),
 'M2 Alombah 2025, ideal [Va,Vb], λd 0.01': lambda pl: A.m2_oracle(pl, lam=0.01),
 'M3 Kouchaki 2023 (paper ξ(G))':     lambda pl: A.m3_kouchaki(pl, xi='paper'),
 'M4 DIRECT, Nguyen & Low 2010':      lambda pl: A.direct(pl),
 'Idea A: DIRECT + bound pruning':    lambda pl: A.direct(pl, eps_prune=0.0),
 'Idea B: DIRECT + bound check':      lambda pl: A.direct_certified(pl, eps=0.02, tol=0.01),
 'Idea C: BSP + bound (best-first)':  lambda pl: A.bsp_bound(pl, eps=0.02, tol=0.01),
 'LIPO, Li 2019 (k tuned)':           lambda pl: A.lipo(pl, K_LIP, eps=0.02),
 'LIPO, Li 2019 (k halved)':          lambda pl: A.lipo(pl, K_LIP / 2, eps=0.02),
 'DIRECT + Lipschitz stop, Khong 2013': lambda pl: A.direct_lipschitz(pl, K_LIP, eps=0.02),
 'Skip sweep, Boztepe 2014 (0.5 VocP)': lambda pl: A.boztepe_skip(pl, 0.5 * A.VOCP),
 'Skip sweep, Boztepe 2014 (1.0 VocP)': lambda pl: A.boztepe_skip(pl, 1.0 * A.VOCP),
 # Added 2026-11-08: the two baselines for Idea B, and Idea B refined.
 'DIRECT as in the paper, Nguyen & Low 2010': lambda pl: A.direct_paper(pl),
 'PSO, Ishaque 2012 (3 particles)':   lambda pl: A.pso(pl, seed=pso_seed(pl)),
 'PSO, Ishaque 2012 (5 particles)':   lambda pl: A.pso(pl, n=5, seed=pso_seed(pl)),
 'Idea B refined':                    lambda pl: A.direct_certified_plus(pl, eps=0.02, tol=0.01),
}
out = {'k_lipschitz': K_LIP, 'nine': {}, 'random': {}}
emit('## Nine project patterns, no noise. Cells: search probes / final % of GMPP\n')
emit(f'Lipschitz constant of LIPO and of the Khong stop: k = {K_LIP:.0f} W per unit duty '
     f'(1.2 x the largest |dP/dD| of the nine patterns).\n')
emit('| Method | ' + ' | '.join(curves) + ' |'); emit('|---' * (len(curves)+1) + '|')
for m, f in METHODS.items():
    cells = []; out['nine'][m] = {}
    for k, (V, I, P) in curves.items():
        pl = A.Plant(V, I); f(pl); s = A.summarize(pl)
        out['nine'][m][k] = s
        cells.append(f"{s['glob']} / {s['final']*100:.1f}")
    emit(f'| {m} | ' + ' | '.join(cells) + ' |')
RR.METHODS.update(METHODS)
for kind in ['panel', 'edge', 'group']:
    for noise in [0.0, 0.005]:
        key = f'{kind}, noise {noise*100:.1f} %'
        out['random'][key] = r = RR.run(kind, 300, noise)
        emit(f'\n## {key} (300 patterns)\n')
        emit('| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |')
        emit('|---|---|---|---|---|---|')
        for m, x in r.items():
            emit(f"| {m} | {x['succ']:.1f} % | {x['worst']:.1f} % | {x['glob']:.1f} | {x['globmax']} | {x['eff1s']:.1f} % |")
json.dump(out, open('results_all.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
with open('results_all.md', 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(lines) + '\n')
