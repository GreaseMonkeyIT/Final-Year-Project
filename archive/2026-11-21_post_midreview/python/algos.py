"""Offline cross-check of M1-M4 and the BSP/bound idea on static P-V curves.

One probe = one applied operating point = one MPPT period (20 ms in MPPT_4x4.slx).
Converter: ideal averaged buck-boost into 10 Ohm, as MPPT_4x4.slx:
    Rpv = R * ((1-D)/D)^2.
Voltage-reference methods (M1, M2, M3) get an ideal voltage loop (one probe per set-point).
"""
import numpy as np

R_LOAD = 10.0
VOC_MOD, ISC_MOD, IMP_MOD = 45.8, 9.11, 8.68
NS, NP = 4, 4
VOC_ARR, ISC_ARR = NS * VOC_MOD, NP * ISC_MOD
D_LO, D_HI = 0.30, 0.78          # common duty search interval (V from ~0.15 Voc to ~Voc)
DSTEP = 0.005                     # P&O step of MPPT_4x4.slx


def rpv(D):
    return R_LOAD * ((1 - D) / D) ** 2


def duty_for(V, I):
    r = V / max(I, 1e-9)
    return np.sqrt(R_LOAD) / (np.sqrt(r) + np.sqrt(R_LOAD))


class Plant:
    def __init__(self, V, I, noise=0.0, rng=None):
        self.V, self.I = V, I
        self.P = V * I
        self.gmpp = self.P.max()
        self.noise, self.rng = noise, rng
        self.log = []                       # (stage, D, V, I, Ptrue, Vmeas, Imeas)

    def _meas(self, v, i):
        if self.noise:
            v *= 1 + self.noise * self.rng.standard_normal()
            i *= 1 + self.noise * self.rng.standard_normal()
        return v, i

    def at_duty(self, D, stage):
        D = float(np.clip(D, 0.05, 0.95))
        f = self.I - self.V / rpv(D)
        k = np.argmax(f < 0)
        if k == 0:
            v, i = self.V[-1], self.I[-1]
        else:
            t = f[k - 1] / (f[k - 1] - f[k])
            v = self.V[k - 1] + t * (self.V[k] - self.V[k - 1])
            i = np.interp(v, self.V, self.I)
        vm, im = self._meas(v, i)
        self.log.append((stage, D, v, i, v * i, vm, im))
        return vm, im, vm * im

    def at_volt(self, Vref, stage):
        v = float(np.clip(Vref, 0.5, self.V[-1] - 0.05))
        i = np.interp(v, self.V, self.I)
        D = duty_for(v, i)
        vm, im = self._meas(v, i)
        self.log.append((stage, D, v, i, v * i, vm, im))
        return vm, im, vm * im, D


# ------------------------------------------------------------------ local stage
def po_local(pl, D0, n=60, step=DSTEP):
    """Plain P&O on duty from D0 (same rule as mppt_controller.m)."""
    D, sgn = D0, +1
    _, _, Pold = pl.at_duty(D, 'local')
    for _ in range(n):
        D = D + sgn * step
        _, _, P = pl.at_duty(D, 'local')
        if P < Pold:
            sgn = -sgn
        Pold = P


def summarize(pl, n_tail=10):
    st = [r[0] for r in pl.log]
    n_glob = sum(s == 'global' for s in st)
    Ptrue = np.array([r[4] for r in pl.log])
    loc = [k for k, s in enumerate(st) if s == 'local']
    final = Ptrue[-n_tail:].mean() / pl.gmpp
    # probes until power stays >= 98 % of its final level
    target = 0.98 * Ptrue[-n_tail:].mean()
    above = Ptrue >= target
    k = len(above)
    while k > 0 and above[k - 1]:
        k -= 1
    n1 = 50                                   # 1 s at 20 ms per probe
    Pw = np.concatenate([Ptrue, np.full(max(0, n1 - len(Ptrue)), Ptrue[-1])])[:n1]
    return dict(glob=n_glob, settle=k + 1, final=final, eff1s=Pw.mean() / pl.gmpp)


# ------------------------------------------------------------------ baselines
def po_from_start(pl, D0=0.30):
    po_local(pl, D0, n=120)


