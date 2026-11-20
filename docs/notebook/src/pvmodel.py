"""Single-diode PV model + minimal theme-aware SVG plotter.

All numbers come from the five-parameter single-diode equation:
    I = Iph - I0*(exp((V + I*Rs)/a) - 1) - (V + I*Rs)/Rsh ,  a = n*Ns*k*T/q
Parameters are extracted from a datasheet-style operating point set.
"""
import math
import numpy as np
from scipy.optimize import brentq, least_squares

Q = 1.602176634e-19
K = 1.380649e-23
T_REF = 298.15          # 25 degC
G_REF = 1000.0          # W/m^2
EG = 1.121              # eV, silicon band gap

# ---------------------------------------------------------------- datasheet
# Reference module: 60-cell monocrystalline, 265 W class
DS = dict(Ns=60, Voc=37.5, Isc=9.20, Vmp=31.0, Imp=8.55,
          aIsc=+0.0005 * 9.20,      # +0.05 %/degC  -> A/degC
          bVoc=-0.0030 * 37.5)      # -0.30 %/degC  -> V/degC


def _a(n, Ns, T):
    return n * Ns * K * T / Q


def extract(ds=DS, n=1.15):
    """Fit Iph, I0, Rs, Rsh so the model passes through the datasheet points."""
    Ns, Voc, Isc, Vmp, Imp = ds['Ns'], ds['Voc'], ds['Isc'], ds['Vmp'], ds['Imp']
    a = _a(n, Ns, T_REF)

    def resid(x):
        Iph, logI0, Rs, Rsh = x
        I0 = math.exp(logI0)
        e_sc = math.exp(min(Isc * Rs / a, 500))
        e_oc = math.exp(min(Voc / a, 500))
        e_mp = math.exp(min((Vmp + Imp * Rs) / a, 500))
        g = (I0 / a) * e_mp + 1.0 / Rsh
        return [
            (Iph - I0 * (e_sc - 1) - Isc * Rs / Rsh - Isc) / Isc,
            (Iph - I0 * (e_oc - 1) - Voc / Rsh) / Isc,
            (Iph - I0 * (e_mp - 1) - (Vmp + Imp * Rs) / Rsh - Imp) / Isc,
            (Imp - Vmp * g / (1 + Rs * g)) / Isc,
        ]

    r = least_squares(resid, [Isc * 1.005, math.log(1e-9), 0.30, 300.0],
                      bounds=([Isc, -34.0, 0.005, 20.0],
                              [Isc * 1.3, -12.0, 2.0, 20000.0]),
                      xtol=1e-14, ftol=1e-14, gtol=1e-14)
    x = r.x
    return dict(Iph=x[0], I0=math.exp(x[1]), Rs=x[2], Rsh=x[3], n=n, Ns=Ns,
                fit_cost=float(r.cost))


P = extract()


def params(G=G_REF, T=T_REF, p=None):
    """Scale the reference parameters to irradiance G and cell temperature T."""
    p = p or P
    a_isc = DS['aIsc']
    Iph = (G / G_REF) * (p['Iph'] + a_isc * (T - T_REF))
    I0 = p['I0'] * (T / T_REF) ** 3 * math.exp(
        (Q * EG / (p['n'] * K)) * (1.0 / T_REF - 1.0 / T))
    Rsh = p['Rsh'] * (G_REF / max(G, 1.0))
    return dict(Iph=Iph, I0=I0, Rs=p['Rs'], Rsh=Rsh, n=p['n'], Ns=p['Ns'], T=T)


def _res_I(I, V, pp):
    a = _a(pp['n'], pp['Ns'], pp['T'])
    return (pp['Iph'] - pp['I0'] * (math.exp((V + I * pp['Rs']) / a) - 1.0)
            - (V + I * pp['Rs']) / pp['Rsh'] - I)


def current(V, pp):
    """Terminal current at terminal voltage V (single module)."""
    lo, hi = -2.0, pp['Iph'] + 2.0
    if _res_I(lo, V, pp) * _res_I(hi, V, pp) > 0:
        return 0.0
    return brentq(_res_I, lo, hi, args=(V, pp), xtol=1e-12, rtol=8.9e-16)


