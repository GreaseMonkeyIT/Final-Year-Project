"""Generate every computed figure in the notebook as a standalone SVG."""
import math, os
import numpy as np
from scipy.optimize import brentq
import pvmodel as m
from pvmodel import Fig, ticks

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'charts')
os.makedirs(OUT, exist_ok=True)
NS = m.DS['Ns']


def save(name, fig):
    with open(os.path.join(OUT, name + '.svg'), 'w') as f:
        f.write(fig.svg())
    print('  ', name)


def legend(fig, items, x=None, y=44, dy=22):
    x = x if x is not None else fig.w - fig.mr + 8
    for i, (lab, cls) in enumerate(items):
        yy = y + i * dy
        fig.body.append(f'<line class="{cls}" x1="{x}" y1="{yy-4}" x2="{x+18}" y2="{yy-4}"/>')
        fig.body.append(f'<text class="leg" x="{x+24}" y="{yy}">{lab}</text>')


# ------------------------------------------------------------------ 1. cell
def f_cell():
    V, I, Pw = m.curve()
    v = V / NS
    Vm, Im, Pm = m.mpp(V, I)
    vm = Vm / NS
    f = Fig(mr=110, xlab='Cell voltage  V  (V)', ylab='Cell current  I  (A)',
            title='Figure 2.3 &#8212; I-V characteristic of one silicon cell (1000 W/m&#178;, 25 &#176;C)')
    f.limits(0, 0.68, 0, 10.2)
    f.rect(0, 0, vm, Im, 'band')
    f.path(v, I, 's1')
    f.dot(0, I[0]); f.dot(v[-1], 0); f.dot(vm, Im, 'ptmpp', 6)
    f.text(0, I[0], 'I&#8347;&#8344;', dx=10, dy=-10, cls='lblb')
    f.text(v[-1], 0, 'V&#8338;&#8336;', dx=-6, dy=-12, anchor='end', cls='lblb')
    f.text(vm, Im, 'maximum power point', dx=12, dy=-12, cls='lblb')
    f.text(vm / 2, Im / 2, 'P&#8344;&#8336;&#8339;', anchor='middle', cls='lblbig')
    f.line(vm, 0, vm, Im, 'dash'); f.line(0, Im, vm, Im, 'dash')
    f.text(vm, 0, f'V&#8344;&#8344; = {vm:.3f} V', dx=8, dy=-8, cls='lbls')
    f.text(0, Im, f'I&#8344;&#8344; = {Im:.2f} A', dx=8, dy=16, cls='lbls')
    f.axes(ticks(0, 0.68, 6), [0, 2, 4, 6, 8, 10], xfmt='{:.1f}')
    f.textpx(f.w - f.mr + 8, 64, 'fill factor', cls='leg')
    f.textpx(f.w - f.mr + 8, 86, f'{Pm/(V[-1]*I[0]):.3f}', cls='legbig')
    save('cell_iv', f)


# ------------------------------------------------- 2/3. irradiance families
GS = [1000, 800, 600, 400, 200]


def f_irr():
    f = Fig(mr=132, xlab='Module voltage  (V)', ylab='Module current  (A)',
            title='Figure 3.1 &#8212; I-V against irradiance (25 &#176;C). The current scales; the knee barely moves.')
    f.limits(0, 40, 0, 10)
    for i, g in enumerate(GS):
        V, I, _ = m.curve(G=g)
        f.path(V, I, f's{i+1}')
        Vm, Im, _ = m.mpp(V, I)
        f.dot(Vm, Im, 'ptmpp', 4)
    f.axes(ticks(0, 40, 5), [0, 2, 4, 6, 8, 10])
    legend(f, [(f'{g} W/m&#178;', f's{i+1}') for i, g in enumerate(GS)])
    save('irradiance_iv', f)

    g2 = Fig(mr=132, xlab='Module voltage  (V)', ylab='Module power  (W)',
             title='Figure 3.2 &#8212; P-V against irradiance. One hill, and its top slides slowly left.')
    g2.limits(0, 40, 0, 280)
    for i, g in enumerate(GS):
        V, I, Pw = m.curve(G=g)
        g2.path(V, Pw, f's{i+1}')
        Vm, Im, Pm = m.mpp(V, I)
        g2.dot(Vm, Pm, 'ptmpp', 4)
    g2.axes(ticks(0, 40, 5), [0, 50, 100, 150, 200, 250])
    legend(g2, [(f'{g} W/m&#178;', f's{i+1}') for i, g in enumerate(GS)])
    save('irradiance_pv', g2)


