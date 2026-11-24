"""Figures of the worked example: DIRECT against the ceiling-guided search (Idea C).

The curve is an idealized partly shaded array in volts. It is for teaching only.
The search runs in volts with the exact corner point. The controller of the
project runs in duty and estimates the corner (docs/notes/gmppt_methods.md,
sections 3 to 5).

Run: python make_figures.py   (writes the PNG files next to this script)
"""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.path.dirname(os.path.abspath(__file__))

# Colors of plots/plot_style.m
BLUE, ORANGE, GREEN = "#2a78d6", "#eb6834", "#1baf7a"
INK, INK2, REF, GRID = "#0b0b0b", "#52514e", "#b9b8b2", "#e4e3de"
plt.rcParams.update({
    "font.family": "Arial", "font.size": 10, "axes.edgecolor": INK2,
    "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
    "axes.grid": True, "grid.color": GRID, "axes.spines.top": False,
    "axes.spines.right": False, "axes.titlesize": 11, "axes.titleweight": "bold",
    "axes.titlecolor": INK, "figure.dpi": 100, "savefig.dpi": 200,
})

EPS_C = 0.02          # margin of the open test, as mppt.eps_c


def current(v):
    """Array current [A] at the voltage v [V]. It never rises with v."""
    v = np.asarray(v, dtype=float)
    return np.select([v <= 80, v <= 90, v <= 140, v <= 180],
                     [30.0, 30 - 1.2 * (v - 80), 18.0, 0.45 * (180 - v)], 0.0)


def power(v):
    return v * current(v)


V = np.linspace(0, 180, 3601)
P = power(V)
PG, VG = P.max(), V[P.argmax()]              # global peak: 2520 W at 140 V


# DIRECT in one dimension (Jones et al. 1993), maximization, epsilon = 1e-4
def direct_tests(n_tests):
    boxes = [(0.0, 180.0, 90.0, float(power(90)))]
    tests = [(90.0, float(power(90)), 1)]
    rnd = 0
    while len(tests) < n_tests:
        rnd += 1
        fmax = max(b[3] for b in boxes)
        po = []
        for j, (a, b, c, f) in enumerate(boxes):
            d = (b - a) / 2
            kmin, kmax = (fmax * (1 + 1e-4) - f) / d, np.inf
            ok = True
            for i, (a2, b2, c2, f2) in enumerate(boxes):
                if i == j:
                    continue
                d2 = (b2 - a2) / 2
                if abs(d2 - d) < 1e-9:
                    ok &= f >= f2
                elif d2 < d:
                    kmin = max(kmin, (f2 - f) / (d - d2))
                else:
                    kmax = min(kmax, (f - f2) / (d2 - d))
            if ok and kmin <= kmax and kmax > 0:
                po.append(j)
        po.sort(key=lambda j: -(boxes[j][1] - boxes[j][0]))   # widest first
        new = []
        for j in po:
            a, b, c, f = boxes[j]
            w = (b - a) / 3
            for cc in (a + w / 2, b - w / 2):
                tests.append((cc, float(power(cc)), rnd))
            new += [(a, a + w, a + w / 2, float(power(a + w / 2))), (a + w, b - w, c, f),
                    (b - w, b, b - w / 2, float(power(b - w / 2)))]
        boxes = [bx for k, bx in enumerate(boxes) if k not in po] + new
    return tests[:n_tests]


# Ceiling-guided search (Idea C), exact corner, in volts
def corner_v(v_lo, v_hi, r_star):
    """Voltage where V / I(V) = r_star. V / I rises with V, so bisection works."""
    lo, hi = v_lo, v_hi
    for _ in range(80):
        m = (lo + hi) / 2
        if m / max(float(current(m)), 1e-12) < r_star:
            lo = m
        else:
            hi = m
    return (lo + hi) / 2


def gaps(samples):
    s = sorted(samples)
    pb = max(power(v) for v in s)
    out = []
    for v1, v2 in zip(s[:-1], s[1:]):
        u = v2 * float(current(v1))                      # higher voltage x higher current
        out.append((v1, v2, u, u > (1 + EPS_C) * pb and v2 - v1 > 1.0))
    return out, float(pb)


def ideac_tests():
    samples = [10.0, 90.0, 170.0]
    history = [list(samples)]
    while True:
        g, pb = gaps(samples)
        open_g = [x for x in g if x[3]]
        if not open_g:
            break
        v1, v2, u, _ = max(open_g, key=lambda x: x[2])
        samples.append(corner_v(v1, v2, v2 / float(current(v1))))
        history.append(list(samples))
    return samples, history


