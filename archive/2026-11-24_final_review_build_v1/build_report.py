"""Build the final report (Word, IEEE A4 two-column) of the final review.

The script takes the format (styles, page, columns, author block) from the
EE420 mini project report and writes reports/final_review/FinalReport_MPPT.docx.
It puts in the figures of reports/final_review/figures and the summary table
figures/summary.csv (make_figures.m writes both). The text is the bare
minimum: the system values, the methods with their sources, the tests, the
figures and the tables. The team writes the abstract, the introduction, the
discussion and the conclusion in the places marked [To be written].

Use:  python build_report.py
"""
import csv
import os
import re
import struct
import zipfile
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
TEMPLATE = os.path.join(ROOT, "reports", "mini_project_EE420", "MiniProject_EE420_Report_PO_INC.docx")
FIGS = os.path.join(HERE, "figures")
OUT = os.path.join(HERE, "FinalReport_MPPT.docx")

TITLE = ("Global Maximum Power Point Tracking of a Partially Shaded Four-by-Four "
         "Photovoltaic Array: Comparison of Five Global Searches")
SUBTITLE = "B.Tech. project report, EE449 Major Project-A, A.Y. 2026-27"
TBD = "[To be written.]"

COL_EMU = 3098800       # one column: (11906 - 2 x 893 - 360) / 2 twips
PAGE_EMU = 6426200      # full text width: 11906 - 2 x 893 twips
EMU_PER_TWIP = 635


# ---------------------------------------------------------------- XML parts
def run(text, bold=False, italic=False, size=None):
    rpr = ""
    if bold:
        rpr += "<w:b/><w:bCs/>"
    if italic:
        rpr += "<w:i/><w:iCs/>"
    if size:
        rpr += f'<w:sz w:val="{size}"/><w:szCs w:val="{size}"/>'
    rpr = f"<w:rPr>{rpr}</w:rPr>" if rpr else ""
    return f'<w:r>{rpr}<w:t xml:space="preserve">{escape(text)}</w:t></w:r>'


def para(style, *runs, keep_next=False, align=None):
    ppr = f'<w:pStyle w:val="{style}"/>'
    if keep_next:
        ppr += "<w:keepNext/>"
    if align:
        ppr += f'<w:jc w:val="{align}"/>'
    body = "".join(r if r.startswith("<w:r>") else run(r) for r in runs)
    return f"<w:p><w:pPr>{ppr}</w:pPr>{body}</w:p>"


def body(text):
    return para("BodyText", text)


def h1(text):
    return para("Heading1", text)


def h2(text):
    return para("Heading2", text)


def bullet(text):
    return para("bulletlist", text)


def table(head, rows, title, widths):
    """IEEE table: caption above (style tablehead), heads in tablecolhead, cells in tablecopy."""
    tw = sum(widths)
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    border = ('<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders>')

    def cell(text, w, style):
        return (f'<w:tc><w:tcPr><w:tcW w:w="{w}" w:type="dxa"/></w:tcPr>'
                f'<w:p><w:pPr><w:pStyle w:val="{style}"/></w:pPr>{run(text)}</w:p></w:tc>')

    xml = para("tablehead", title, keep_next=True)
    xml += (f'<w:tbl><w:tblPr><w:tblW w:w="{tw}" w:type="dxa"/><w:jc w:val="center"/>{border}'
            f'<w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>{grid}</w:tblGrid>')
    xml += "<w:tr>" + "".join(cell(h, w, "tablecolhead") for h, w in zip(head, widths)) + "</w:tr>"
    for r in rows:
        xml += "<w:tr>" + "".join(cell(str(c), w, "tablecopy") for c, w in zip(r, widths)) + "</w:tr>"
    xml += "</w:tbl>" + para("BodyText", "")
    return xml


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