def voc(pp):
    f = lambda V: current(V, pp)
    hi = 0.1
    while f(hi) > 0 and hi < 200:
        hi += 0.5
    return brentq(f, 0.0, hi, xtol=1e-9)


def voltage(I, pp, vmax=None):
    """Terminal voltage at terminal current I (inverse of current())."""
    vmax = vmax or voc(pp) + 0.5
    f = lambda V: current(V, pp) - I
    if f(0.0) < 0:
        return 0.0
    if f(vmax) > 0:
        return vmax
    return brentq(f, 0.0, vmax, xtol=1e-9)


def curve(G=G_REF, T=T_REF, npts=420, p=None):
    """Return V, I, P arrays from 0 V to Voc."""
    pp = params(G, T, p)
    Vo = voc(pp)
    V = np.linspace(0.0, Vo, npts)
    I = np.array([current(v, pp) for v in V])
    I = np.clip(I, 0.0, None)
    return V, I, V * I


def mpp(V, I):
    Pw = V * I
    j = int(np.argmax(Pw))
    return V[j], I[j], Pw[j]


# ------------------------------------------------- series string with bypass
VD = 0.7      # bypass diode forward drop


def string_curve(irradiances, T=T_REF, npts=1200):
    """I-V and P-V of series modules, one bypass diode per module."""
    pps = [params(g, T) for g in irradiances]
    vocs = [voc(pp) for pp in pps]
    iscs = [current(0.0, pp) for pp in pps]
    imax = max(iscs)
    I = np.linspace(1e-3, imax * 1.02, npts)
    V = np.zeros_like(I)
    for pp, vo, isc in zip(pps, vocs, iscs):
        seg = np.array([voltage(i, pp, vmax=vo + 0.5) if i < isc else -VD for i in I])
        V += seg
    keep = V > 0
    V, I = V[keep], I[keep]
    order = np.argsort(V)
    return V[order], I[order], (V * I)[order]


def local_peaks(V, Pw, minsep=1.5):
    out = []
    for j in range(2, len(Pw) - 2):
        if Pw[j] >= Pw[j - 1] and Pw[j] > Pw[j + 1]:
            out.append((V[j], Pw[j]))
    # thin out numerical duplicates
    thin = []
    for v, p_ in out:
        if not thin or v - thin[-1][0] > minsep:
            thin.append((v, p_))
        elif p_ > thin[-1][1]:
            thin[-1] = (v, p_)
    return thin