# ------------------------------------------------ 4/5. temperature families
TS = [15, 25, 45, 65]


def f_temp():
    f = Fig(mr=112, xlab='Module voltage  (V)', ylab='Module current  (A)',
            title='Figure 3.3 &#8212; I-V against cell temperature (1000 W/m&#178;). The voltage collapses; the current does not.')
    f.limits(0, 42, 0, 10)
    for i, t in enumerate(TS):
        V, I, _ = m.curve(T=273.15 + t)
        f.path(V, I, f's{i+1}')
        Vm, Im, _ = m.mpp(V, I)
        f.dot(Vm, Im, 'ptmpp', 4)
    f.axes(ticks(0, 42, 6), [0, 2, 4, 6, 8, 10])
    legend(f, [(f'{t} &#176;C', f's{i+1}') for i, t in enumerate(TS)])
    save('temp_iv', f)

    g2 = Fig(mr=112, xlab='Module voltage  (V)', ylab='Module power  (W)',
             title='Figure 3.4 &#8212; P-V against cell temperature. Hot modules make less power at a lower voltage.')
    g2.limits(0, 42, 0, 300)
    for i, t in enumerate(TS):
        V, I, Pw = m.curve(T=273.15 + t)
        g2.path(V, Pw, f's{i+1}')
        Vm, Im, Pm = m.mpp(V, I)
        g2.dot(Vm, Pm, 'ptmpp', 4)
    g2.axes(ticks(0, 42, 6), [0, 50, 100, 150, 200, 250, 300])
    legend(g2, [(f'{t} &#176;C', f's{i+1}') for i, t in enumerate(TS)])
    save('temp_pv', g2)


# ---------------------------------------------------- 6. parasitic elements
def f_parasitic():
    vals = [0.05, 0.16, 0.45, 0.90]
    f = Fig(mr=140, xlab='Module voltage  (V)', ylab='Module current  (A)',
            title='Figure 2.5 &#8212; Series resistance R&#8347; shears the knee down and to the left')
    f.limits(0, 40, 0, 10)
    for i, rs in enumerate(vals):
        p = dict(m.P); p['Rs'] = rs
        V, I, _ = m.curve(p=p)
        f.path(V, I, f's{i+1}')
    f.axes(ticks(0, 40, 5), [0, 2, 4, 6, 8, 10])
    legend(f, [(f'R&#8347; = {r} &#8486;', f's{i+1}') for i, r in enumerate(vals)])
    save('rs_effect', f)

    vals2 = [2000, 211, 60, 20]
    g2 = Fig(mr=140, xlab='Module voltage  (V)', ylab='Module current  (A)',
             title='Figure 2.6 &#8212; Shunt resistance R&#8347;&#8341; tilts the flat part of the curve')
    g2.limits(0, 40, 0, 10)
    for i, rsh in enumerate(vals2):
        p = dict(m.P); p['Rsh'] = rsh
        V, I, _ = m.curve(p=p)
        g2.path(V, I, f's{i+1}')
    g2.axes(ticks(0, 40, 5), [0, 2, 4, 6, 8, 10])
    legend(g2, [(f'R&#8347;&#8341; = {r} &#8486;', f's{i+1}') for i, r in enumerate(vals2)])
    save('rsh_effect', g2)


