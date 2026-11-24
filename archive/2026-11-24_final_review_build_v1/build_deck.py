"""Build the final review deck from the mid-review deck of batch 4.

The script copies the template (Batch-4_projectppt.pptx), keeps its slides 1
to 9 (title, members, introduction, problem, objective, time plan, mid-review
results), adds one slide for each result figure of reports/final_review/figures
(made from template slide 8, the slide with the navy header), a summary table,
a conclusion slide for the team to fill, and the references slide of the
template at the end. The text on the new slides is the bare minimum.

Use:  python build_deck.py <template.pptx>
      (or "bash run.sh deck" from the project folder)
Output: reports/final_review/FinalReview_MPPT.pptx
"""
import copy
import csv
import os
import sys

from pptx import Presentation
from pptx.util import Emu, Pt
from pptx.dml.color import RGBColor

HERE = os.path.dirname(os.path.abspath(__file__))
FIGS = os.path.join(HERE, "figures")
OUT = os.path.join(HERE, "FinalReview_MPPT.pptx")
NAVY = RGBColor(0x1F, 0x4E, 0x79)

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


def main():
    if len(sys.argv) < 2:
        sys.exit("Use: python build_deck.py <template.pptx>")
    template = sys.argv[1]

    # 1. Structure: copy slide 8 (figure layout) for each new slide, before any edit.
    prs = Presentation(template)
    tmpl_n = len(prs.slides)
    n_new = len(FIG_SLIDES) + 3          # figures, methods, summary, conclusion
    src = prs.slides[7]
    for k in range(n_new):
        copy_slide(prs, src)
    slides = list(prs.slides)
    new = slides[tmpl_n:]
    # Move the references slide (template slide 10) to the end.
    sld_ids = prs.slides._sldIdLst
    ref = list(sld_ids)[tmpl_n - 1]
    sld_ids.remove(ref)
    sld_ids.append(ref)

    # Order of the new slides: methods, figures, summary, conclusion.
    titles = ["Methods Compared"] + [f[1] for f in FIG_SLIDES] + ["Summary of All Tests", "Conclusion"]
    subs = (["Five global searches with the same local stage and restart rule"] + [f[2] for f in FIG_SLIDES]
            + ["Best and worst outcome of each test, processing time", "[To be written.]"])
    figs = [None] + [f[0] for f in FIG_SLIDES] + [None, None]

    W, H = prs.slide_width, prs.slide_height
    area = (Emu(350520), Emu(1800000), Emu(11490000), Emu(4600000))   # x, y, w, h of the content
    for s, t, sub, fig in zip(new, titles, subs, figs):
        for sh in list(find(s, kind="pic")):
            sh._element.getparent().remove(sh._element)
        set_text(next(find(s, "Simulink Simulations")), t)
        set_text(next(find(s, "4×4 PV Array")), sub)
        if fig:
            path = os.path.join(FIGS, fig + ".png")
            if os.path.isfile(path):
                w, h = png_size(path)
                sc = min(area[2] / w, area[3] / h)
                pw, ph = int(w * sc), int(h * sc)
                s.shapes.add_picture(path, area[0] + (area[2] - pw) // 2, area[1], pw, ph)

    # Methods slide: a table.
    rows = [("Method", "Global search", "After the search"),
            ("DIRECT (paper)", "Lipschitz search on duty, Nguyen and Low 2010", "P&O of the paper"),
            ("Idea B", "DIRECT, then a ceiling check with a corner split", "Parabolic stage"),
            ("Idea C (final)", "Bisection that the measured ceiling guides", "Parabolic stage"),
            ("PSO", "Particle swarm, Ishaque et al. 2012", "Parabolic stage"),
            ("GWO", "Grey wolf optimizer, Mohanty et al. 2016", "Parabolic stage"),
            ("Restart rule", "Power differs by > 5 % from the power after the search, tested when the slope "
             "over 0.2 s is < 1 %/s; timer 900 s", "All five")]
    add_table(new[0], rows, area, [Emu(2200000), Emu(6290000), Emu(3000000)])

    # Summary slide: from figures/summary.csv.
    sp = os.path.join(FIGS, "summary.csv")
    if os.path.isfile(sp):
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
        add_table(new[-2], rows, area, [Emu(1650000)] + [Emu(1230000)] * 8)

    # Slide numbers in the footers of the new slides and the references slide.
    for i, s in enumerate(prs.slides, 1):
        for sh in s.shapes:
            if sh.has_text_frame and sh.top > Emu(6400000) and sh.left > Emu(8000000) and sh.text_frame.text.strip().isdigit():
                set_text(sh, str(i))
    prs.save(OUT)
    print(f"Saved {OUT} ({len(prs.slides)} slides)")


def copy_slide(prs, src):
    """Add a copy of slide src at the end, with its text shapes but without its pictures.

    The new slide uses the layout of src. The function removes the placeholders
    of the layout and copies the shape elements of src. Pictures need links to
    their image parts, so the function does not copy them (the new slides get
    their own figures).
    """
    new = prs.slides.add_slide(src.slide_layout)
    tree = new.shapes._spTree
    for sh in list(new.shapes):
        tree.remove(sh._element)
    for el in src.shapes._spTree.iterchildren():
        tag = el.tag.split("}")[1]
        if tag in ("sp", "cxnSp", "graphicFrame", "grpSp"):
            tree.append(copy.deepcopy(el))
    return new


def add_table(slide, rows, area, widths):
    x, y, w, h = area
    nr, nc = len(rows), len(rows[0])
    tb = slide.shapes.add_table(nr, nc, x, y, sum(widths), Emu(380000) * nr).table
    for j, cw in enumerate(widths):
        tb.columns[j].width = cw
    for i, r in enumerate(rows):
        for j, v in enumerate(r):
            c = tb.cell(i, j)
            c.text = str(v)
            for p in c.text_frame.paragraphs:
                for rn in p.runs:
                    rn.font.size = Pt(14 if nc <= 3 else 12)
                    rn.font.name = "Times New Roman"
                    rn.font.bold = i == 0
                    if i == 0:
                        rn.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            if i == 0:
                c.fill.solid()
                c.fill.fore_color.rgb = RGBColor(0x14, 0x33, 0x5A)


if __name__ == "__main__":
    main()