# ------------------------------------------------------------- SVG plotting
class Fig:
    """Minimal SVG axes. No colours are hard-coded: CSS classes carry them."""

    def __init__(self, w=760, h=430, ml=76, mr=86, mt=30, mb=58,
                 xlab='', ylab='', title=''):
        self.w, self.h = w, h
        self.ml, self.mr, self.mt, self.mb = ml, mr, mt, mb
        self.xlab, self.ylab, self.title = xlab, ylab, title
        self.body = []
        self.x0 = self.x1 = self.y0 = self.y1 = 0.0

    def limits(self, x0, x1, y0, y1):
        self.x0, self.x1, self.y0, self.y1 = x0, x1, y0, y1

    def X(self, x):
        return self.ml + (x - self.x0) / (self.x1 - self.x0) * (self.w - self.ml - self.mr)

    def Y(self, y):
        return self.h - self.mb - (y - self.y0) / (self.y1 - self.y0) * (self.h - self.mt - self.mb)

    # -- primitives
    def path(self, xs, ys, cls='s1', extra=''):
        d = 'M' + ' L'.join(f'{self.X(x):.2f},{self.Y(y):.2f}' for x, y in zip(xs, ys))
        self.body.append(f'<path class="{cls}" d="{d}" {extra}/>')

    def line(self, x1, y1, x2, y2, cls='ann'):
        self.body.append(f'<line class="{cls}" x1="{self.X(x1):.2f}" y1="{self.Y(y1):.2f}" '
                         f'x2="{self.X(x2):.2f}" y2="{self.Y(y2):.2f}"/>')

    def dot(self, x, y, cls='pt', r=4.6):
        self.body.append(f'<circle class="{cls}" cx="{self.X(x):.2f}" cy="{self.Y(y):.2f}" r="{r}"/>')

    def text(self, x, y, s, cls='lbl', anchor='start', dx=0, dy=0):
        self.body.append(f'<text class="{cls}" x="{self.X(x)+dx:.2f}" y="{self.Y(y)+dy:.2f}" '
                         f'text-anchor="{anchor}">{s}</text>')

    def textpx(self, px, py, s, cls='lbl', anchor='start'):
        self.body.append(f'<text class="{cls}" x="{px:.2f}" y="{py:.2f}" text-anchor="{anchor}">{s}</text>')

    def rect(self, x1, y1, x2, y2, cls='band'):
        X1, X2 = self.X(x1), self.X(x2)
        Y1, Y2 = self.Y(y1), self.Y(y2)
        self.body.append(f'<rect class="{cls}" x="{min(X1,X2):.2f}" y="{min(Y1,Y2):.2f}" '
                         f'width="{abs(X2-X1):.2f}" height="{abs(Y2-Y1):.2f}"/>')

    # -- axes
    def axes(self, xticks, yticks, xfmt='{:g}', yfmt='{:g}', grid=True):
        pre = []
        if grid:
            for t in xticks:
                pre.append(f'<line class="grid" x1="{self.X(t):.2f}" y1="{self.Y(self.y0):.2f}" '
                           f'x2="{self.X(t):.2f}" y2="{self.Y(self.y1):.2f}"/>')
            for t in yticks:
                pre.append(f'<line class="grid" x1="{self.X(self.x0):.2f}" y1="{self.Y(t):.2f}" '
                           f'x2="{self.X(self.x1):.2f}" y2="{self.Y(t):.2f}"/>')
        pre.append(f'<line class="ax" x1="{self.X(self.x0):.2f}" y1="{self.Y(self.y0):.2f}" '
                   f'x2="{self.X(self.x1):.2f}" y2="{self.Y(self.y0):.2f}"/>')
        pre.append(f'<line class="ax" x1="{self.X(self.x0):.2f}" y1="{self.Y(self.y0):.2f}" '
                   f'x2="{self.X(self.x0):.2f}" y2="{self.Y(self.y1):.2f}"/>')
        for t in xticks:
            pre.append(f'<text class="tick" x="{self.X(t):.2f}" y="{self.Y(self.y0)+20:.2f}" '
                       f'text-anchor="middle">{xfmt.format(t)}</text>')
        for t in yticks:
            pre.append(f'<text class="tick" x="{self.X(self.x0)-9:.2f}" y="{self.Y(t)+4:.2f}" '
                       f'text-anchor="end">{yfmt.format(t)}</text>')
        pre.append(f'<text class="axlab" x="{(self.ml+self.w-self.mr)/2:.2f}" '
                   f'y="{self.h-14:.2f}" text-anchor="middle">{self.xlab}</text>')
        pre.append(f'<text class="axlab" transform="translate(20,{(self.mt+self.h-self.mb)/2:.2f}) '
                   f'rotate(-90)" text-anchor="middle">{self.ylab}</text>')
        if self.title:
            pre.append(f'<text class="figtitle" x="{self.ml:.2f}" y="18" text-anchor="start">{self.title}</text>')
        self.body = pre + self.body

    def svg(self):
        return (f'<svg viewBox="0 0 {self.w} {self.h}" class="fig" '
                f'xmlns="http://www.w3.org/2000/svg" role="img">\n'
                + '\n'.join(self.body) + '\n</svg>')


def ticks(lo, hi, n=6):
    step = (hi - lo) / n
    mag = 10 ** math.floor(math.log10(step))
    for m in (1, 2, 2.5, 5, 10):
        if step <= m * mag:
            step = m * mag
            break
    t0 = math.ceil(lo / step) * step
    out, t = [], t0
    while t <= hi * 1.0001:
        out.append(round(t, 10))
        t += step
    return out