# --------------------------------------------------------- 7. the load line
def f_loadline():
    V, I, Pw = m.curve()
    Vm, Im, Pm = m.mpp(V, I)
    pp = m.params()
    Ropt = Vm / Im
    f = Fig(mr=150, xlab='Module voltage  (V)', ylab='Module current  (A)',
            title='Figure 4.1 &#8212; The load, not the panel, chooses the operating point')
    f.limits(0, 40, 0, 10)
    f.path(V, I, 's1')
    for R in (1.5, Ropt, 12.0):
        vv = np.linspace(0, 40, 40); ii = vv / R
        keep = ii <= 10
        f.path(vv[keep], ii[keep], 'dash2')
        vop = brentq(lambda x: m.current(x, pp) - x / R, 0.01, V[-1])
        iop = vop / R
        f.dot(vop, iop, 'pt', 4.6)
        f.text(vop, iop, f'{vop*iop:.0f} W', dx=8, dy=-9, cls='lbls')
    f.text(6.0, 4.0, 'R = 1.5 &#8486;', cls='lbls', anchor='middle')
    f.text(34.5, 2.9, 'R = 12 &#8486;', cls='lbls', anchor='middle')
    f.text(24.0, 8.9, f'R = R&#8358;&#8347;&#8348; = {Ropt:.2f} &#8486;', cls='lbls', anchor='middle')
    Vbat = 24.0
    f.line(Vbat, 0, Vbat, 10, 'dash3')
    ib = m.current(Vbat, pp)
    f.dot(Vbat, ib, 'ptbad', 5.4)
    f.text(Vbat, ib, f'24 V battery clamp: {Vbat*ib:.0f} W', dx=-10, dy=22, anchor='end', cls='lblbad')
    f.dot(Vm, Im, 'ptmpp', 6.4)
    f.text(Vm, Im, f'MPP {Pm:.0f} W', dx=10, dy=-12, cls='lblb')
    f.axes(ticks(0, 40, 5), [0, 2, 4, 6, 8, 10])
    legend(f, [('module I-V', 's1'), ('resistive load line', 'dash2'),
               ('battery clamp', 'dash3'), ('true MPP', 'ptmpp')])
    save('loadline', f)


# ------------------------------------------ 8. stability of the MPP ratios
def f_ratios():
    gs = np.arange(100, 1001, 50)
    kv, ki = [], []
    for g in gs:
        V, I, _ = m.curve(G=float(g), npts=600)
        Vm, Im, _ = m.mpp(V, I)
        kv.append(Vm / V[-1]); ki.append(Im / I[0])
    ts = np.arange(0, 71, 5)
    kvt = []
    for t in ts:
        V, I, _ = m.curve(T=273.15 + float(t), npts=600)
        Vm, Im, _ = m.mpp(V, I)
        kvt.append(Vm / V[-1])
    f = Fig(mr=140, xlab='Irradiance  G  (W/m&#178;)', ylab='Ratio  (dimensionless)',
            title='Figure 5.2 &#8212; V&#8344;&#8344;/V&#8338;&#8336; and I&#8344;&#8344;/I&#8347;&#8344; hardly move, which is what makes the fractional methods work')
    f.limits(0, 1000, 0.6, 1.0)
    f.path(gs, kv, 's1'); f.path(gs, ki, 's3')
    f.axes([0, 200, 400, 600, 800, 1000], [0.6, 0.7, 0.8, 0.9, 1.0], yfmt='{:.2f}')
    legend(f, [('V&#8344;&#8344; / V&#8338;&#8336;  (vs G)', 's1'), ('I&#8344;&#8344; / I&#8347;&#8344;  (vs G)', 's3')])
    f.textpx(f.w - f.mr + 8, 108, 'spread over 100-1000 W/m&#178;', cls='leg')
    f.textpx(f.w - f.mr + 8, 128, f'k&#8342; : {min(kv):.3f} to {max(kv):.3f}', cls='legb')
    f.textpx(f.w - f.mr + 8, 148, f'k&#8305; : {min(ki):.3f} to {max(ki):.3f}', cls='legb')
    f.textpx(f.w - f.mr + 8, 176, 'over 0-70 &#176;C', cls='leg')
    f.textpx(f.w - f.mr + 8, 196, f'k&#8342; : {min(kvt):.3f} to {max(kvt):.3f}', cls='legb')
    save('ratio_stability', f)


