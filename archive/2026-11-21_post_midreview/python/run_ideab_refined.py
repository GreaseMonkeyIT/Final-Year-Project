"""Idea B refined: what each change gives, at an equal certificate (2026-11-08).

1. Ablation. Idea B, then one change at a time, then all three changes
   (direct_certified_plus): no extra cycles of DIRECT, no local stage of DIRECT,
   corner split. Also Idea C with the corner split.
2. Certificate. After the search, every gap between two neighbouring samples
   has the ceiling U = V1 x I2. "Cert" is max U / P_best over the gaps that do
   not touch the best sample: the search proves that no point outside the two
   gaps next to the best sample has more than Cert x P_best. It uses the true
   V and I of the samples, so it is the same with and without noise.
3. Equal certificate. A larger eps saves probes, but gives a weaker
   certificate. The sweep over eps shows the probes of Idea B and of Idea B
   refined at the same certificate. It also shows a variant that we rejected:
   the stop test on the "window" of a gap (the duties where the ceiling can
   still beat (1 + eps) P_best) in place of the full gap. It saves probes only
   because its certificate is weaker. At an equal certificate it is no better.
4. PSO settings. The start points and the stop value of the PSO baseline are
   our choices. The sweep shows the values that we tested.
5. DIRECT as in the paper: two readings of the re-test after one failed
   shading test (section 4 of the output).

The three random sets of run_all.py (panel, edge, group, 300 patterns each, the
same seeds) are pooled: 900 cases. Writes results_ideab_refined.md and .json.
Run time: about 5 min.
"""
import json
import math
import sys
import numpy as np
import algos as A
import runrand as RR
from pvarray import array_curve

sys.stdout.reconfigure(encoding='utf-8')
lines = []


def emit(s=''):
    print(s)
    lines.append(s)


CURVES = []
for kind in ['panel', 'edge', 'group']:
    rng = np.random.default_rng(1)                 # As runrand.run
    CURVES.extend(array_curve(RR.gen(kind, rng))[:2] for _ in range(300))


def cert(pl):
    """max U / P_best over the gaps that do not touch the best sample (true values)."""
    pts = sorted((r[1], r[2], r[3], r[4]) for r in pl.log if r[0] == 'global')
    pb = max(p for *_, p in pts)
    kb = max(range(len(pts)), key=lambda k: pts[k][3])
    u = [pts[k][1] * pts[k + 1][2] for k in range(len(pts) - 1) if k not in (kb - 1, kb)]
    return max(u) / pb if u else 1.0


def run(f, noise=0.0, curves=CURVES):
    nr = np.random.default_rng(8)
    fin, g, c = [], [], []
    for V, I in curves:
        pl = A.Plant(V, I, noise=noise, rng=nr)
        f(pl)
        s = A.summarize(pl)
        fin.append(s['final']); g.append(s['glob']); c.append(cert(pl))
    fin, g, c = np.array(fin), np.array(g), np.array(c)
    return dict(found=float((fin >= 0.98).mean() * 100), worst=float(fin.min() * 100),
                probes=float(g.mean()), pmax=int(g.max()),
                cert_mean=float(c.mean()), cert_p95=float(np.percentile(c, 95)), cert_max=float(c.max()))


# ------------------------------------------------------------------ variants
def b_variant(pl, eps=0.02, tol=0.01, extra=True, local=True, split='mid'):
    k0 = len(pl.log)
    A.direct(pl, handover=lambda *_: None, local=local, extra=extra)
    pts = [(r[1], r[5], r[6], r[5] * r[6]) for r in pl.log[k0:]]
    A.po_local(pl, A._bound_refine(pl, pts, eps, tol, split=split))


def c_variant(pl, eps=0.02, tol=0.01, split='mid'):
    pts = []
    for d in np.linspace(A.D_LO, A.D_HI, 3):
        v, i, p = pl.at_duty(d, 'global'); pts.append((d, v, i, p))
    A.po_local(pl, A._bound_refine(pl, pts, eps, tol, split=split))