# ------------------------------------------------------------------ M1 Zaki 2023
def m1_zaki(pl, r=0.8, vdiode=3 * 0.37, thr=40.0):
    """Eq. (10)-(13), sequential comparison of LMPP candidates, then local stage."""
    N = NS
    cand = [r * VOC_ARR * (N - i) / N - i * vdiode for i in range(N)]
    res = []
    v0, i0, p0, d0 = pl.at_volt(cand[0], 'global'); res.append((p0, d0))
    v1, i1, p1, d1 = pl.at_volt(cand[1], 'global'); res.append((p1, d1))
    irr0 = i0 * 1000 / (IMP_MOD * NP)
    irr1 = i1 * 1000 / (ISC_MOD * NP)
    if abs(irr0 - irr1) < thr:            # no shading: INC from i = 0
        po_local(pl, d0)
        return
    best = 0 if p0 >= p1 else 1
    if p1 > p0:                           # keep climbing while power rises
        for i in range(2, N):
            v, ii, p, d = pl.at_volt(cand[i], 'global'); res.append((p, d))
            if p < res[i - 1][0]:
                best = i - 1
                break
            best = i
    po_local(pl, res[best][1])


# ------------------------------------------------------------------ M2 MSMPPT (best case)
def m2_oracle(pl, width=0.08, lam=0.05):
    """Stage 1 given for free: [Va, Vb] = GMPP +- width/2 * Voc, clipped to the
    GMPP hill. This is the best case: in the paper this needs V and I of every
    module, temperature, and a trained ANN (Appendix A)."""
    V, P = pl.V, pl.P
    j = np.argmax(P)
    va, vb = V[j] - width / 2 * V[-1], V[j] + width / 2 * V[-1]
    D = 0.30
    for _ in range(40):                    # stage 2 confinement, d +- lambda
        v, i, p = pl.at_duty(D, 'global')
        if v > vb:
            D += lam
        elif v < va:
            D -= lam
        else:
            break
    po_local(pl, D)


# ------------------------------------------------------------------ M3 Kouchaki 2023
def m3_kouchaki(pl, thr=50.0, xi=None):
    """Shade test at 0.5 Voc and 0.8 Ns Voc, Ns irradiance probes at 0.8 n Voc,
    Ns corrected probes at n (0.8 + xi_n) Voc, best one, then local stage.
    xi=None: no correction (xi = 0). xi='paper': the paper's linear xi(G).
    xi='oracle': the corrected point is the
    true local peak nearest to 0.8 n Voc (the best that any xi(G) can do)."""
    v1, i1, p1, _ = pl.at_volt(0.5 * VOC_MOD, 'global')
    v2, i2, p2, d2 = pl.at_volt(0.8 * NS * VOC_MOD, 'global')
    G1, G2 = i1 / ISC_ARR * 1000, i2 / ISC_ARR * 1000
    if abs(G1 - G2) < thr:
        po_local(pl, d2)
        return
    Gn = {}
    for n in range(1, NS):                 # n = Ns is the V2 probe again
        _, i_n, _, _ = pl.at_volt(0.8 * n * VOC_MOD, 'global')
        Gn[n] = i_n / ISC_ARR * 1000
    Gn[NS] = G2
    best = (-1, None)
    for n in range(1, NS + 1):
        vn = 0.8 * n * VOC_MOD
        if xi == 'paper':                  # xi linear in G: 0.17 at 100 W/m2, 0 at 1000 W/m2
            x = float(np.clip(0.17 * (1000 - Gn[n]) / 900, 0, 0.17))
            vn = n * (0.8 + x) * VOC_MOD
        if xi == 'oracle':
            from pvarray import peaks
            pk = peaks(pl.V, pl.P)
            vn = min(pk, key=lambda t: abs(t[0] - vn))[0]
        v, i, p, d = pl.at_volt(vn, 'global')
        if p > best[0]:
            best = (p, d)
    po_local(pl, best[1])