# ------------------------------------------------------- 9. P&O on the hill
def f_po():
    V, I, Pw = m.curve()
    Vm, Im, Pm = m.mpp(V, I)
    f = Fig(xlab='Module voltage  (V)', ylab='Module power  (W)',
            title='Figure 6.1 &#8212; Perturb and observe walks uphill, then oscillates across the top')
    f.limits(0, 40, 0, 300)
    f.path(V, Pw, 's1')
    seq = [18, 21.5, 25, 28, 30.9, 33.4]
    for v0 in seq:
        j = int(np.argmin(abs(V - v0)))
        f.dot(V[j], Pw[j], 'pt', 4.4)
    for a, b, cls in [(18, 21.5, 'arrow'), (21.5, 25, 'arrow'), (25, 28, 'arrow'),
                      (28, 30.9, 'arrow'), (30.9, 33.4, 'arrow'), (33.4, 30.9, 'arrowb')]:
        ja = int(np.argmin(abs(V - a))); jb = int(np.argmin(abs(V - b)))
        f.body.append(f'<line class="{cls}" x1="{f.X(V[ja]):.1f}" y1="{f.Y(Pw[ja])-13:.1f}" '
                      f'x2="{f.X(V[jb]):.1f}" y2="{f.Y(Pw[jb])-13:.1f}" '
                      f'marker-end="url(#{"ah" if cls=="arrow" else "ahb"})"/>')
    f.dot(Vm, Pm, 'ptmpp', 6.4)
    f.text(20, 245, '&#916;P &gt; 0 : keep going the same way', cls='lbl')
    f.text(37.5, 195, '&#916;P &lt; 0 :', cls='lblbad', anchor='end')
    f.text(37.5, 178, 'turn around', cls='lblbad', anchor='end')
    f.axes(ticks(0, 40, 5), [0, 50, 100, 150, 200, 250, 300])
    save('po_hill', f)


# -------------------------------------------------- 10. incremental conduct
def f_inc():
    V, I, Pw = m.curve(npts=800)
    Vm, Im, Pm = m.mpp(V, I)
    dP = np.gradient(Pw, V)
    f = Fig(xlab='Module voltage  (V)', ylab='dP/dV   (W per V)',
            title='Figure 6.3 &#8212; dP/dV is the quantity the tracker drives to zero')
    f.limits(0, 40, -140, 40)
    f.path(V[3:-3], dP[3:-3], 's5')
    f.line(0, 0, 40, 0, 'ax2')
    f.line(Vm, -140, Vm, 40, 'dash')
    f.dot(Vm, 0, 'ptmpp', 6.4)
    f.text(4, 22, 'dI/dV &gt; &#8722;I/V', cls='lbl')
    f.text(4, 8, 'left of the peak', cls='lbls')
    f.text(37.5, -70, 'dI/dV &lt; &#8722;I/V', cls='lblbad', anchor='end')
    f.text(37.5, -84, 'right of the peak', cls='lbls', anchor='end')
    f.text(Vm, 40, f'V&#8344;&#8344; = {Vm:.1f} V', dx=8, dy=14, cls='lblb')
    f.axes(ticks(0, 40, 5), [-140, -105, -70, -35, 0, 35])
    save('inccond', f)


