"""Build the final review deck from the mid-review deck of batch 4.

The script copies the template (Batch-4_projectppt.pptx) and keeps its slides
1 to 8 (title, members, introduction, problem, objective, time plan, shading
patterns). It updates them for the final review: the title, the status of the
time plan, slide 8 as "Why a Global Search", the date in the footers, and one
slide number per slide. It drops the mid-review results of slide 9 and the
mid-review references of slide 10. The new slides are made from template
slide 8 (navy header): system, methods, Idea C, the worked example, one slide
for each result figure, the summary table, the findings, the limits, the
conclusion and the references of the final methods. Idea C is the main method.

Use:  python build_deck.py <template.pptx>
      (or "bash run.sh deck" from the project folder)
Output: reports/final_review/FinalReview_MPPT.pptx
"""
import copy
import csv
import os
import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FIGS = os.path.join(HERE, "figures")
EXAMPLE = os.path.join(ROOT, "docs", "explainer", "ceiling_example")
OUT = os.path.join(HERE, "FinalReview_MPPT.pptx")
DATE = "DD/MM/2026"            # date of the final review: set here, or in PowerPoint
INK = RGBColor(0x1A, 0x1A, 0x1A)
HEAD = RGBColor(0x14, 0x33, 0x5A)
FONT = "Times New Roman"

# Content area under the subtitle and above the footer: x, y, w, h (EMU)
AREA = (Emu(350520), Emu(1800000), Emu(11490000), Emu(4600000))

# (figure file, slide title, subtitle)
FIG_SLIDES = [
    ("fig_startup_R1", "Start-up on a Shaded Pattern", "Simulink, pattern R1, sensors on. Grey band: global search"),
    ("fig_search_points", "Where Each Search Samples", "Settled samples of each search on the P-V curve of R1"),
    ("fig_startup_stats", "Start-up Accuracy", "99 patterns in Simulink (left), all patterns on the static bench (right)"),
    ("fig_en50530", "EN 50530 Irradiance Ramps", "Dynamic MPPT efficiency against the ramp slope"),
    ("fig_cloud_trace", "Cloud Event", "Power against time on the cloud event with the largest change"),
    ("fig_cloud_stats", "Cloud Events", "40 cloud events from the Oahu data, Simulink"),
    ("fig_day", "Full Days", "One full day of Idea C, and the energy ratio over four days"),
    ("fig_noise", "Sensor Noise", "100 pattern steps that move the global peak, 1 to 30 x sensor noise"),
    ("fig_compute", "Processing Time and Compute Energy", "Compiled controller on one core of the PC"),
]