# ------------------------------------------------------------------ M4 DIRECT (Nguyen & Low 2010)
class Iv:
    def __init__(self, lo, hi, c, v, i, p):
        self.lo, self.hi, self.c, self.v, self.i, self.p = lo, hi, c, v, i, p
        self.dead = False

    @property
    def w(self):
        return self.hi - self.lo


def _sample(pl, c, stage):
    v, i, p = pl.at_duty(c, stage)
    return v, i, p


def _trisect(pl, ivs, iv, stage, prune=None):
    w = iv.w / 3
    new = []
    for lo in (iv.lo, iv.lo + 2 * w):
        c = lo + w / 2
        if prune is not None and prune(ivs, c, iv):
            nv = Iv(lo, lo + w, c, np.nan, np.nan, -np.inf); nv.dead = True
        else:
            v, i, p = _sample(pl, c, stage)
            nv = Iv(lo, lo + w, c, v, i, p)
        new.append(nv)
    ivs.remove(iv)
    mid = Iv(iv.lo + w, iv.lo + 2 * w, iv.c, iv.v, iv.i, iv.p)
    ivs.extend([new[0], mid, new[1]])
    ivs.sort(key=lambda x: x.c)


def bound_prune(eps):
    """Idea: monotone I-V bound. The sampled neighbours (in duty) of a new centre c
    bracket its voltage: on that bracket P <= V(lower duty) * I(higher duty)."""
    def f(ivs, c, parent):
        live = [x for x in ivs if not x.dead and x.c != c and np.isfinite(x.p)]
        left = [x for x in live if x.c < c]
        right = [x for x in live if x.c > c]
        if not left or not right:
            return False
        a, b = max(left, key=lambda x: x.c), min(right, key=lambda x: x.c)
        ub = a.v * b.i
        best = max(x.p for x in live)
        return ub < best * (1 - eps)
    return f