class Doc:
    def __init__(self):
        self.parts = []
        self.media = []       # (rid, file name, source path)
        self.nfig = 0

    def add(self, xml):
        self.parts.append(xml)

    def figure(self, name, caption, wide=True):
        path = os.path.join(FIGS, name + ".png")
        self.nfig += 1
        rid = f"rIdFR{self.nfig}"
        if not os.path.isfile(path):
            self.add(para("BodyText", run(f"[Figure {name}.png is missing: run make_figures.m.]", italic=True)))
        else:
            self.media.append((rid, f"fr{self.nfig}.png", path))
            w, h = png_size(path)
            cx = PAGE_EMU if wide else COL_EMU
            cy = int(cx * h / w)
            pic = (f'<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
                   f'<wp:extent cx="{cx}" cy="{cy}"/><wp:docPr id="{900 + self.nfig}" name="Figure {self.nfig}"/>'
                   f'<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
                   f'<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
                   f'<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                   f'<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
                   f'<pic:nvPicPr><pic:cNvPr id="{900 + self.nfig}" name="fr{self.nfig}.png"/><pic:cNvPicPr/></pic:nvPicPr>'
                   f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
                   f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm>'
                   f'<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic>'
                   f'</wp:inline></w:drawing></w:r>')
            fig = f'<w:p><w:pPr><w:keepNext/><w:jc w:val="center"/></w:pPr>{pic}</w:p>'
            cap = para("figurecaption", caption)
            if wide:
                # One-column section for a figure across the page, then back to two columns.
                self.add(SECT_2COL)
                self.add(fig + cap)
                self.add(SECT_1COL)
            else:
                self.add(fig + cap)


def sect(cols):
    c = '<w:cols w:num="2" w:space="360"/>' if cols == 2 else '<w:cols w:space="720"/>'
    return ('<w:p><w:pPr><w:spacing w:before="0" w:after="0"/><w:sectPr><w:type w:val="continuous"/>'
            '<w:pgSz w:w="11906" w:h="16838" w:code="9"/><w:pgMar w:top="1080" w:right="893" w:bottom="1440" '
            f'w:left="893" w:header="720" w:footer="720" w:gutter="0"/>{c}<w:docGrid w:linePitch="360"/>'
            '</w:sectPr></w:pPr></w:p>')


SECT_2COL = sect(2)   # ends a section with two columns
SECT_1COL = sect(1)   # ends a section with one column


def read_summary():
    path = os.path.join(FIGS, "summary.csv")
    if not os.path.isfile(path):
        return None
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


