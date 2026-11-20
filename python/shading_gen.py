"""Random shading patterns for the 4 x 4 array.

The function gen() is copied unchanged from the preliminary study
(archive/2026-11-21_post_midreview/python/runrand.py), so that new test
runs can use the same three kinds of random shading without the archived
algorithms. The 1800 random cases of that study used gen() with
numpy.random.default_rng and the seeds in runrand.run().

Use with pvarray.array_curve(G) to get the I-V and P-V curve of a pattern.
"""
import numpy as np


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
