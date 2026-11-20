"""Static 4x4 Emmvee E325P72 array model (numpy only), same values as pv4x4_config.m.

Cell: single diode, n = 1.0, Rs = 4.41 mOhm, no shunt. 24 cells per bypass group,
3 groups per panel, 4 panels per string, 4 strings in parallel.
Bypass diode 15SQ045: Vf 0.37 V, Ron 0.012 Ohm.
"""
import numpy as np

VT = 1.380649e-23 * 298.15 / 1.602176634e-19   # 25 degC, n = 1
ISC, VOC_CELL, RS = 9.11, 45.8 / 72, 0.0044
I0 = ISC / (np.exp(VOC_CELL / VT) - 1.0)
VF, RON = 0.37, 0.012
NGRP, NCELL_GRP = 3, 24


def group_v(I, G):
    """Voltage of one 24-cell bypass group at current I (array), irradiance G."""
    iph = ISC * G / 1000.0
    v = np.full_like(I, -np.inf)
    ok = I < iph
    v[ok] = NCELL_GRP * (VT * np.log((iph - I[ok]) / I0 + 1.0) - I[ok] * RS)
    return np.maximum(v, -VF - RON * I)


def string_iv(Gcol, npts=6000):
    """Gcol: 4 values (one per panel, all 3 groups equal) or 12 values (one per group)."""
    I = np.linspace(-20.0, ISC * 1.02, npts)  # negative: reverse current of a weak string near Voc (no blocking diode, as in Simulink)
    V = np.zeros_like(I)
    per = NGRP if len(Gcol) == 4 else 1
    for g in Gcol:
        V += per * group_v(I, g)
    return I, V          # V decreases as I increases


def array_curve(G, vgrid=None):
    """G: 4x4 (rows x strings). Returns V, I, P on a voltage grid."""
    G = np.asarray(G, float)
    if vgrid is None:
        vgrid = np.linspace(0.0, 190.0, 8001)
    Itot = np.zeros_like(vgrid)
    for c in range(G.shape[1]):
        I, V = string_iv(G[:, c])
        # invert: V(I) is decreasing -> interp on reversed arrays
        Is = np.interp(vgrid, V[::-1], I[::-1], left=I[-1], right=I[0])
        Itot += Is
    keep = Itot > 0
    last = np.argmax(~keep) if (~keep).any() else len(vgrid)
    V, Ia = vgrid[:last], Itot[:last]
    return V, Ia, V * Ia


def peaks(V, P, rel=0.002):
    j = np.where((P[1:-1] >= P[:-2]) & (P[1:-1] > P[2:]))[0] + 1
    out = []
    for k in j:
        if not out or V[k] - out[-1][0] > 3.0:
            out.append((V[k], P[k]))
        elif P[k] > out[-1][1]:
            out[-1] = (V[k], P[k])
    return out