def direct(pl, eps_prune=None, dcr=DSTEP, handover=None, refine=None, local=True, extra=True):
    """refine(pl, ivs), if given, runs after the local stage and returns the hand-over duty.
    local=False: no locally biased stage. extra=False: no two extra cycles after the
    neighbour test. Idea B refined (direct_certified_plus) uses both."""
    prune = None if eps_prune is None else bound_prune(eps_prune)
    w = D_HI - D_LO
    c = D_LO + w / 2
    v, i, p = _sample(pl, c, 'global')
    ivs = [Iv(D_LO, D_HI, c, v, i, p)]
    _trisect(pl, ivs, ivs[0], 'global')            # 3 samples: D2 (high V), D1, D3 (low V)
    s2, s1, s3 = ivs                                 # sorted by duty: low duty = high V
    psc = ((s3.i - s1.i) / s3.i >= 0.1) and ((s2.v - s1.v) / s2.v >= 0.2)
    if psc:
        # globally biased: divide best third, then the remaining larger POIs -> 9 samples
        for _ in range(3):
            big = max(x.w for x in ivs if not x.dead)
            cands = [x for x in ivs if abs(x.w - big) < 1e-12 and not x.dead]
            tgt = max(cands, key=lambda x: x.p)
            # paper's skip rules
            if tgt is s3 and tgt.v < VOC_ARR / 3:
                tgt.dead = True; continue
            if tgt is s2 and (tgt.i < ISC_ARR / 3 or tgt.v > 0.9 * VOC_ARR):
                tgt.dead = True; continue
            _trisect(pl, ivs, tgt, 'global', prune)
        live = sorted([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.c)
        order = sorted(range(len(live)), key=lambda k: -live[k].p)
        if extra and abs(order[0] - order[1]) != 1:  # two best not neighbours: two more cycles
            _trisect(pl, ivs, live[order[0]], 'global', prune)
            ivs2 = [x for x in ivs if not x.dead and np.isfinite(x.p)]
            big = max(x.w for x in ivs2)
            tgt = max([x for x in ivs2 if abs(x.w - big) < 1e-12], key=lambda x: x.p)
            _trisect(pl, ivs, tgt, 'global', prune)
    # locally biased: trisect the interval with the highest centre power
    while local:
        tgt = max([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.p)
        if tgt.w / 3 < dcr:
            break
        _trisect(pl, ivs, tgt, 'global', prune)
    best = max([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.p)
    d0 = best.c if refine is None else refine(pl, ivs)
    (handover or po_local)(pl, d0)


# ------------------------------------------------------------------ Idea: BSP + monotone bound (best-first branch and bound)
def bsp_bound(pl, eps=0.0, tol=DSTEP, d_lo=D_LO, d_hi=D_HI, n_init=3, delta=0.0):
    """Samples are points (not interval centres). A gap between two consecutive
    samples d1 < d2 (V1 > V2, I1 < I2) holds P <= V1 * I2. Always split the gap with
    the highest bound at its duty midpoint. Stop when no gap can beat the best
    sample by more than eps, or every open gap is narrower than tol.
    delta: bound on the relative error of each sensor (task T8). The test then uses
    the robust ceiling V1 (1 + delta) I2 (1 + delta) against P_best (1 - 2 delta)."""
    pts = []
    for d in np.linspace(d_lo, d_hi, n_init):
        v, i, p = pl.at_duty(d, 'global'); pts.append((d, v, i, p))
    while True:
        pts.sort()
        best = max(p for *_, p in pts)
        gaps = []
        for (d1, v1, i1, p1), (d2, v2, i2, p2) in zip(pts, pts[1:]):
            ub = v1 * i2 * (1 + delta) ** 2
            if ub > best * (1 - 2 * delta) * (1 + eps) and d2 - d1 > tol:
                gaps.append((ub, d1, d2))
        if not gaps:
            break
        ub, d1, d2 = max(gaps)
        dm = 0.5 * (d1 + d2)
        v, i, p = pl.at_duty(dm, 'global'); pts.append((dm, v, i, p))
    dbest = max(pts, key=lambda t: t[3])[0]
    po_local(pl, dbest)


def corner_duty(d1, v1, i1, d2, v2, i2, theta=0.1):
    """Duty in the gap (d1, d2) where the input resistance R = V / I equals V1 / I2.

    Only there can the operating point reach the corner (V1, I2) of the box that
    holds every point of the gap, so a point with a power near the ceiling V1 x I2
    can only be near this duty. At this duty the two new ceilings are equal.
    The ideal buck-boost has ln R = ln R_load + 2 x with x = ln((1 - d) / d), so
    the duty comes from a linear interpolation of the two measured ln R in x. No
    converter value is needed. A wrong map moves the probe, but the ceilings stay
    valid. The duty is kept at least theta x (d2 - d1) from each end of the gap."""
    w = d2 - d1
    if v1 <= 0 or v2 <= 0:                 # No resistance to interpolate
        return float(min(max(0.5 * (d1 + d2), d1 + theta * w), d2 - theta * w))
    x1, x2 = np.log((1 - d1) / d1), np.log((1 - d2) / d2)
    y1, y2 = np.log(v1 / max(i1, 1e-9)), np.log(v2 / max(i2, 1e-9))
    if abs(y1 - y2) < 1e-12:
        d = 0.5 * (d1 + d2)
    else:
        x = x1 + (np.log(v1 / max(i2, 1e-9)) - y1) * (x2 - x1) / (y2 - y1)
        d = 1.0 / (1.0 + np.exp(x))
    return float(min(max(d, d1 + theta * w), d2 - theta * w))


def _bound_refine(pl, pts, eps, tol, delta=0.0, split='mid', theta=0.1):
    """BSP + monotone I-V bound, continued from existing samples (d, v, i, p).
    delta: robust ceiling, as in bsp_bound.
    split: 'mid' splits a gap at its duty midpoint, 'corner' at corner_duty."""
    while True:
        pts.sort()
        best = max(p for *_, p in pts)
        k = (1 + delta) ** 2
        gaps = [(v1 * i2 * k, d1, d2, v1, i1, v2, i2)
                for (d1, v1, i1, p1), (d2, v2, i2, p2) in zip(pts, pts[1:])
                if v1 * i2 * k > best * (1 - 2 * delta) * (1 + eps) and d2 - d1 > tol]
        if not gaps:
            return max(pts, key=lambda t: t[3])[0]
        if split == 'corner':
            # The corner split gives two new gaps with equal ceilings, so ties
            # are common. Ceilings within a relative 1e-9 count as equal, and
            # the gap with the higher duty wins, as in gmppt_search.m.
            umax = max(g[0] for g in gaps)
            ub, d1, d2, v1, i1, v2, i2 = max((g for g in gaps if g[0] >= umax * (1 - 1e-9)),
                                             key=lambda g: g[1])
            dm = corner_duty(d1, v1, i1, d2, v2, i2, theta)
        else:
            ub, d1, d2, v1, i1, v2, i2 = max(gaps)
            dm = 0.5 * (d1 + d2)
        v, i, p = pl.at_duty(dm, 'global'); pts.append((dm, v, i, p))


def direct_certified(pl, eps=0.02, tol=2 * DSTEP, local_dcr=None, delta=0.0):
    """DIRECT search of the paper, then a bound check before the hand-over:
    any gap between samples whose bound V1*I2 beats the best sample is split.
    delta: robust ceiling, as in bsp_bound."""
    k0 = len(pl.log)
    direct(pl, dcr=local_dcr or DSTEP, handover=lambda *_: None)
    pts = []
    for r in pl.log[k0:]:                    # reuse the measured values
        pts.append((r[1], r[5], r[6], r[5] * r[6]))
    dbest = _bound_refine(pl, pts, eps, tol, delta)
    po_local(pl, dbest)


def direct_certified_plus(pl, eps=0.02, tol=2 * DSTEP, theta=0.1):
    """Idea B, refined (2026-11-08). Three changes from direct_certified:
    1. No two extra cycles after the neighbour test of DIRECT. That test is part
       of the hand-over rule of DIRECT, which the ceiling check replaces.
    2. No locally biased stage of DIRECT. The ceiling check refines the region
       of the best sample anyway, so that stage only adds probes.
    3. The ceiling check splits a gap at corner_duty, not at the duty midpoint.
    The stop test, and so the certificate, is the same as direct_certified."""
    k0 = len(pl.log)
    direct(pl, handover=lambda *_: None, local=False, extra=False)
    pts = [(r[1], r[5], r[6], r[5] * r[6]) for r in pl.log[k0:]]
    dbest = _bound_refine(pl, pts, eps, tol, split='corner', theta=theta)
    po_local(pl, dbest)


# ------------------------------------------------------------------ DIRECT as read from the paper
def direct_paper(pl, dcr=DSTEP / 2, psc_i=0.1, psc_v=0.2, handover=None, retest='held'):
    """DIRECT GMPPT as written in Nguyen and Low (2010, IEEE TIE 57(10)), on the
    common duty range [D_LO, D_HI]. Page numbers are of the journal.

    1. Sample the centre D1 of the range. Trisect it: D2 (low duty, high V) and
       D3 (high duty, low V). This is iteration 1.
    2. Shading test (19), (20), p. 3459: c19 = (I3 - I1) / I3 >= 0.1 and
       c20 = (V2 - V1) / V2 >= 0.2.
       - Both hold: shaded.
       - Neither holds: uniform. Go to step 6.
       - One holds (p. 3459, Fig. 5(a)): divide the third with the highest power
         (this is iteration 2). Re-test with the pair that the failed condition
         did not cover and the new sample between them: (D2, new, D1) if (19)
         failed, (D1, new, D3) if (20) failed. Both hold: shaded, and skip rule 3
         or 4 applies. Else uniform. If no new sample is between the pair,
         uniform. The paper gives the first case only. The second is "similar".
         retest='outer' is another reading, for a sensitivity check only: the
         triple (D2, best new sample, D3) for both cases. On our curves (20)
         fails alone in about half of the cases, so the reading matters.
    3. Global stage up to iteration 4 (p. 3461). Each iteration divides the
       interval with the highest centre power among the intervals of the
       largest width. Skip rules (p. 3461), on the thirds D2 and D3 only:
       1. V(D3) < Voc / 3: do not sample D3,3 (the low-voltage child).
       2. I(D2) < Isc / 3 or V(D2) > 0.9 Voc: do not sample D2,2 (the
          high-voltage child).
       3. (19) failed: do not divide D3. 4. (20) failed: do not divide D2.
       A skipped child has no sample and is never chosen. A skip of rule 3 or 4
       uses the iteration, so the stage takes fewer samples, as p. 3461 says.
       Rules 1 and 2 also apply when step 2 divides D2 or D3 (3 of 900 random
       cases). On our range, D2 is at D = 0.38, near Voc, where I < Isc / 3, so
       rule 2 holds on every curve and D2,2 is never sampled.
    4. If the two samples with the highest power are not neighbours in duty
       (p. 3461): iteration 5 divides the interval with the highest power,
       iteration 6 the best interval of the largest width. No new test.
    5. (No step: the paper has none here.)
    6. Local stage (p. 3462): divide the interval with the highest centre power.
       Stop after a division whose new sample spacing (width / 3) is at most
       dcr, Eq. (21). The paper asks for dcr below the P&O step. On the range
       0.48 any dcr in [0.0020, 0.0059) gives the same probes.
    7. Hand over at the best sample (the paper does not name the point).

    Values the paper does not give, and our choice: the range (common range of
    this study), dcr (DSTEP / 2), ties (lowest duty), Voc and Isc of the skip
    rules (array STC values), the restart threshold (common restart of all
    methods).
    A departure: after the search the paper runs P&O with the step dcr (p. 3462,
    Fig. 8). Here the common P&O of all methods follows, with the step DSTEP.
    The paper also asks for dcr below the P&O step, so its text is not
    consistent on this point. The search itself does not depend on it."""
    w = D_HI - D_LO
    c = D_LO + w / 2
    v, i, p = _sample(pl, c, 'global')
    ivs = [Iv(D_LO, D_HI, c, v, i, p)]
    _trisect(pl, ivs, ivs[0], 'global')
    s2, s1, s3 = ivs
    for x in ivs:
        x.whole_skip = False
    c19 = (s3.i - s1.i) / s3.i >= psc_i
    c20 = (s2.v - s1.v) / s2.v >= psc_v
    done = set()                       # thirds that a skip of rule 3 or 4 used up

    def skip_child(iv, cc):
        if iv is s3 and s3.v < VOC_ARR / 3 and cc > iv.c:
            return True                # rule 1: D3,3
        if iv is s2 and (s2.i < ISC_ARR / 3 or s2.v > 0.9 * VOC_ARR) and cc < iv.c:
            return True                # rule 2: D2,2
        return False

    def divide(iv):
        _trisect(pl, ivs, iv, 'global', lambda _ivs, cc, parent: skip_child(parent, cc))

    def best_of_largest():
        live = [x for x in ivs if np.isfinite(x.p) and id(x) not in done]
        big = max(x.w for x in live)
        return max([x for x in live if abs(x.w - big) < 1e-12], key=lambda x: x.p)

    it = 1
    shaded = c19 and c20
    if c19 != c20:
        tgt = max((s2, s1, s3), key=lambda x: x.p)
        hi_v, lo_v = (s2, s1) if not c19 else (s1, s3)
        old = {id(x) for x in ivs}
        divide(tgt)
        it = 2
        if retest == 'outer':
            hi_v, lo_v = s2, s3
            new = [x for x in ivs if np.isfinite(x.p) and id(x) not in old and x.c != tgt.c]
            inner = [max(new, key=lambda x: x.p)] if new else []
        else:
            inner = [x for x in ivs if np.isfinite(x.p) and hi_v.c < x.c < lo_v.c]
        if inner:
            m = inner[0]
            shaded = ((lo_v.i - m.i) / lo_v.i >= psc_i) and ((hi_v.v - m.v) / hi_v.v >= psc_v)
        if shaded:
            whole = s3 if not c19 else s2          # rule 3 or rule 4
            if whole in ivs:
                whole.whole_skip = True
    if shaded:
        while it < 4:
            it += 1
            tgt = best_of_largest()
            if getattr(tgt, 'whole_skip', False):
                done.add(id(tgt))
                continue
            divide(tgt)
        live = sorted([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.c)
        order = sorted(range(len(live)), key=lambda k: -live[k].p)
        if abs(order[0] - order[1]) != 1:
            divide(max([x for x in live if id(x) not in done], key=lambda x: x.p))
            divide(best_of_largest())
    while True:                                    # local stage
        tgt = max([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.p)
        wnew = tgt.w / 3
        _trisect(pl, ivs, tgt, 'global')
        if wnew <= dcr:
            break
    best = max([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.p)
    (handover or po_local)(pl, best.c)


# ------------------------------------------------------------------ PSO (Ishaque et al. 2012)
def lcg(s):
    """One step of a 32-bit linear congruential generator (Numerical Recipes
    constants). Returns the new state and a number in [0, 1). The controller
    (gmppt_search.m) uses the same generator, so a run with the same seed gives
    the same probes in Python and in MATLAB. All products are below 2^53, so
    double arithmetic is exact."""
    s = (1664525 * s + 1013904223) % 4294967296
    return s, s / 4294967296.0


def pso(pl, n=3, w=0.4, c1=1.2, c2=1.6, vstop=2 * DSTEP, itmax=20, seed=1, handover=None):
    """PSO on the duty, after Ishaque, Salam, Amjad and Mekhilef (2012, IEEE TPEL
    27(8), pp. 3627-3638). The original paper was not available. The values come
    from secondary sources: n = 3, w = 0.4, c1 = 1.2, c2 = 1.6, fixed start
    points (Magalhaes et al. 2026, Sustainability 18(11), Table 4). Check them
    against the paper.
    1. Particles start evenly spread over [D_LO, D_HI], both ends included,
       with zero velocity.
    2. One iteration: apply each particle in turn (one probe each). Then update
       each personal best, then the global best.
    3. v = w v + c1 r1 (pbest - x) + c2 r2 (gbest - x), r1 and r2 from lcg,
       drawn for each particle in turn (r1, then r2).
    4. Stop when every |v| < vstop, or after itmax iterations. Else
       x = clip(x + v, D_LO, D_HI) and go to 2.
    The start points, vstop and itmax are our choices. A sweep on the 900
    noise-free random cases (2026-11-08) chose the values that suit PSO best:
    start at the ends and the middle (95.6 % found and a worst case of 75.4 %,
    against 93.0 % and 74.3 % for the centres of three parts), vstop = 0.01
    (32 probes against 38 for 0.005, the same success). itmax = 20 cuts off 2
    of 900 runs (results_ideab_refined.md, section 3).
    5. Hand over at the global best. The paper holds this duty. Here the common
       P&O of all methods follows, so that only the search differs."""
    x = [D_LO + k * (D_HI - D_LO) / (n - 1) for k in range(n)]
    v = [0.0] * n
    pbx, pbp = list(x), [-np.inf] * n
    gx, gp = x[0], -np.inf
    s = seed
    for _ in range(itmax):
        for k in range(n):
            _, _, p = pl.at_duty(x[k], 'global')
            if p > pbp[k]:
                pbp[k], pbx[k] = p, x[k]
        for k in range(n):
            if pbp[k] > gp:
                gp, gx = pbp[k], pbx[k]
        for k in range(n):
            s, r1 = lcg(s)
            s, r2 = lcg(s)
            v[k] = w * v[k] + c1 * r1 * (pbx[k] - x[k]) + c2 * r2 * (gx - x[k])
        if max(abs(t) for t in v) < vstop:
            break
        x = [min(max(x[k] + v[k], D_LO), D_HI) for k in range(n)]
    (handover or po_local)(pl, gx)


# ------------------------------------------------------------------ Baselines for Ideas B and C (task T7)
VOCP = VOC_MOD / 3                  # Voc of one bypass group (24 cells), 15.3 V


def max_slope(curves, d_lo=D_LO, d_hi=D_HI, step=1e-4):
    """Largest |dP/dD| [W per unit duty] of the static curves on [d_lo, d_hi],
    with the ideal converter. curves: list of (V, I). Tunes the Lipschitz constant."""
    D = np.arange(d_lo, d_hi + step / 2, step)
    s = 0.0
    for V, I in curves:
        pl = Plant(V, I)
        P = np.array([pl.at_duty(d, 'tune')[2] for d in D])
        s = max(s, float(np.max(np.abs(np.diff(P))) / step))
    return s


def lipo(pl, k, eps=0.02, nmax=40, d_lo=D_LO, d_hi=D_HI, grid=1e-4):
    """Piyavskii-Shubert search on the duty, as LIPO (Li et al. 2019, IEEE Access).
    k is the Lipschitz constant [W per unit duty]. Sample both ends of the range,
    then always the argmax of the upper envelope F(D) = min_j (P_j + k |D - D_j|).
    Stop when max F < (1 + eps) P_best, or after nmax probes. F is evaluated on a
    duty grid of step grid. Then P&O from the best sample. If k is below the true
    slope, F is not an upper bound and the search can miss the GMPP."""
    Dg = np.arange(d_lo, d_hi + grid / 2, grid)
    pts = []
    for d in (d_lo, d_hi):
        _, _, p = pl.at_duty(d, 'global'); pts.append((d, p))
    while len(pts) < nmax:
        Ds = np.array([d for d, _ in pts]); Ps = np.array([p for _, p in pts])
        F = np.min(Ps[:, None] + k * np.abs(Dg[None, :] - Ds[:, None]), axis=0)
        j = int(np.argmax(F))
        if F[j] < (1 + eps) * Ps.max():
            break
        _, _, p = pl.at_duty(Dg[j], 'global'); pts.append((Dg[j], p))
    po_local(pl, max(pts, key=lambda t: t[1])[0])


def _lipschitz_refine(L, eps, nmax):
    """Stop rule of Khong et al. (2013, Automatica 49(7)) for DIRECT: an interval of
    width w and centre power p can hold at most p + L w / 2. While an interval
    has p + L w / 2 > (1 + eps) P_best, trisect the interval with the highest bound.
    The test covers every interval, also the ones that the skip rules of DIRECT
    marked dead, as the ceiling check of Idea B covers the full range.
    Stop after nmax search probes. Returns the best centre."""
    def f(pl, ivs):
        while True:
            live = [x for x in ivs if np.isfinite(x.p)]
            best = max(x.p for x in live)
            ub = [x.p + L * x.w / 2 for x in live]
            j = int(np.argmax(ub))
            n = sum(r[0] == 'global' for r in pl.log)
            if ub[j] <= (1 + eps) * best or n + 2 > nmax:
                break
            _trisect(pl, ivs, live[j], 'global')
        return max([x for x in ivs if np.isfinite(x.p)], key=lambda x: x.p).c
    return f


def direct_lipschitz(pl, L, eps=0.02, nmax=40):
    """DIRECT of the paper (all steps up to the hand-over), then the Lipschitz
    stop of Khong et al. (2013) in place of the ceiling check of Idea B."""
    direct(pl, refine=_lipschitz_refine(L, eps, nmax))


def boztepe_skip(pl, vgstep=VOCP, d0=D_LO):
    """Scan with skips on a voltage grid, as Boztepe et al. (2014, IEEE TIE),
    with an ideal voltage loop (one probe per voltage set-point).
    1. Measure the operating point Q at duty d0 (start-up): Pstore = P_Q.
    2. The window is [Pstore / Isc_STC, 0.9 Voc_STC]. Probe its lowest voltage.
    3. After probe k (set-point v_k, current I_k): Pstore = max(Pstore, P_k).
       The new lower limit is Vmin = Pstore / I_k: between v_k and Vmin the
       current is at most I_k, so P < Pstore. The next probe is the lowest grid
       voltage v_k + j vgstep (j >= 1) at or above Vmin.
    4. Stop when that voltage is above 0.9 Voc_STC. P&O from the best probe."""
    vmax = 0.9 * VOC_ARR
    _, _, pq = pl.at_duty(d0, 'global')
    pbest, dbest = pq, d0
    v = pq / ISC_ARR
    while v <= vmax:
        _, ik, pk, dk = pl.at_volt(v, 'global')
        if pk > pbest:
            pbest, dbest = pk, dk
        vmin = pbest / max(ik, 1e-9)
        j = max(1, int(np.ceil((vmin - v) / vgstep - 1e-9)))
        v = v + j * vgstep
    po_local(pl, dbest)
