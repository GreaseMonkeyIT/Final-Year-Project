"""Random shading patterns for the 4x4 array, and the runner used by run_all.py."""
import numpy as np
from pvarray import array_curve
import algos as A

METHODS = {}          # run_all.py fills this


def gen(kind, rng):
    """panel: each panel shaded with p = 0.4, 100-900 W/m2.
    edge:  a shadow edge rises from the bottom of each string. It is not aligned
           to the panels, so one bypass group of a panel can be shaded alone.
    group: each bypass group shaded on its own with p = 0.3 (stress case)."""
    if kind == 'panel':
        G = np.where(rng.random((4, 4)) < 0.4, rng.uniform(100, 900, (4, 4)), 1000.0)
    elif kind == 'edge':
        G = np.full((12, 4), 1000.0)
        for c in range(4):
            k = rng.integers(0, 12)                  # shaded groups in this string
            lvl = rng.uniform(100, 700)
            G[12 - k:, c] = lvl
            if k < 12 and rng.random() < 0.5:        # one group in the penumbra
                G[12 - k - 1, c] = rng.uniform(lvl, 1000)
    else:
        G = np.where(rng.random((12, 4)) < 0.3, rng.uniform(100, 900, (12, 4)), 1000.0)
    return G


def run(kind, n, noise, seed=1, methods=None):
    methods = methods or METHODS
    rng = np.random.default_rng(seed)
    cur = []
    for _ in range(n):
        V, I, P = array_curve(gen(kind, rng))
        cur.append((V, I))
    out = {}
    for name, f in methods.items():
        nr = np.random.default_rng(seed + 7)
        rs = []
        for V, I in cur:
            pl = A.Plant(V, I, noise=noise, rng=nr)
            f(pl)
            rs.append(A.summarize(pl))
        fi = np.array([r['final'] for r in rs])
        g = np.array([r['glob'] for r in rs])
        e = np.array([r['eff1s'] for r in rs])
        out[name] = dict(succ=float((fi >= 0.98).mean() * 100), meanfinal=float(fi.mean() * 100),
                         worst=float(fi.min() * 100), glob=float(g.mean()), globmax=int(g.max()),
                         eff1s=float(e.mean() * 100))
    return out