# ---------------------------------------------------------------- content
def content(d):
    d.add(para("Abstract", run("Abstract", bold=True, italic=True), run("—" + TBD, bold=True)))
    d.add(para("Keywords", run("Keywords—", italic=True, bold=True),
               run("maximum power point tracking, partial shading, global search, DIRECT, particle swarm "
                   "optimization, grey wolf optimizer, EN 50530", italic=True, bold=True)))

    d.add(h1("Introduction"))
    d.add(body(TBD))

    d.add(h1("System Model"))
    d.add(table(["Item", "Value"], [
        ["PV panel", "Emmvee E325P72 [17]: 325 W, 72 cells, 3 bypass diodes"],
        ["Array", "4 panels in series x 4 strings; Voc 183.2 V, Isc 36.44 A at STC"],
        ["Converter", "Averaged buck-boost, direct duty control, R_load 10 Ω, C_in 220 µF"],
        ["Control timing", "Sample 50 µs (20 kHz), MPPT period 20 ms, search probe 40 ms"],
        ["Search range", "Duty 0.30 to 0.78"],
        ["Sensors", "AMC1311 (voltage), LEM LA 55-P (current), 12-bit ADC (TMS320F28379D)"],
        ["Software", "MATLAB R2025b, Simulink, Simscape Electrical"],
    ], "System values", [1500, 3366]))
    d.add(body(TBD))

    d.add(h1("Tracking Methods"))
    d.add(table(["Method", "Search", "Source"], [
        ["DIRECT (paper)", "Lipschitz search on duty; P&O ending of the paper", "[1]"],
        ["Idea B", "DIRECT stage, then a ceiling check with a corner split", "[1], [5], [6], [12]"],
        ["Idea C", "Bisection that the measured ceiling guides", "[5], [6], [13], [14]"],
        ["PSO", "Particle swarm on duty", "[2]"],
        ["GWO", "Grey wolf optimizer on duty", "[3], [4]"],
        ["P&O, INC", "Hill climbing from start-up, no global search", "[16]"],
    ], "Global searches", [1000, 2566, 1300]))
    d.add(body("Ideas B and C are implementations of published parts, not new methods. After each search, "
               "Idea B, Idea C, PSO and GWO hand over to the same parabolic local stage [7], [8], [9]."))
    d.add(table(["Part", "Rule", "Source"], [
        ["Level test", "New search if |P − P_ref| > 5 % of P_ref", "[6], [10]"],
        ["Steady test", "Slope of a line fit over 10 periods (0.2 s) at most 1 %/s", "[5]"],
        ["Voltage hold", "Hold the voltage of the peak between checks", "[5], [10]"],
        ["Timer", "New search after 900 s of tracking", "[6], [11]"],
    ], "Restart rule", [1100, 2766, 1000]))
    d.add(body(TBD))

    d.add(h1("Test Plan"))
    d.add(table(["Phase", "Test", "Bench"], [
        ["1b", "Start-up on all patterns, 25 °C and 45 °C, sensors on and off", "Static"],
        ["1c", "Start-up on 99 patterns", "Simulink"],
        ["2", "EN 50530 irradiance ramps on P0 and R1 [15]", "Static, Simulink"],
        ["3", "40 cloud events from the Oahu data [18]", "Simulink"],
        ["3n", "100 pattern steps under 1 to 30 x sensor noise", "Static"],
        ["4", "Four full days, weather of Vijayawada [19], clouds from [18], open sky and morning shade", "Static"],
        ["compute", "Time of one decision of the compiled controller", "PC"],
    ], "Test phases", [800, 3066, 1000]))
    d.add(body("Limits of the tests. EN 50530 defines the ramps for an array with no shade, so the ramps on "
               "R1 go beyond the standard. The start-up and shut-down test (Annex B.4) and the static MPPT "
               "efficiency test of EN 50530 were not run. The 1 x sensor noise has only the datasheet noise of "
               "the sensors and the ADC. The converter model is averaged and has no switching ripple, so the "
               "10 x and 30 x levels stand for the noise of real hardware. The processing time was measured "
               "on a PC, not on the target controller (TMS320F28379D)."))
    d.add(body(TBD))

    d.add(h1("Results"))
    d.figure("fig_pv_patterns", "P-V curves of the nine shading patterns at 25 °C. Filled dot: global peak.")
    d.figure("fig_startup_R1", "Start-up on pattern R1, Simulink, sensors on. Grey band: global search.")
    d.figure("fig_search_points", "Samples of each global search on the P-V curve of R1.")
    d.figure("fig_startup_stats", "Start-up accuracy. Left: 99 patterns in Simulink. Right: all patterns, static bench.")
    d.figure("fig_en50530", "Dynamic MPPT efficiency on the EN 50530 ramps.")
    d.figure("fig_cloud_trace", "Power against time on the cloud event with the largest change.")
    d.figure("fig_cloud_stats", "Efficiency and recovery time on the 40 cloud events, Simulink.")
    d.figure("fig_day", "One full day of Idea C, and the energy ratio over four days.")
    d.figure("fig_noise", "Pattern steps that move the global peak, under sensor noise.")
    d.figure("fig_compute", "Execution time of one decision and compute energy of one search.")
    rows = read_summary()
    if rows:
        def f(r, k, n=2):
            try:
                return f"{float(r[k]):.{n}f}"
            except (KeyError, ValueError):
                return "-"
        d.add(table(["Search", "Start-up mean/worst (%)", "Wrong of 99", "Ramps mean (%)",
                     "Clouds mean/worst (%)", "Days worst (%)", "Search (s)", "µs/dec."],
                    [[r["Search"].replace(" + Parabolic", ""),
                      f(r, "p1c_mean_pct", 3) + " / " + f(r, "p1c_worst_pct"), f(r, "p1c_wrong_of_99", 0),
                      f(r, "p2_mean_pct"), f(r, "p3_mean_pct") + " / " + f(r, "p3_worst_pct"),
                      f(r, "p4_worst_day_pct", 3), f(r, "search_time_s"), f(r, "us_per_decision", 3)]
                     for r in rows],
                    "Summary of the final tests", [900, 900, 500, 600, 900, 600, 500, 500]))
    else:
        d.add(body("[Summary table: run make_figures.m.]"))
    d.add(body(TBD))

    d.add(h1("Conclusion"))
    d.add(body(TBD))

    d.add(h1("References"))
    refs = [
        "T. L. Nguyen and K.-S. Low, “A global maximum power point tracking scheme employing DIRECT search "
        "algorithm for photovoltaic systems,” IEEE Trans. Ind. Electron., vol. 57, no. 10, pp. 3456–3467, 2010.",
        "K. Ishaque, Z. Salam, M. Amjad and S. Mekhilef, “An improved particle swarm optimization (PSO)-based "
        "MPPT for PV with reduced steady-state oscillation,” IEEE Trans. Power Electron., vol. 27, no. 8, "
        "pp. 3627–3638, 2012.",
        "S. Mohanty, B. Subudhi and P. K. Ray, “A new MPPT design using grey wolf optimization technique for "
        "photovoltaic system under partial shading conditions,” IEEE Trans. Sustain. Energy, vol. 7, no. 1, "
        "pp. 181–188, 2016.",
        "S. Mirjalili, S. M. Mirjalili and A. Lewis, “Grey wolf optimizer,” Adv. Eng. Softw., vol. 69, "
        "pp. 46–61, 2014.",
        "M. Boztepe et al., “Global MPPT scheme for photovoltaic string inverters based on restricted voltage "
        "window search algorithm,” IEEE Trans. Ind. Electron., vol. 61, no. 7, pp. 3302–3312, 2014.",
        "Y. Wang, Y. Li and X. Ruan, “High-accuracy and fast-speed MPPT methods for PV string under partially "
        "shaded conditions,” IEEE Trans. Ind. Electron., vol. 63, no. 1, pp. 235–245, 2016.",
        "F.-S. Pai, R.-M. Chao, S. H. Ko and T.-S. Lee, “Performance evaluation of parabolic prediction to "
        "maximum power point tracking for PV array,” IEEE Trans. Sustain. Energy, vol. 2, no. 1, pp. 60–68, 2011.",
        "R. P. Brent, Algorithms for Minimization without Derivatives. Englewood Cliffs, NJ, USA: Prentice-Hall, 1973.",
        "D. Sera, R. Teodorescu, J. Hantschel and M. Knoll, “Optimized maximum power point tracker for "
        "fast-changing environmental conditions,” IEEE Trans. Ind. Electron., vol. 55, no. 7, pp. 2629–2637, 2008.",
        "A. M. S. Furtado et al., “A reduced voltage range global maximum power point tracking algorithm for "
        "photovoltaic systems under partial shading conditions,” IEEE Trans. Ind. Electron., vol. 65, no. 4, "
        "pp. 3252–3262, 2018.",
        "E. Koutroulis and F. Blaabjerg, “A new technique for tracking the global maximum power point of PV "
        "arrays operating under partial-shading conditions,” IEEE J. Photovolt., vol. 2, no. 2, pp. 184–190, 2012.",
        "H. Tuy, “Monotonic optimization: problems and solution approaches,” SIAM J. Optim., vol. 11, "
        "no. 2, pp. 464–494, 2000.",
        "S. A. Piyavskii, “An algorithm for finding the absolute extremum of a function,” USSR Comput. "
        "Math. Math. Phys., vol. 12, no. 4, pp. 57–67, 1972.",
        "B. O. Shubert, “A sequential method seeking the global maximum of a function,” SIAM J. Numer. "
        "Anal., vol. 9, no. 3, pp. 379–388, 1972.",
        "EN 50530: Overall efficiency of grid connected photovoltaic inverters, CENELEC, 2010. Ramp rows as "
        "in a TUV Rheinland test report.",
        "T. Esram and P. L. Chapman, “Comparison of photovoltaic array maximum power point tracking "
        "techniques,” IEEE Trans. Energy Convers., vol. 22, no. 2, pp. 439–449, 2007.",
        "Emmvee Photovoltaic Power Pvt. Ltd., “PV module brochure, E325P72,” manufacturer datasheet. "
        "(Not a peer-reviewed source.)",
        "M. Sengupta and A. Andreas, “Oahu Solar Measurement Grid (1-Year Archive): 1-Second Solar "
        "Irradiance; Oahu, Hawaii (Data),” National Renewable Energy Laboratory, DA-5500-56506, 2010, "
        "doi: 10.5439/1052451. License: Creative Commons Attribution 4.0.",
        "L. K. Lawrie and D. B. Crawley, “Development of Global Typical Meteorological Years (TMYx),” "
        "2026. [Online]. Available: https://climate.onebuilding.org. File: Gannavaram-Vijayawada, "
        "WMO 431810, TMYx 2011–2025. (Data set, not a peer-reviewed source.)",
    ]
    for i, r in enumerate(refs, 1):
        d.add(para("references", f"[{i}] " + r))