D = direct_tests(11)
C, HIST = ideac_tests()

print("DIRECT:")
for k, (v, p, r) in enumerate(D, 1):
    print(f"  {k:2d}  round {r}  {v:6.1f} V  {p:6.0f} W  {100 * p / PG:5.1f} %")
print("Idea C:")
for k, v in enumerate(C, 1):
    print(f"  {k:2d}  {v:6.1f} V  {float(current(v)):5.2f} A  {float(power(v)):6.0f} W  {100 * float(power(v)) / PG:5.1f} %")
lossD = sum(1 - p / PG for _, p, _ in D)
lossC = sum(1 - float(power(v)) / PG for v in C)
print(f"Loss: DIRECT {lossD:.2f}, Idea C {lossC:.2f} test-equivalents")


def pv_axes(ax, ymax=3200):
    ax.plot(V, P, color=INK2, lw=1.6, zorder=2)
    ax.set_xlim(0, 182)
    ax.set_ylim(0, ymax)
    ax.set_xlabel("Array voltage (V)")
    ax.set_ylabel("Array power (W)")


def mark(ax, v, p, n, color, dy=70):
    ax.plot(v, p, "o", ms=9, mfc=color, mec="white", mew=1.2, zorder=5)
    ax.text(v, p + dy, str(n), ha="center", va="bottom", fontsize=9, color=INK, fontweight="bold", zorder=6)


# Figure 1: the curve
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 4.2))
a1.plot(V, current(V), color=INK2, lw=1.6)
a1.set_xlim(0, 182); a1.set_ylim(0, 34)
a1.set_xlabel("Array voltage (V)"); a1.set_ylabel("Array current (A)")
a1.set_title("Current against voltage")
a1.text(40, 31, "Unshaded step: 30 A", ha="center", color=INK2)
a1.text(115, 19, "Shaded step: 18 A", ha="center", color=INK2)
a1.annotate("Bypass diodes switch", xy=(85, 24), xytext=(100, 27), color=INK2,
            arrowprops=dict(arrowstyle="-", color=INK2, lw=0.8))
a1.text(4, 2, "The current never rises when the voltage rises.", color=INK2, fontsize=9)
pv_axes(a2, 2900)
a2.set_title("Power against voltage")
a2.plot(80, 2400, "o", ms=9, mfc=REF, mec=INK2, zorder=5)
a2.text(80, 2480, "Local peak\n2400 W at 80 V", ha="center", va="bottom", fontsize=9, color=INK2)
a2.plot(VG, PG, "o", ms=10, mfc=GREEN, mec="white", mew=1.2, zorder=5)
a2.text(VG, PG + 80, "Global peak\n2520 W at 140 V", ha="center", va="bottom", fontsize=9, color=INK)
a2.text(90, 1450, "Valley\n1620 W at 90 V", ha="center", va="top", fontsize=9, color=INK2)
fig.suptitle("The example: an idealized partly shaded array with two peaks", fontweight="bold", color=INK)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "1_example_curve.png"))
plt.close(fig)

# Figure 2: DIRECT
fig, ax = plt.subplots(figsize=(10, 4.8))
pv_axes(ax, 3000)
ax.axvspan(0, 60, color=REF, alpha=0.25, lw=0, zorder=1)
ax.plot([0, 60], [1800, 1800], ls="--", color=INK2, lw=1)
ax.text(30, 1850, "Bound below 60 V:\n60 V × 30 A = 1800 W", ha="center", va="bottom", fontsize=9, color=INK2)
ax.text(30, 2600, "Tests 10 and 11 fall here.\nThe best so far is 2460 W (test 9),\nso this region cannot win.\nDIRECT does not use this bound.\n(Test 2 came when the best was\nonly 1620 W, below this bound.)",
        ha="center", va="center", fontsize=9, color=INK)
for k, (v, p, r) in enumerate(D, 1):
    mark(ax, v, p, k, BLUE, 70)
ax.set_title("DIRECT: 11 tests, and still no rule that says the peak is found")
ax.text(178, 2900, "Round 1: tests 1 to 3.  Round 2: 4 and 5.  Round 3: 6 to 9.  Round 4: 10, 11 and more.",
        ha="right", fontsize=8.5, color=INK2)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "2_direct_tests.png"))
plt.close(fig)

# Figure 3: the ceiling of one gap, and the corner split
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 4.6))
for ax in (a1, a2):
    ax.plot(V, current(V), color=REF, lw=1.4)
    ax.set_xlim(0, 182); ax.set_ylim(0, 41)
    ax.set_xlabel("Array voltage (V)"); ax.set_ylabel("Array current (A)")