REFS = [
    "T. L. Nguyen and K.-S. Low, “A global maximum power point tracking scheme employing DIRECT search algorithm "
    "for photovoltaic systems,” IEEE Trans. Ind. Electron., vol. 57, no. 10, pp. 3456–3467, 2010.",
    "D. R. Jones, C. D. Perttunen and B. E. Stuckman, “Lipschitzian optimization without the Lipschitz constant,” "
    "J. Optim. Theory Appl., vol. 79, no. 1, pp. 157–181, 1993.",
    "M. Boztepe et al., “Global MPPT scheme for photovoltaic string inverters based on restricted voltage window "
    "search algorithm,” IEEE Trans. Ind. Electron., vol. 61, no. 7, pp. 3302–3312, 2014.",
    "Y. Wang, Y. Li and X. Ruan, “High-accuracy and fast-speed MPPT methods for PV string under partially shaded "
    "conditions,” IEEE Trans. Ind. Electron., vol. 63, no. 1, pp. 235–245, 2016.",
    "S. A. Piyavskii, “An algorithm for finding the absolute extremum of a function,” USSR Comput. Math. Math. "
    "Phys., vol. 12, no. 4, pp. 57–67, 1972.",
    "B. O. Shubert, “A sequential method seeking the global maximum of a function,” SIAM J. Numer. Anal., vol. 9, "
    "no. 3, pp. 379–388, 1972.",
    "H. Tuy, “Monotonic optimization: problems and solution approaches,” SIAM J. Optim., vol. 11, no. 2, "
    "pp. 464–494, 2000.",
    "W. Li et al., “A Lipschitz optimization-based MPPT algorithm for photovoltaic system under partial shading "
    "condition,” IEEE Access, vol. 7, pp. 126323–126333, 2019.",
    "K. Ishaque, Z. Salam, M. Amjad and S. Mekhilef, “An improved particle swarm optimization (PSO)-based MPPT for "
    "PV with reduced steady-state oscillation,” IEEE Trans. Power Electron., vol. 27, no. 8, pp. 3627–3638, 2012.",
    "S. Mohanty, B. Subudhi and P. K. Ray, “A new MPPT design using grey wolf optimization technique for "
    "photovoltaic system under partial shading conditions,” IEEE Trans. Sustain. Energy, vol. 7, no. 1, "
    "pp. 181–188, 2016.",
    "S. Mirjalili, S. M. Mirjalili and A. Lewis, “Grey wolf optimizer,” Adv. Eng. Softw., vol. 69, pp. 46–61, 2014.",
    "F.-S. Pai, R.-M. Chao, S. H. Ko and T.-S. Lee, “Performance evaluation of parabolic prediction to maximum "
    "power point tracking for PV array,” IEEE Trans. Sustain. Energy, vol. 2, no. 1, pp. 60–68, 2011.",
    "R. P. Brent, Algorithms for Minimization without Derivatives. Englewood Cliffs, NJ, USA: Prentice-Hall, 1973.",
    "D. Sera, R. Teodorescu, J. Hantschel and M. Knoll, “Optimized maximum power point tracker for fast-changing "
    "environmental conditions,” IEEE Trans. Ind. Electron., vol. 55, no. 7, pp. 2629–2637, 2008.",
    "A. M. S. Furtado et al., “A reduced voltage range global maximum power point tracking algorithm for "
    "photovoltaic systems under partial shading conditions,” IEEE Trans. Ind. Electron., vol. 65, no. 4, "
    "pp. 3252–3262, 2018.",
    "E. Koutroulis and F. Blaabjerg, “A new technique for tracking the global maximum power point of PV arrays "
    "operating under partial-shading conditions,” IEEE J. Photovolt., vol. 2, no. 2, pp. 184–190, 2012.",
    "T. Esram and P. L. Chapman, “Comparison of photovoltaic array maximum power point tracking techniques,” "
    "IEEE Trans. Energy Convers., vol. 22, no. 2, pp. 439–449, 2007.",
    "EN 50530: Overall efficiency of grid connected photovoltaic inverters, CENELEC, 2010. Ramp rows as in a "
    "TUV Rheinland test report.",
    "M. Sengupta and A. Andreas, “Oahu Solar Measurement Grid (1-Year Archive): 1-Second Solar Irradiance; Oahu, "
    "Hawaii (Data),” NREL, DA-5500-56506, 2010, doi: 10.5439/1052451.",
    "L. K. Lawrie and D. B. Crawley, “Development of Global Typical Meteorological Years (TMYx),” 2026. "
    "https://climate.onebuilding.org (data set).",
    "Emmvee Photovoltaic Power Pvt. Ltd., “PV module brochure, E325P72,” manufacturer datasheet.",
]