# ------------------------------------------------- 11. reverse bias / Bishop
def bishop_cell_iv(vs, G=1000.0, Vbr=-15.0, ab=0.0025, mm=3.0):
    pp = m.params(G)
    a = m._a(pp['n'], 1, pp['T'])
    Rs, Rsh, Iph, I0 = pp['Rs'] / NS, pp['Rsh'] / NS, pp['Iph'], pp['I0']

    def res(I, V):
        Vj = V + I * Rs
        av = 1.0 + ab * (1.0 - min(Vj / Vbr, 0.999)) ** (-mm)
        return Iph - I0 * (math.exp(min(Vj / a, 300)) - 1.0) - (Vj / Rsh) * av - I

    out = []
    for V in vs:
        try:
            out.append(brentq(res, -6.0, Iph + 6.0, args=(V,), xtol=1e-10))
        except ValueError:
            out.append(float('nan'))
    return np.array(out)


def f_reverse():
    vs = np.linspace(-18, 0.72, 620)
    Istr = 8.56
    f = Fig(mr=140, xlab='Cell voltage  (V)', ylab='Cell current  (A)',
            title='Figure 8.1 &#8212; A shaded cell is driven into reverse bias and becomes a heater')
    f.limits(-18, 2, -2, 10)
    i1 = bishop_cell_iv(vs, G=1000)
    i2 = bishop_cell_iv(vs, G=200)
    f.path(vs, np.clip(i1, -2, 10), 's1')
    f.path(vs, np.clip(i2, -2, 10), 's4')
    f.line(-18, Istr, 2, Istr, 'dash3')
    f.line(-18, 0, 2, 0, 'ax2')
    j = int(np.nanargmin(abs(i2 - Istr)))
    f.dot(vs[j], Istr, 'ptbad', 6.4)
    f.text(vs[j], Istr, f'{vs[j]:.1f} V &#215; {Istr:.1f} A &#8776; {abs(vs[j]*Istr):.0f} W', dx=10, dy=24, cls='lblbad')
    f.text(vs[j], Istr, 'turned into heat inside one cell', dx=10, dy=41, cls='lbls')
    f.text(-17.6, Istr, 'current forced through by the healthy cells', dx=0, dy=-10, cls='lbls')
    f.axes([-18, -15, -12, -9, -6, -3, 0], [-2, 0, 2, 4, 6, 8, 10])
    legend(f, [('cell at 1000 W/m&#178;', 's1'), ('cell at 200 W/m&#178;', 's4'),
               ('string current', 'dash3')])
    save('reverse_bias', f)


# ------------------------------------------------- 12/13. shaded string I-V
SHADE = [1000, 600, 300]


def f_string():
    V, I, Pw = m.string_curve(SHADE)
    Vu, Iu, Pu = m.string_curve([1000, 1000, 1000])
    f = Fig(mr=158, xlab='String voltage  (V)', ylab='String current  (A)',
            title='Figure 9.1 &#8212; Three series modules at 1000 / 600 / 300 W/m&#178;: the I-V becomes a staircase')
    f.limits(0, 120, 0, 10)
    f.path(Vu, Iu, 's4'); f.path(V, I, 's1')
    f.axes([0, 20, 40, 60, 80, 100, 120], [0, 2, 4, 6, 8, 10])
    legend(f, [('uniform 1000 W/m&#178;', 's4'), ('shaded string', 's1')])
    save('string_iv', f)

    g2 = Fig(mr=158, xlab='String voltage  (V)', ylab='String power  (W)',
             title='Figure 9.2 &#8212; The same string in the P-V plane: one hill becomes three')
    g2.limits(0, 120, 0, 900)
    g2.path(Vu, Pu, 's4'); g2.path(V, Pw, 's1')
    pk = m.local_peaks(V, Pw)
    gp = max(pk, key=lambda t: t[1])
    for v, p_ in pk:
        if v == gp[0]:
            g2.dot(v, p_, 'ptmpp', 6.6)
            g2.text(v, p_, f'global peak  {p_:.0f} W', dx=10, dy=-13, cls='lblb')
        else:
            g2.dot(v, p_, 'ptbad', 5)
            g2.text(v, p_, f'{p_:.0f} W', dx=-6, dy=-11, cls='lbls', anchor='end')
    g2.axes([0, 20, 40, 60, 80, 100, 120], [0, 150, 300, 450, 600, 750, 900])
    legend(g2, [('uniform 1000 W/m&#178;', 's4'), ('shaded string', 's1'),
                ('global peak', 'ptmpp'), ('local peak', 'ptbad')])
    save('string_pv', g2)


