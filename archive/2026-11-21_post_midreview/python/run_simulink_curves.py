"""Run the global searches of algos.py on the Simulink sweep curves.

Methods: DIRECT, Idea B, Idea C, DIRECT as in the paper, PSO (seed 1) and
Idea B refined (mppt.alg = 3 to 8).

The curves are the CSV files in simulink_curves/ (V, I, P of
results/pv4x4_sweeps.mat). The MATLAB port (gmppt_static_check.m) uses
the same curves, so the two logs can be compared probe by probe.

Output: simulink_curves_runs.json. For each method and pattern, the log
of every probe (stage, D, V, I, P) and the summary of algos.summarize.
Run time: a few seconds.
"""
import json
import numpy as np
import algos as A

PATS = ['P0', 'P1', 'P2', 'P3', 'R1', 'R2', 'R3', 'R4', 'R5']
METHODS = {
    'DIRECT': lambda pl: A.direct(pl),
    'Idea B': lambda pl: A.direct_certified(pl, eps=0.02, tol=0.01),
    'Idea C': lambda pl: A.bsp_bound(pl, eps=0.02, tol=0.01),
    'DIRECT paper': lambda pl: A.direct_paper(pl),
    'PSO': lambda pl: A.pso(pl, seed=1),
    'Idea B refined': lambda pl: A.direct_certified_plus(pl, eps=0.02, tol=0.01),
}

out = {}
print('Search probes / final % of the GMPP / hand-over duty\n')
print('| Method | ' + ' | '.join(PATS) + ' |')
print('|---' * (len(PATS) + 1) + '|')
for m, f in METHODS.items():
    out[m] = {}
    cells = []
    for k in PATS:
        d = np.loadtxt(f'simulink_curves/{k}.csv', delimiter=',')
        pl = A.Plant(d[:, 0], d[:, 1])
        f(pl)
        s = A.summarize(pl)
        log = [dict(stage=r[0], D=r[1], V=r[2], I=r[3], P=r[4]) for r in pl.log]
        n = s['glob']
        hand = log[n]['D']                  # first P&O probe = hand-over duty
        out[m][k] = dict(summary=s, handover=hand, gmpp=float(pl.gmpp), log=log)
        cells.append(f"{n} / {s['final'] * 100:.1f} / {hand:.4f}")
    print(f'| {m} | ' + ' | '.join(cells) + ' |')

json.dump(out, open('simulink_curves_runs.json', 'w'), indent=1)
print('\nWrote simulink_curves_runs.json')