def build_spec():
    """The new slides, in order. Each entry: (kind, title, subtitle, payload)."""
    s = []
    s.append(("table", "System and Test Benches", "One array, one converter, two benches that run the same controller code", (
        [("Item", "Value"),
         ("PV array", "4 × 4 Emmvee E325P72 panels, 5.2 kW, Voc 183.2 V, Isc 36.44 A at STC"),
         ("Converter", "Averaged buck-boost, direct duty control, duty range 0.30 to 0.78"),
         ("Control timing", "One decision each 20 ms, one search test 40 ms"),
         ("Simulink bench", "Simscape Electrical with a sensor model, MATLAB R2025b"),
         ("Static bench", "The same controller code, compiled, on the static I-V curves. Within 0.001 points of "
                          "Simulink on the nine patterns"),
         ("Measure", "Tracking efficiency η = ∫P dt / ∫P_GMPP dt over each test profile")],
        [Emu(2600000), Emu(8890000)])))
    s.append(("table", "Methods Compared", "Five global searches with the same local stage and restart rule. Idea C is the main method", (
        [("Method", "Global search", "After the search"),
         ("Idea C (main)", "Best-first search by the measured ceiling, corner split, certificate stop", "Parabolic stage"),
         ("Idea B", "DIRECT global stage, then the ceiling check of Idea C", "Parabolic stage"),
         ("DIRECT (paper)", "DIRECT on duty, Nguyen and Low 2010", "P&O of the paper"),
         ("PSO", "Particle swarm, 8 particles, Ishaque et al. 2012", "Parabolic stage"),
         ("GWO", "Grey wolf optimizer, 6 wolves, Mohanty et al. 2016", "Parabolic stage"),
         ("Restart rule", "Power change above 5 % when steady (slope over 0.2 s). Off below 260 W. Timer 900 s",
          "All five")],
        [Emu(2200000), Emu(6290000), Emu(3000000)])))
    s.append(("figtext", "Idea C: The Measured Ceiling", "Two measured operating points bound the power of the whole gap between them", (
        os.path.join(EXAMPLE, "3_ceiling_idea.png"),
        ["Two tests at the duties d1 < d2 give (V1, I1) and (V2, I2), with V1 ≥ V2",
         "The array current never rises when the voltage rises, so between them V ≤ V1 and I ≤ I2",
         "Ceiling of the gap: P ≤ V1 · I2",
         "No slope constant, no array model, no datasheet value",
         "Source: Boztepe et al. 2014, Wang et al. 2016"])))
    s.append(("table", "Idea C: Search and Stop", "An implementation of published parts, not a new method", (
        [("Step", "What Idea C does", "Source"),
         ("1", "Test the duties 0.30, 0.54 and 0.78", "First samples as in DIRECT"),
         ("2", "Ceiling of each gap: higher voltage × higher current", "Boztepe 2014, Wang 2016"),
         ("3", "Test the open gap with the highest ceiling first", "Piyavskii 1972, Shubert 1972"),
         ("4", "Test at the corner duty, on the load line through (V1, I2)", "Polyblock step, Tuy 2000"),
         ("5", "Stop when no gap exceeds 1.02 × the best power: certificate", "Monotonic optimization"),
         ("6", "Parabolic stage: refine, hold the voltage, check each 1 s", "Pai 2011, Brent 1973, Sera 2008")],
        [Emu(900000), Emu(6890000), Emu(3700000)])))
    s.append(("fig2", "Worked Example: DIRECT on One Curve",
              "Idealized shaded curve. DIRECT tests regions that cannot win and has no stop rule", (
                  os.path.join(EXAMPLE, "2_direct_tests.png"), os.path.join(EXAMPLE, "5_power_per_test.png"))))
    s.append(("figtext", "Worked Example: How Idea C Stops", "The same curve. Each test goes where the ceiling allows a better point", (
        os.path.join(EXAMPLE, "4_ideac_tests.png"),
        ["After test 6, the left half, with the local peak, closes without a test",
         "After test 9, every gap is closed",
         "Stop at 2508 W, 99.5 % of the peak, with a proof: no point above 2558 W",
         "9 tests and 2.4 test periods of energy lost, against 11 tests, 3.8 and no stop for DIRECT"])))
    for fig, title, sub in FIG_SLIDES:
        s.append(("fig", title, sub, os.path.join(FIGS, fig + ".png")))
    s.append(("summary", "Summary of All Tests", "Best and worst outcome of each test, processing time", None))
    s.append(("table", "Where Idea C Stands", "Final tests of 24 November 2026", (
        [("", "Result"),
         ("Better", "Wrong peak in 1 of 99 Simulink start-ups (DIRECT 26) and in 0.78 % of static start-ups (DIRECT 10.24 %)"),
         ("Better", "Search 0.51 s against 2.4 to 2.6 s for PSO and GWO. Cloud events 98.72 % against 95.66 % and 90.83 %"),
         ("Better", "Four open-sky days: 99.968 % of the GMPP energy, the highest share. 6.4 µJ per search"),
         ("Equal", "Same search time as DIRECT (0.51 s). Cloud events 98.72 % against 98.62 %"),
         ("Weaker", "Simulink loses 0.27 points against the static bench, from the parabolic check"),
         ("Weaker", "Pattern steps: DIRECT 96.9 % against 96.1 %, although DIRECT has twice the wrong peaks")],
        [Emu(1600000), Emu(9890000)])))
    s.append(("bullets", "Limits and Next Steps", "What the results do not yet cover", [
        "#Limits",
        "On slow, deep cloud edges in Simulink, the parabolic check does not settle (0.27 points lost)",
        "Cloud data from one climate (Oahu), days from the typical weather of Vijayawada",
        "The long tests ran on the static bench, and the controller has not run on hardware",
        "#Next steps",
        "Real-time test with hardware in the loop on the OPAL-RT OP5707",
        "Controller code on the TMS320F28379D",
        "Analysis of the parabolic check under slow cloud edges"]))
    s.append(("bullets", "Conclusion", "Idea C: reliable global search at the cost of DIRECT", [
        "Idea C found the GMPP in 98 of 99 Simulink start-ups, DIRECT in 73, with the same search time (0.51 s)",
        "It searched about five times faster than PSO and GWO and kept 3 to 8 points more energy on cloud events",
        "It delivered 99.968 % of the available energy over four open-sky days, with 521 searches",
        "Its stop rule needs no slope constant, no array model and no datasheet value",
        "It is an implementation of published parts: Boztepe 2014, Wang 2016, Piyavskii 1972, Shubert 1972, Tuy 2000"]))
    half = (len(REFS) + 1) // 2
    s.append(("refs", "References (1 of 2)", "Sources of the final methods and data", (REFS[:half], 1)))
    s.append(("refs", "References (2 of 2)", "Sources of the final methods and data", (REFS[half:], half + 1)))
    return s