# ---------------------------------------------------------------- assemble
def main():
    zin = zipfile.ZipFile(TEMPLATE)
    doc = zin.read("word/document.xml").decode("utf-8")
    rels = zin.read("word/_rels/document.xml.rels").decode("utf-8")

    b = doc.index("<w:body>") + len("<w:body>")
    sects = [m.end() for m in re.finditer(r"</w:sectPr></w:pPr></w:p>", doc)]
    head_end = sects[2]                      # title, author block (3 columns), spacer
    head = doc[:head_end]
    head = head.replace("Tracking Performance of Perturb and Observe and Incremental Conductance on a "
                        "Four-by-Four Photovoltaic Array under Partial Shading", escape(TITLE))
    head = head.replace("Mini project report, EE420 Microgrids and Smart Grids, A.Y. 2026-27", escape(SUBTITLE))
    final_sect = doc[doc.rindex("<w:sectPr"):doc.rindex("</w:body>")]

    d = Doc()
    content(d)
    xml = head + "".join(d.parts) + SECT_2COL + final_sect + "</w:body></w:document>"

    # Relationships: drop the figures of the template, add the new ones.
    rels = re.sub(r'<Relationship Id="rIdFig\d+"[^>]*/>', "", rels)
    new = "".join(f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/'
                  f'relationships/image" Target="media/{fn}"/>' for rid, fn, _ in d.media)
    rels = rels.replace("</Relationships>", new + "</Relationships>")

    tmp = OUT + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            n = item.filename
            if n.endswith("/") or n.startswith("word/media/fig"):
                continue
            if n == "word/document.xml":
                zout.writestr(n, xml)
            elif n == "word/_rels/document.xml.rels":
                zout.writestr(n, rels)
            else:
                zout.writestr(item, zin.read(n))
        for _, fn, path in d.media:
            zout.write(path, "word/media/" + fn)
    os.replace(tmp, OUT)
    print(f"Saved {OUT} ({d.nfig} figures)")


if __name__ == "__main__":
    main()
