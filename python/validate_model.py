"""Compare the numpy array model (pvarray.py) with the Simulink sweeps of PV4x4_sweep.slx.

The CSV files in simulink_curves/ are V, I, P of results/pv4x4_sweeps.mat,
one file for each pattern of shading_patterns.m.
"""
import numpy as np
from pvarray import array_curve
from patterns import PATS

for k, G in PATS.items():
    V, I, P = array_curve(G)
    d = np.loadtxt(f'simulink_curves/{k}.csv', delimiter=',')
    Vs, Ps = d[:, 0], d[:, 2]
    err = np.max(np.abs(np.interp(Vs, V, P, right=0) - Ps)) / Ps.max() * 100
    print(f'{k}: GMPP model {P.max():6.0f} W, Simulink {Ps.max():6.0f} W, '
          f'largest difference {err:.2f} % of GMPP')