# ---------------------------------------------------------------- helpers
def set_text(shape, text):
    """Replace the text of a shape and keep the format of its first run."""
    tf = shape.text_frame
    p0 = tf.paragraphs[0]
    r0 = p0.runs[0] if p0.runs else p0.add_run()
    r0.text = text
    for r in p0.runs[1:]:
        r.text = ""
    for p in list(tf.paragraphs[1:]):
        p._p.getparent().remove(p._p)


def replace_para(shape, old, new):
    """Replace the text of the paragraph that contains old, and keep its first run format."""
    for p in shape.text_frame.paragraphs:
        if old in "".join(r.text for r in p.runs):
            p.runs[0].text = new
            for r in p.runs[1:]:
                r.text = ""
            return True
    return False


def all_shapes(shapes):
    for sh in shapes:
        yield sh
        if sh.shape_type == 6:
            yield from all_shapes(sh.shapes)


def find(slide, prefix_text=None, kind=None):
    for sh in slide.shapes:
        if kind == "pic" and sh.shape_type == 13:
            yield sh
        elif kind is None and sh.has_text_frame and prefix_text and sh.text_frame.text.startswith(prefix_text):
            yield sh


def png_size(path):
    import struct
    with open(path, "rb") as f:
        h = f.read(24)
    return struct.unpack(">II", h[16:24])