vb, vc = 90.0, 170.0
ib, ic = float(current(vb)), float(current(vc))
a1.add_patch(plt.Rectangle((0, 0), vc, ib, color=ORANGE, alpha=0.10, lw=0))
a1.add_patch(plt.Rectangle((vb, ic), vc - vb, ib - ic, fill=False, ls="--", ec=INK2, lw=1))
seg = (V >= vb) & (V <= vc)
a1.plot(V[seg], current(V[seg]), color=INK, lw=2)
for v, i, lab, ha in ((vb, ib, "Sample at 90 V, 18 A", "right"), (vc, ic, "Sample at 170 V, 4.5 A", "right")):
    a1.plot(v, i, "o", ms=9, mfc=ORANGE, mec="white", mew=1.2, zorder=5)
    a1.text(v - 3, i - 2.2, lab, ha=ha, fontsize=9, color=INK)
a1.plot(vc, ib, "D", ms=8, mfc="white", mec=ORANGE, mew=2, zorder=5)
a1.text(vc, ib + 1.2, "Corner", ha="center", fontsize=9, color=INK)
a1.text(60, 8, "Ceiling U = 170 V × 18 A\n= 3060 W", ha="center", fontsize=10, color=INK)
a1.text(4, 40, "Between the samples, V ≤ 170 V and I ≤ 18 A.\nSo P = V × I ≤ 3060 W, whatever the curve does.",
        fontsize=9, color=INK2, va="top")
a1.set_title("Two samples give a ceiling for the gap between them")
v4 = corner_v(vb, vc, vc / ib)
i4 = float(current(v4))
a2.plot([0, vc], [0, ib], ls=":", color=ORANGE, lw=1.2)
a2.text(20, 8.5, "Load line through the corner:\nV / I = 170 V / 18 A = 9.4 Ω", fontsize=9, color=INK2)
a2.add_patch(plt.Rectangle((vb, ic), vc - vb, ib - ic, fill=False, ls="--", ec=REF, lw=1))
a2.add_patch(plt.Rectangle((vb, i4), v4 - vb, ib - i4, fill=False, ls="--", ec=INK2, lw=1))
a2.add_patch(plt.Rectangle((v4, ic), vc - v4, i4 - ic, fill=False, ls="--", ec=INK2, lw=1))
for v, i in ((vb, ib), (vc, ic)):
    a2.plot(v, i, "o", ms=9, mfc=ORANGE, mec="white", mew=1.2, zorder=5)
a2.plot(v4, i4, "o", ms=10, mfc=ORANGE, mec=INK, mew=1.2, zorder=6)
a2.annotate(f"New test where the load line\nmeets the curve: {v4:.0f} V, {i4:.1f} A, {v4 * i4:.0f} W",
            xy=(v4, i4), xytext=(112, 24), ha="center", fontsize=9, color=INK,
            arrowprops=dict(arrowstyle="-", color=INK2, lw=0.8))
a2.plot([v4, vc], [ib, i4], "D", ms=7, mfc="white", mec=ORANGE, mew=1.6, zorder=5)
u1, u2 = v4 * ib, vc * i4
a2.text(4, 40, f"Two smaller boxes, two lower ceilings:\n{v4:.0f} V × 18 A = {u1:.0f} W and 170 V × {i4:.1f} A = {u2:.0f} W.\nBoth are below the old 3060 W. They are equal\nbecause the test lies on the load line.",
        fontsize=9, color=INK2, va="top")
a2.set_title("A test at the corner splits the box")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "3_ceiling_idea.png"))
plt.close(fig)