def window_refine(pl, pts, eps, tol, theta=0.1):
    """Rejected variant: the tol test uses the window of a gap, the duties where
    R = V / I is in [(1 + eps) P_best / I2^2, V1^2 / ((1 + eps) P_best)]."""
    def d_of(y, d1, v1, i1, d2, v2, i2):
        x1, x2 = math.log((1 - d1) / d1), math.log((1 - d2) / d2)
        y1, y2 = math.log(v1 / max(i1, 1e-9)), math.log(v2 / i2)
        x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
        return 1 / (1 + math.exp(x))
    while True:
        pts.sort()
        pb = max(p for *_, p in pts)
        cand = []
        for (d1, v1, i1, p1), (d2, v2, i2, p2) in zip(pts, pts[1:]):
            U = v1 * i2
            if U <= (1 + eps) * pb:
                continue
            lo_R = max((1 + eps) * pb / i2 ** 2, v2 / i2)
            hi_R = min(v1 ** 2 / ((1 + eps) * pb), v1 / max(i1, 1e-9))
            da = max(d_of(math.log(hi_R), d1, v1, i1, d2, v2, i2), d1)
            db = min(d_of(math.log(lo_R), d1, v1, i1, d2, v2, i2), d2)
            if db - da > tol:
                cand.append((U, d1, v1, i1, d2, v2, i2))
        if not cand:
            return max(pts, key=lambda t: t[3])[0]
        U, d1, v1, i1, d2, v2, i2 = max(cand)
        dm = A.corner_duty(d1, v1, i1, d2, v2, i2, theta)
        v, i, p = pl.at_duty(dm, 'global'); pts.append((dm, v, i, p))


def b_window(pl, eps=0.02, tol=0.01):
    k0 = len(pl.log)
    A.direct(pl, handover=lambda *_: None, local=False, extra=False)
    pts = [(r[1], r[5], r[6], r[5] * r[6]) for r in pl.log[k0:]]
    A.po_local(pl, window_refine(pl, pts, eps, tol))


def pso_x0(pl, x0, vstop, itmax=20, seed=1):
    """A.pso with given start points (for the sweep of the start points)."""
    n = len(x0)
    x, v = list(x0), [0.0] * n
    pbx, pbp = list(x), [-np.inf] * n
    gx, gp, s = x[0], -np.inf, seed
    for _ in range(itmax):
        for k in range(n):
            _, _, p = pl.at_duty(x[k], 'global')
            if p > pbp[k]:
                pbp[k], pbx[k] = p, x[k]
        for k in range(n):
            if pbp[k] > gp:
                gp, gx = pbp[k], pbx[k]
        for k in range(n):
            s, r1 = A.lcg(s); s, r2 = A.lcg(s)
            v[k] = 0.4 * v[k] + 1.2 * r1 * (pbx[k] - x[k]) + 1.6 * r2 * (gx - x[k])
        if max(abs(t) for t in v) < vstop:
            break
        x = [min(max(x[k] + v[k], A.D_LO), A.D_HI) for k in range(n)]
    A.po_local(pl, gx)


def seed_of(pl):
    return 1 + int(round(pl.gmpp * 1000)) % 1000003     # As run_all.py


out = {}
HEAD = '| Variant | GMPP found | Worst | Mean probes | Max | Cert mean | Cert p95 | Cert max |'
SEP = '|---|---|---|---|---|---|---|---|'


def row(name, r):
    emit(f"| {name} | {r['found']:.1f} % | {r['worst']:.1f} % | {r['probes']:.2f} | {r['pmax']} | "
         f"{r['cert_mean']:.3f} | {r['cert_p95']:.3f} | {r['cert_max']:.3f} |")