def add_picture_fit(slide, path, x, y, w, h):
    """Add a picture inside the box (x, y, w, h), centred, with its aspect ratio kept."""
    if not os.path.isfile(path):
        tb = slide.shapes.add_textbox(x, y, w, Emu(400000))
        tb.text_frame.text = f"[Missing figure: {os.path.basename(path)}]"
        return
    pw, ph = png_size(path)
    sc = min(w / pw, h / ph)
    cw, ch = int(pw * sc), int(ph * sc)
    slide.shapes.add_picture(path, x + (w - cw) // 2, y, cw, ch)


def add_bullets(slide, x, y, w, h, items, size=18):
    """A text box with bullet paragraphs. An item that starts with '#' is a bold heading without a bullet."""
    tf = slide.shapes.add_textbox(x, y, w, h).text_frame
    tf.word_wrap = True
    for i, it in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        head = it.startswith("#")
        p.space_before = Pt(10 if head and i else 6)
        r = p.add_run()
        r.text = it[1:] if head else it
        r.font.size = Pt(size)
        r.font.name = FONT
        r.font.bold = head
        r.font.color.rgb = HEAD if head else INK
        if not head:
            ppr = p._p.get_or_add_pPr()
            ppr.set("marL", "285750")
            ppr.set("indent", "-285750")
            ppr.append(ppr.makeelement(qn("a:buChar"), {"char": "•"}))


def add_table(slide, rows, area, widths, size=None):
    x, y, w, h = area
    nr, nc = len(rows), len(rows[0])
    tb = slide.shapes.add_table(nr, nc, x, y, sum(widths), Emu(380000) * nr).table
    for j, cw in enumerate(widths):
        tb.columns[j].width = cw
    fs = size or (14 if nc <= 3 else 12)
    for i, r in enumerate(rows):
        for j, v in enumerate(r):
            c = tb.cell(i, j)
            c.text = str(v)
            for p in c.text_frame.paragraphs:
                for rn in p.runs:
                    rn.font.size = Pt(fs)
                    rn.font.name = FONT
                    rn.font.bold = i == 0
                    if i == 0:
                        rn.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            if i == 0:
                c.fill.solid()
                c.fill.fore_color.rgb = HEAD


def copy_slide(prs, src):
    """Add a copy of slide src at the end, with its text shapes but without its pictures."""
    new = prs.slides.add_slide(src.slide_layout)
    tree = new.shapes._spTree
    for sh in list(new.shapes):
        tree.remove(sh._element)
    for el in src.shapes._spTree.iterchildren():
        tag = el.tag.split("}")[1]
        if tag in ("sp", "cxnSp", "graphicFrame", "grpSp"):
            tree.append(copy.deepcopy(el))
    return new


def delete_slide(prs, index):
    sld_ids = prs.slides._sldIdLst
    el = list(sld_ids)[index]
    prs.part.drop_rel(el.rId)
    sld_ids.remove(el)


def summary_rows():
    sp = os.path.join(FIGS, "summary.csv")
    if not os.path.isfile(sp):
        return None
    with open(sp, newline="", encoding="utf-8") as f:
        R = list(csv.DictReader(f))

    def g(r, k, n=2):
        try:
            return f"{float(r[k]):.{n}f}"
        except (KeyError, ValueError):
            return "-"
    rows = [("Search", "Start-up mean / worst %", "Wrong of 99", "Ramps %", "Clouds mean / worst %",
             "Worst day %", "Search s", "µs per decision", "µJ per search")]
    for r in R:
        rows.append((r["Search"].replace(" + Parabolic", ""), g(r, "p1c_mean_pct", 3) + " / " + g(r, "p1c_worst_pct"),
                     g(r, "p1c_wrong_of_99", 0), g(r, "p2_mean_pct"), g(r, "p3_mean_pct") + " / " + g(r, "p3_worst_pct"),
                     g(r, "p4_worst_day_pct", 3), g(r, "search_time_s"), g(r, "us_per_decision", 3),
                     g(r, "uJ_per_search", 1)))
    return rows


# ---------------------------------------------------------------- main
def main():
    if len(sys.argv) < 2:
        sys.exit("Use: python build_deck.py <template.pptx>")
    prs = Presentation(sys.argv[1])
    spec = build_spec()

    # 1. Structure first: copy template slide 8 for each new slide, then drop
    #    template slides 9 (mid-review results) and 10 (mid-review references).
    src = prs.slides[7]
    new = [copy_slide(prs, src) for _ in spec]
    delete_slide(prs, 9)
    delete_slide(prs, 8)

    # 2. Template slides 1, 7 and 8, updated for the final review.
    s1 = prs.slides[0]
    for sh in all_shapes(s1.shapes):
        if sh.has_text_frame:
            replace_para(sh, "(B.Tech. Project Presentation)", "(B.Tech. Project Presentation, Final Review)")
            replace_para(sh, "SEPTEMBER 2026", DATE)
    s7 = prs.slides[6]
    for sh in all_shapes(s7.shapes):
        if sh.has_text_frame:
            replace_para(sh, "Status at Review-I", "Status at the final review")
            replace_para(sh, "PV array simulations completed",
                         "Five global searches implemented and compared in Simulink and on a static bench "
                         "(final tests of 24 Nov 2026). Idea C selected as the main method. Next: hardware validation.")
            replace_para(sh, "Mid review", "B.Tech Project Presentation, Final Review")
    def subtitle(slide, text):
        # The subtitle box of template slide 8 is as wide as the slide but starts at x = 0.5 M,
        # so long text ran past the edge. Keep it inside the slide and let it wrap.
        sh = next(find(slide, "4×4 PV Array"))
        set_text(sh, text)
        sh.width = Emu(11300000)
        sh.text_frame.word_wrap = True

    s8 = prs.slides[7]
    set_text(next(find(s8, "Simulink Simulations")), "Why a Global Search")
    subtitle(s8, "Partial shading gives several peaks. On pattern R1, P&O and INC stop at 35 % of the GMPP power")

    # 3. The new slides.
    x, y, w, h = AREA
    for s, (kind, title, sub, pay) in zip(new, spec):
        set_text(next(find(s, "Simulink Simulations")), title)
        subtitle(s, sub)
        if kind == "fig":
            add_picture_fit(s, pay, x, y, w, h)
        elif kind == "fig2":
            half = (w - Emu(200000)) // 2
            add_picture_fit(s, pay[0], x, y, half, h)
            add_picture_fit(s, pay[1], x + half + Emu(200000), y, half, h)
        elif kind == "figtext":
            fw = int(w * 0.56)
            add_picture_fit(s, pay[0], x, y, fw, h)
            add_bullets(s, x + fw + Emu(250000), y, w - fw - Emu(250000), h, pay[1], size=17)
        elif kind == "table":
            add_table(s, pay[0], AREA, pay[1])
        elif kind == "summary":
            rows = summary_rows()
            if rows:
                add_table(s, rows, AREA, [Emu(1650000)] + [Emu(1230000)] * 8)
        elif kind == "bullets":
            add_bullets(s, x, y, w, h, pay, size=20)
        elif kind == "refs":
            refs, start = pay
            tf = s.shapes.add_textbox(x, Emu(1650000), w, Emu(4750000)).text_frame
            tf.word_wrap = True
            for i, r in enumerate(refs):
                p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
                p.space_before = Pt(3)
                rn = p.add_run()
                rn.text = f"[{start + i}] {r}"
                rn.font.size = Pt(13)
                rn.font.name = FONT
                rn.font.color.rgb = INK

    # 4. Footers on every slide: the date, and one slide number (the template had
    #    a slide-number field and a typed copy of the number in the same box).
    for i, s in enumerate(prs.slides, 1):
        for sh in all_shapes(s.shapes):
            if not sh.has_text_frame:
                continue
            for p in sh.text_frame.paragraphs:
                joined = "".join(r.text for r in p.runs)     # the template splits the date over several runs
                if "30/09/2026" in joined:
                    p.runs[0].text = joined.replace("30/09/2026", DATE)
                    for r in p.runs[1:]:
                        r.text = ""
                flds = [f for f in p._p.findall(qn("a:fld")) if f.get("type") == "slidenum"]
                if flds:
                    for r in p._p.findall(qn("a:r")):
                        p._p.remove(r)
                    for f in flds:
                        t = f.find(qn("a:t"))
                        if t is not None:
                            t.text = str(i)
    prs.save(OUT)
    print(f"Saved {OUT} ({len(prs.slides)} slides)")


if __name__ == "__main__":
    main()