# Figure 4: Idea C, after test 6 and at the end
fig, axs = plt.subplots(2, 1, figsize=(10, 9.4))
for ax, n, title in ((axs[0], 6, "After test 6: the left half closes without another test"),
                     (axs[1], len(C), f"After test {len(C)}: every gap is closed, so the search stops at {float(power(C[-1])):.0f} W ({100 * float(power(C[-1])) / PG:.1f} % of the peak)")):
    pv_axes(ax, 3250)
    smp = C[:n]
    g, pb = gaps(smp)
    thr = (1 + EPS_C) * pb
    for v1, v2, u, op in g:
        if not op:
            ax.axvspan(v1, v2, color=REF, alpha=0.18, lw=0, zorder=1)
        ax.plot([v1, v2], [u, u], color=ORANGE if op else INK2, lw=2.2 if op else 1.4, zorder=3)
    ax.axhline(thr, ls="--", color=GREEN, lw=1.2, zorder=2)
    ax.text(2, thr + 40, f"Open limit = 1.02 × best ({pb:.0f} W) = {thr:.0f} W", fontsize=9, color=INK, va="bottom")
    zoomed = [k for k, v in enumerate(smp, 1) if n > 6 and 138.5 < v < 151.5]
    for k, v in enumerate(smp, 1):
        if k in zoomed:               # crowded near 140 V: labels in the zoom
            ax.plot(v, float(power(v)), "o", ms=9, mfc=ORANGE, mec="white", mew=1.2, zorder=5)
        else:
            mark(ax, v, float(power(v)), k, ORANGE, 70)
    ax.set_title(title, fontsize=10.5)
    if zoomed:
        z = ax.inset_axes([0.47, 0.08, 0.36, 0.32])
        z.set_facecolor("white")
        z.plot(V, P, color=INK2, lw=1.6)
        for v1, v2, u, op in g:
            z.plot([v1, v2], [u, u], color=INK2, lw=1.4)
        z.axhline(thr, ls="--", color=GREEN, lw=1.2)
        for k in zoomed:
            v = smp[k - 1]
            p = float(power(v))
            z.plot(v, p, "o", ms=8, mfc=ORANGE, mec="white", mew=1.2, zorder=5)
            if k in (9, 6):
                z.text(v - 0.3, p - 25, str(k), fontsize=9, fontweight="bold", color=INK,
                       va="top", ha="right", zorder=6)
            else:
                z.text(v + 0.45, p, str(k), fontsize=9, fontweight="bold", color=INK,
                       va="center", ha="left", zorder=6)
        z.set_xlim(138.5, 151.5); z.set_ylim(2000, 2580)
        z.set_xticks([140, 145, 150]); z.set_yticks([2100, 2300, 2500])
        z.tick_params(labelsize=8)
        z.text(139, 2030, "Zoom: 139 to 151 V", ha="left", fontsize=8.5, color=INK2)
        ax.indicate_inset_zoom(z, edgecolor=INK2)
axs[0].text(46, 2180, "Ceilings 2465 W, below the limit:\nclosed. The local peak at 80 V\nis ruled out.",
            ha="center", va="top", fontsize=9, color=INK)
axs[0].text(2, 3150, "Orange line: ceiling of an open gap.  Dark line: ceiling of a closed gap.  Gray band: closed region.",
            ha="left", va="top", fontsize=8.5, color=INK2)
fig.suptitle("Idea C: the ceiling decides where to test and when to stop", fontweight="bold", color=INK)
fig.subplots_adjust(left=0.08, right=0.98, top=0.92, bottom=0.06, hspace=0.30)
fig.savefig(os.path.join(OUT, "4_ideac_tests.png"))
plt.close(fig)

# Figure 5: power at each test
fig, axs = plt.subplots(2, 1, figsize=(10, 5.6), sharex=True)
pd_ = [100 * p / PG for _, p, _ in D]
pc_ = [100 * float(power(v)) / PG for v in C]
for ax, vals, col, name, note in (
        (axs[0], pd_, BLUE, "DIRECT", f"Energy lost: {lossD:.1f} test-equivalents. Not finished: no stop rule."),
        (axs[1], pc_, ORANGE, "Idea C", f"Energy lost: {lossC:.1f} test-equivalents. Stops at test {len(C)}: peak proven.")):
    x = np.arange(1, len(vals) + 1)
    ax.bar(x, vals, width=0.6, color=col, zorder=3)
    for xi, yi in zip(x, vals):
        ax.text(xi, yi + 2, f"{yi:.0f}", ha="center", va="bottom", fontsize=8.5, color=INK)
    ax.axhline(100, ls="--", color=GREEN, lw=1.2)
    ax.set_ylim(0, 125); ax.set_xlim(0.4, 11.6)
    ax.set_ylabel("P / P global (%)")
    ax.set_title(f"{name}: power at each test", loc="left")
    ax.text(11.5, 112, note, ha="right", fontsize=9, color=INK)
    ax.grid(axis="x", visible=False)
axs[1].text(10.5, 50, "After test 3,\nno test falls\nbelow 81 %", ha="center", va="center", fontsize=9, color=INK2)
axs[1].set_xticks(range(1, 12))
axs[1].set_xlabel("Test number (one 40 ms test period each)")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "5_power_per_test.png"))
plt.close(fig)
print("Figures written to", OUT)