# ------------------------------------------------------ 14. shading pattern
PATTERNS = [([1000, 1000, 1000, 1000], 'uniform 1000'),
            ([1000, 1000, 500, 500], 'two at 50 %'),
            ([1000, 750, 500, 250], 'graded shade'),
            ([1000, 1000, 1000, 200], 'one deep shade')]


def f_patterns():
    f = Fig(mr=140, xlab='String voltage  (V)', ylab='String power  (W)',
            title='Figure 9.3 &#8212; Four shade patterns on one four-module string')
    f.limits(0, 160, 0, 1120)
    for i, (pat, lab) in enumerate(PATTERNS):
        V, I, Pw = m.string_curve(pat, npts=900)
        f.path(V, Pw, f's{i+1}')
        for v, p_ in m.local_peaks(V, Pw):
            f.dot(v, p_, 'ptsm', 3.6)
    f.axes([0, 40, 80, 120, 160], [0, 200, 400, 600, 800, 1000])
    legend(f, [(lab, f's{i+1}') for i, (p, lab) in enumerate(PATTERNS)], y=44, dy=21)
    save('patterns', f)


# ------------------------------------------------------- 15. search windows
def f_windows():
    pat = [1000, 800, 450, 250]
    V, I, Pw = m.string_curve(pat, npts=1400)
    Voc_mod = 37.5
    f = Fig(mr=150, xlab='String voltage  (V)', ylab='String power  (W)',
            title='Figure 10.1 &#8212; Every peak falls inside k &#215; (0.72 to 0.95) V&#8338;&#8336;, so only four short windows need a visit')
    f.limits(0, 160, 0, 900)
    for k in range(1, 5):
        f.rect(0.72 * k * Voc_mod, 0, 0.95 * k * Voc_mod, 900, 'band2')
        f.line(0.83 * k * Voc_mod, 0, 0.83 * k * Voc_mod, 900, 'dash')
        f.text(0.835 * k * Voc_mod, 872, f'window k = {k}', anchor='middle', cls='lbls')
    f.path(V, Pw, 's1')
    pk = m.local_peaks(V, Pw)
    gp = max(pk, key=lambda t: t[1])
    for k, (v, p_) in enumerate(pk, start=1):
        f.dot(v, p_, 'ptmpp' if v == gp[0] else 'ptbad', 6.4 if v == gp[0] else 4.6)
        f.text(v, p_, f'{v/(k*Voc_mod):.2f}&#183;kV&#8338;&#8336;', dx=0, dy=22, cls='lbls', anchor='middle')
    f.text(gp[0], gp[1], f'global peak {gp[1]:.0f} W at {gp[0]:.0f} V', dx=12, dy=-13, cls='lblb')
    f.axes([0, 40, 80, 120, 160], [0, 150, 300, 450, 600, 750, 900])
    legend(f, [('P-V curve', 's1'), ('window centre', 'dash'), ('window to search', 'band2')])
    save('windows', f)
    return [(round(v, 1), round(p_, 1)) for v, p_ in pk]