# 1. Ablation
ABL = {
    'Idea B (eps 0.02, tol 0.01)': lambda pl: A.direct_certified(pl, eps=0.02, tol=0.01),
    'B, no extra cycles': lambda pl: b_variant(pl, extra=False),
    'B, no local stage': lambda pl: b_variant(pl, local=False),
    'B, corner split': lambda pl: b_variant(pl, split='corner'),
    'B, no extra cycles, no local stage': lambda pl: b_variant(pl, extra=False, local=False),
    'Idea B refined (all three)': lambda pl: A.direct_certified_plus(pl, eps=0.02, tol=0.01),
    'Idea C (eps 0.02, tol 0.01)': lambda pl: A.bsp_bound(pl, eps=0.02, tol=0.01),
    'Idea C, corner split': lambda pl: c_variant(pl, split='corner'),
}
for noise in [0.0, 0.005]:
    emit(f'## 1. Ablation, 900 cases, noise {noise * 100:.1f} %\n')
    emit(HEAD); emit(SEP)
    out[f'ablation_{noise}'] = {}
    for m, f in ABL.items():
        r = run(f, noise)
        out[f'ablation_{noise}'][m] = r
        row(m, r)
    emit()

# 2. Equal certificate
emit('## 2. Probes against the certificate, 900 cases, no noise\n')
emit(HEAD); emit(SEP)
out['eps_sweep'] = {}
for e in [0.02, 0.03, 0.04, 0.05, 0.06]:
    for name, f in [('Idea B', lambda pl, e=e: A.direct_certified(pl, eps=e, tol=0.01)),
                    ('Idea B refined', lambda pl, e=e: A.direct_certified_plus(pl, eps=e, tol=0.01))]:
        r = run(f)
        out['eps_sweep'][f'{name}, eps {e}'] = r
        row(f'{name}, eps {e}', r)
for e in [0.0, 0.01, 0.02]:
    r = run(lambda pl, e=e: b_window(pl, eps=e))
    out['eps_sweep'][f'Rejected: window test, eps {e}'] = r
    row(f'Rejected: window test, eps {e}', r)
emit()

# 3. PSO settings
emit('## 3. PSO settings, 900 cases, no noise\n')
emit('| Start points | vstop | GMPP found | Worst | Mean probes | Max |')
emit('|---|---|---|---|---|---|')
spread = [A.D_LO + (k + 0.5) * (A.D_HI - A.D_LO) / 3 for k in range(3)]
ends = [A.D_LO, 0.5 * (A.D_LO + A.D_HI), A.D_HI]
out['pso'] = {}
for nm, x0 in [('centres of 3 parts', spread), ('ends and middle', ends)]:
    for vs in [0.005, 0.01, 0.02, 0.04]:
        r = run(lambda pl, x0=x0, vs=vs: pso_x0(pl, x0, vs, seed=seed_of(pl)))
        out['pso'][f'{nm}, vstop {vs}'] = r
        emit(f"| {nm} | {vs} | {r['found']:.1f} % | {r['worst']:.1f} % | {r['probes']:.1f} | {r['pmax']} |")
emit('\nSeed spread of the chosen PSO (ends and middle, vstop 0.01): three seed sets.\n')
emit('| Seed set | GMPP found | Worst | Mean probes |')
emit('|---|---|---|---|')
for base in [0, 1000, 2000]:
    r = run(lambda pl, b=base: A.pso(pl, seed=seed_of(pl) + b))
    out['pso'][f'seed set {base}'] = r
    emit(f"| +{base} | {r['found']:.1f} % | {r['worst']:.1f} % | {r['probes']:.1f} |")

# 4. Reading of the paper DIRECT
emit()
emit('## 4. DIRECT as in the paper: two readings of the re-test, 900 cases')
emit()
emit('When only one shading test holds, the paper gives the re-test for a failed (19) only.')
emit('"held": the pair of the test that held, with the new sample between them (the default).')
emit('"outer": the triple (D2, best new sample, D3) in both cases.')
emit()
emit(HEAD); emit(SEP)
out['direct_paper_reading'] = {}
for noise in [0.0, 0.005]:
    for rd in ['held', 'outer']:
        r = run(lambda pl, rd=rd: A.direct_paper(pl, retest=rd), noise)
        out['direct_paper_reading'][f'{rd}, noise {noise}'] = r
        row(f'{rd}, noise {noise * 100:.1f} %', r)

json.dump(out, open('results_ideab_refined.json', 'w', encoding='utf-8'), indent=1)
with open('results_ideab_refined.md', 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(lines) + '\n')