# --------------------------------------------------- 16. evaluation budget
def f_budget():
    data = [('Exhaustive sweep, 0.5 V steps', 320),
            ('Particle swarm, 6 particles &#215; 15 iterations', 90),
            ('Grey wolf, 4 agents &#215; 20 iterations', 80),
            ('DIRECT / Lipschitz 1-D search', 40),
            ('Fibonacci search inside each segment', 30),
            ('0.8&#183;V&#8338;&#8336; window scan, then local climb', 12)]
    f = Fig(w=780, h=340, ml=310, mr=60, mt=36, mb=56,
            xlab='Converter settling steps needed before the global peak is held', ylab='',
            title='Figure 11.1 &#8212; The cost that matters is settling steps, not arithmetic')
    f.limits(0, 340, 0, len(data))
    for i, (lab, n) in enumerate(data):
        y = len(data) - i - 0.5
        f.body.append(f'<rect class="bar{i+1}" x="{f.X(0):.1f}" y="{f.Y(y)-12:.1f}" '
                      f'width="{f.X(n)-f.X(0):.1f}" height="24" rx="3"/>')
        f.textpx(f.ml - 12, f.Y(y) + 5, lab, cls='lbl', anchor='end')
        f.textpx(f.X(n) + 9, f.Y(y) + 5, f'&#8776; {n}', cls='legb')
    f.axes([0, 100, 200, 300], [], grid=True)
    save('budget', f)


if __name__ == '__main__':
    print('generating figures...')
    for fn in (f_cell, f_irr, f_temp, f_parasitic, f_loadline, f_ratios,
               f_po, f_inc, f_reverse, f_string, f_patterns, f_windows, f_budget):
        fn()
    print('done')


# ------------------------------------------------ 17/18. combining curves
def f_combine():
    V, I, _ = m.curve()
    Vm, Im, _ = m.mpp(V, I)
    Ilev = 6.0
    j = int(np.argmin(abs(I - Ilev)))
    v1 = V[j]
    f = Fig(mr=150, xlab='Voltage  (V)', ylab='Current  (A)',
            title='Figure 7.1 &#8212; Series: the voltages add at the same current')
    f.limits(0, 80, 0, 10)
    f.path(V, I, 's1')
    f.path(2 * V, I, 's3')
    f.line(0, Ilev, 2 * v1, Ilev, 'dash')
    f.dot(v1, Ilev, 'pt', 5); f.dot(2 * v1, Ilev, 'pt', 5)
    f.text(v1, Ilev, f'V&#8321; = {v1:.1f} V', dx=-8, dy=-11, anchor='end', cls='lbls')
    f.text(2 * v1, Ilev, f'V&#8321; + V&#8322; = {2*v1:.1f} V', dx=10, dy=-11, cls='lbls')
    f.axes([0, 20, 40, 60, 80], [0, 2, 4, 6, 8, 10])
    legend(f, [('one module', 's1'), ('two in series', 's3')])
    save('combine_series', f)

    Vlev = 20.0
    i1 = m.current(Vlev, m.params())
    g2 = Fig(mr=150, xlab='Voltage  (V)', ylab='Current  (A)',
             title='Figure 7.2 &#8212; Parallel: the currents add at the same voltage')
    g2.limits(0, 40, 0, 20)
    g2.path(V, I, 's1')
    g2.path(V, 2 * I, 's3')
    g2.line(Vlev, 0, Vlev, 2 * i1, 'dash')
    g2.dot(Vlev, i1, 'pt', 5); g2.dot(Vlev, 2 * i1, 'pt', 5)
    g2.text(Vlev, i1, f'I&#8321; = {i1:.2f} A', dx=10, dy=5, cls='lbls')
    g2.text(Vlev, 2 * i1, f'I&#8321; + I&#8322; = {2*i1:.2f} A', dx=10, dy=5, cls='lbls')
    g2.axes([0, 10, 20, 30, 40], [0, 5, 10, 15, 20])
    legend(g2, [('one module', 's1'), ('two in parallel', 's3')])
    save('combine_parallel', g2)
