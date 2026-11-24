"""Build the final report (Word, IEEE A4 two-column) of the final review.

The script takes the format (styles, page, columns, author block) from the
EE420 mini project report and writes reports/final_review/FinalReport_MPPT.docx.
It puts in the figures of reports/final_review/figures and the summary table
figures/summary.csv (make_figures.m writes both). The text is a full draft
(2026-11-24) with Idea C as the main method, for the team to edit. The
references are numbered in the order of their first citation (cite()).

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
    """IEEE table: caption above (style tablehead), heads in tablecolhead, cells in tablecopy.

    Each row keeps with the next row and does not split, so a table stays in one column.
    """
    tw = sum(widths)
    grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
    border = ('<w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
              '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders>')

    def cell(text, w, style, keep=True):
        kn = "<w:keepNext/>" if keep else ""
        return (f'<w:tc><w:tcPr><w:tcW w:w="{w}" w:type="dxa"/></w:tcPr>'
                f'<w:p><w:pPr><w:pStyle w:val="{style}"/>{kn}</w:pPr>{run(text)}</w:p></w:tc>')

    xml = para("tablehead", title, keep_next=True)
    xml += (f'<w:tbl><w:tblPr><w:tblW w:w="{tw}" w:type="dxa"/><w:jc w:val="center"/>{border}'
            f'<w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>{grid}</w:tblGrid>')
    tr = "<w:tr><w:trPr><w:cantSplit/></w:trPr>"
    xml += tr + "".join(cell(h, w, "tablecolhead") for h, w in zip(head, widths)) + "</w:tr>"
    for i, r in enumerate(rows):
        last = i == len(rows) - 1
        xml += tr + "".join(cell(str(c), w, "tablecopy", keep=not last) for c, w in zip(r, widths)) + "</w:tr>"
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

    def add(self, xml, wide=False):
        if wide:
            # One-column section across the page, then back to two columns.
            self.parts += [SECT_2COL, xml, SECT_1COL]
        else:
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


# ---------------------------------------------------------------- references
# Each source has a key. cite() numbers the sources in the order of their first
# use in the text, as the IEEE style asks, and the reference list follows that order.
REFS = {
    "esram": "T. Esram and P. L. Chapman, “Comparison of photovoltaic array maximum power point tracking "
             "techniques,” IEEE Trans. Energy Convers., vol. 22, no. 2, pp. 439–449, 2007.",
    "ishaque": "K. Ishaque, Z. Salam, M. Amjad and S. Mekhilef, “An improved particle swarm optimization (PSO)-based "
               "MPPT for PV with reduced steady-state oscillation,” IEEE Trans. Power Electron., vol. 27, no. 8, "
               "pp. 3627–3638, 2012.",
    "mohanty": "S. Mohanty, B. Subudhi and P. K. Ray, “A new MPPT design using grey wolf optimization technique for "
               "photovoltaic system under partial shading conditions,” IEEE Trans. Sustain. Energy, vol. 7, no. 1, "
               "pp. 181–188, 2016.",
    "mirjalili": "S. Mirjalili, S. M. Mirjalili and A. Lewis, “Grey wolf optimizer,” Adv. Eng. Softw., vol. 69, "
                 "pp. 46–61, 2014.",
    "jones": "D. R. Jones, C. D. Perttunen and B. E. Stuckman, “Lipschitzian optimization without the Lipschitz "
             "constant,” J. Optim. Theory Appl., vol. 79, no. 1, pp. 157–181, 1993.",
    "nguyen": "T. L. Nguyen and K.-S. Low, “A global maximum power point tracking scheme employing DIRECT search "
              "algorithm for photovoltaic systems,” IEEE Trans. Ind. Electron., vol. 57, no. 10, pp. 3456–3467, 2010.",
    "lipo": "W. Li, G. Zhang, T. Pan, Z. Zhang, Y. Geng and J. Wang, “A Lipschitz optimization-based MPPT algorithm "
            "for photovoltaic system under partial shading condition,” IEEE Access, vol. 7, pp. 126323–126333, 2019.",
    "boztepe": "M. Boztepe et al., “Global MPPT scheme for photovoltaic string inverters based on restricted voltage "
               "window search algorithm,” IEEE Trans. Ind. Electron., vol. 61, no. 7, pp. 3302–3312, 2014.",
    "wang": "Y. Wang, Y. Li and X. Ruan, “High-accuracy and fast-speed MPPT methods for PV string under partially "
            "shaded conditions,” IEEE Trans. Ind. Electron., vol. 63, no. 1, pp. 235–245, 2016.",
    "piyavskii": "S. A. Piyavskii, “An algorithm for finding the absolute extremum of a function,” USSR Comput. "
                 "Math. Math. Phys., vol. 12, no. 4, pp. 57–67, 1972.",
    "shubert": "B. O. Shubert, “A sequential method seeking the global maximum of a function,” SIAM J. Numer. "
               "Anal., vol. 9, no. 3, pp. 379–388, 1972.",
    "tuy": "H. Tuy, “Monotonic optimization: problems and solution approaches,” SIAM J. Optim., vol. 11, "
           "no. 2, pp. 464–494, 2000.",
    "emmvee": "Emmvee Photovoltaic Power Pvt. Ltd., “PV module brochure, E325P72,” manufacturer datasheet. "
              "(Not a peer-reviewed source.)",
    "pai": "F.-S. Pai, R.-M. Chao, S. H. Ko and T.-S. Lee, “Performance evaluation of parabolic prediction to "
           "maximum power point tracking for PV array,” IEEE Trans. Sustain. Energy, vol. 2, no. 1, pp. 60–68, 2011.",
    "brent": "R. P. Brent, Algorithms for Minimization without Derivatives. Englewood Cliffs, NJ, USA: "
             "Prentice-Hall, 1973.",
    "sera": "D. Sera, R. Teodorescu, J. Hantschel and M. Knoll, “Optimized maximum power point tracker for "
            "fast-changing environmental conditions,” IEEE Trans. Ind. Electron., vol. 55, no. 7, pp. 2629–2637, 2008.",
    "furtado": "A. M. S. Furtado et al., “A reduced voltage range global maximum power point tracking algorithm for "
               "photovoltaic systems under partial shading conditions,” IEEE Trans. Ind. Electron., vol. 65, no. 4, "
               "pp. 3252–3262, 2018.",
    "koutroulis": "E. Koutroulis and F. Blaabjerg, “A new technique for tracking the global maximum power point of PV "
                  "arrays operating under partial-shading conditions,” IEEE J. Photovolt., vol. 2, no. 2, "
                  "pp. 184–190, 2012.",
    "en50530": "EN 50530: Overall efficiency of grid connected photovoltaic inverters, CENELEC, 2010. Ramp rows as "
               "in a TUV Rheinland test report.",
    "oahu": "M. Sengupta and A. Andreas, “Oahu Solar Measurement Grid (1-Year Archive): 1-Second Solar "
            "Irradiance; Oahu, Hawaii (Data),” National Renewable Energy Laboratory, DA-5500-56506, 2010, "
            "doi: 10.5439/1052451. License: Creative Commons Attribution 4.0.",
    "tmyx": "L. K. Lawrie and D. B. Crawley, “Development of Global Typical Meteorological Years (TMYx),” "
            "2026. [Online]. Available: https://climate.onebuilding.org. File: Gannavaram-Vijayawada, "
            "WMO 431810, TMYx 2011–2025. (Data set, not a peer-reviewed source.)",
}
_ORDER = []


def cite(*keys):
    """Return "[n]" or "[n], [m]" and number each source at its first use."""
    out = []
    for k in keys:
        if k not in REFS:
            raise KeyError(f"unknown reference key {k}")
        if k not in _ORDER:
            _ORDER.append(k)
        out.append(f"[{_ORDER.index(k) + 1}]")
    return ", ".join(out)


# ---------------------------------------------------------------- content
# The text is a draft for the team to edit (written on 2026-11-24 from the final
# run of 2026-11-24). Idea C is the main method. Every borrowed part cites its source.
def content(d):
    d.add(para("Abstract", run("Abstract", bold=True, italic=True), run("—", bold=True), run(
        "Partial shading makes the power-voltage curve of a photovoltaic (PV) array multimodal, so a local "
        "tracker can stop on a local peak. This report compares five global searches for the maximum power point "
        "tracking (MPPT) of a simulated four-by-four array of 325 W panels with an averaged buck-boost converter. "
        "The main method, Idea C, is an implementation of published parts. It bounds the power between two measured "
        "operating points by the higher voltage times the higher current, tests the gap with the highest bound "
        "first at its corner duty, and stops when no gap can exceed the best power by more than 2 %. The baselines "
        "are the DIRECT search of Nguyen and Low, particle swarm optimization, grey wolf optimization and Idea B, "
        "a DIRECT search with the same bound check. All the searches use the same parabolic local stage and the "
        "same restart rule. The tests cover start-ups in Simulink and on a static bench, the EN 50530 ramps, 40 "
        "cloud events from measured 1 s irradiance data, pattern steps under sensor noise, and four full days. "
        "Idea C ended on a wrong peak in 1 of 99 Simulink start-ups, against 26 for DIRECT, with the same mean "
        "search time of 0.51 s. It delivered 98.72 % of the available energy on the cloud events and 99.968 % "
        "over four open-sky days.", bold=True)))
    d.add(para("Keywords", run("Keywords—", italic=True, bold=True),
               run("maximum power point tracking, partial shading, global search, branch and bound, measured power "
                   "ceiling, DIRECT, particle swarm optimization, grey wolf optimizer, EN 50530", italic=True, bold=True)))

    d.add(h1("Introduction"))
    d.add(body("A PV array delivers its highest power at one operating point, the maximum power point (MPP). The MPP "
               "moves with the irradiance and the temperature, and MPPT adjusts the operating point of the power "
               "converter to follow it. Perturb and observe (P&O) and incremental conductance (INC) are the common "
               f"methods {cite('esram')}. They estimate the slope of the power curve from two measurements and climb it."))
    d.add(body("Under partial shading, the bypass diodes of the shaded panels conduct, and the current-voltage curve of "
               "the array falls in steps. The power-voltage curve then has one peak for each step, and only one of "
               "them is the global maximum power point (GMPP). A local method stops on the peak nearest to its start. "
               "On one shading pattern of this project, P&O and INC reached only 35 % of the GMPP power. A global "
               "MPPT (GMPPT) method must decide which peak to climb. Each test of a candidate operating point costs "
               "energy, because the array runs below its peak during the test."))
    d.add(body("Published GMPPT methods trade the cost of the search against its reliability. Particle swarm "
               f"optimization (PSO) {cite('ishaque')} and grey wolf optimization (GWO) {cite('mohanty', 'mirjalili')} "
               "move a population of operating points for a fixed number of iterations. The deterministic DIRECT "
               f"search {cite('jones')}, applied to MPPT by Nguyen and Low {cite('nguyen')}, divides the duty range "
               "without a bound on the slope of the power curve. It can therefore never rule out a region, and its "
               f"stop proves nothing. Lipschitz searches such as LIPO {cite('lipo')} prove a bound, but they need a "
               "slope constant that must be tuned for each plant."))
    d.add(body("This report implements and compares five global searches on a simulated four-by-four array. The main "
               "method, Idea C, combines published parts: the measured power ceiling of Boztepe et al. "
               f"{cite('boztepe')} and Wang et al. {cite('wang')}, the best-first rule of Piyavskii {cite('piyavskii')} "
               f"and Shubert {cite('shubert')}, and the corner split of monotonic optimization {cite('tuy')}. It is an "
               "implementation, not a new method. Idea B adds the same ceiling check to the DIRECT search. Section II "
               "describes the system, Section III the methods, Section IV the tests, Section V the results, and "
               "Section VI the conclusions."))

    d.add(h1("System Model"))
    d.add(table(["Item", "Value"], [
        ["PV panel", f"Emmvee E325P72 {cite('emmvee')}: 325 W, 72 cells, 3 bypass diodes"],
        ["Array", "4 panels in series x 4 strings; Voc 183.2 V, Isc 36.44 A at STC"],
        ["Converter", "Averaged buck-boost, direct duty control, R_load 10 Ω, C_in 220 µF"],
        ["Control timing", "Sample 50 µs (20 kHz), MPPT period 20 ms, search probe 40 ms"],
        ["Search range", "Duty 0.30 to 0.78"],
        ["Sensors", "AMC1311 (voltage), LEM LA 55-P (current), 12-bit ADC (TMS320F28379D)"],
        ["Software", "MATLAB R2025b, Simulink, Simscape Electrical"],
    ], "System values", [1500, 3366]))
    d.add(body("Table I lists the system values. The array has four strings of four panels, and each panel has three "
               "bypass diodes, so a shaded array can have several power peaks. An averaged buck-boost converter with "
               "direct duty control connects the array to a resistive load. The input resistance of the ideal "
               "converter is R(D) = R_load (1 − D)² / D², so a higher duty gives a lower array voltage. The controller "
               "samples at 20 kHz, makes one MPPT decision each 20 ms, holds each search test for 40 ms, and averages "
               "the last quarter of the test."))
    d.add(body("Two benches run the same controller code. The Simulink model with Simscape Electrical has the plant "
               "dynamics and a model of the sensors. A compiled static bench runs the controller on the static "
               "current-voltage curves of the array. On the nine shading patterns of the project, it gives the "
               "Simulink results within 0.001 percentage points, so it can run the long tests."))

    d.add(h1("Tracking Methods"))
    d.add(table(["Method", "Search", "Source"], [
        ["DIRECT (paper)", "Lipschitz search on duty; P&O ending of the paper", cite("nguyen", "jones")],
        ["Idea B", "DIRECT global stage, then the ceiling check of Idea C", cite("nguyen", "boztepe", "wang", "tuy")],
        ["Idea C (main)", "Best-first search by the measured ceiling, corner split, certificate stop",
         cite("boztepe", "wang", "piyavskii", "shubert", "tuy")],
        ["PSO", "Particle swarm on duty, 8 particles", cite("ishaque")],
        ["GWO", "Grey wolf optimizer on duty, 6 wolves", cite("mohanty", "mirjalili")],
        ["P&O, INC", "Hill climbing from start-up, no global search", cite("esram")],
    ], "Global searches", [1000, 2566, 1300]))
    d.add(body("Idea C searches the duty range 0.30 to 0.78. It first tests the duties 0.30, 0.54 and 0.78. Take two "
               "neighbouring tests at the duties d1 < d2, with the measured points (V1, I1) and (V2, I2). The array "
               "current does not rise when the voltage rises, and a higher duty gives a lower voltage. Every duty "
               f"between the two tests therefore gives P(d) ≤ U = V1·I2 {cite('boztepe', 'wang')}. This ceiling needs "
               "no slope constant, no array model and no datasheet value."))
    d.add(body("A gap is open when its ceiling is above 1.02 P_best and the gap is wider than 0.01 of duty, where "
               "P_best is the best tested power. Idea C tests the open gap with the highest ceiling first, as in the "
               f"search of Piyavskii and Shubert {cite('piyavskii', 'shubert')}. It tests at the corner duty, where the "
               "load line through the point (V1, I2) meets the array curve. This is the projection step of the "
               f"polyblock algorithm {cite('tuy')}, and it splits the gap into two gaps with lower ceilings. The search "
               "stops when no gap is open. Under steady irradiance and settled readings, the tests then prove that no "
               "duty in the range gives more than 1.02 P_best, apart from the narrow gaps next to the best test. A "
               "store of 64 tests caps the search."))
    d.add(body("Idea B runs the global stage of DIRECT and then the same ceiling check on all the DIRECT samples. "
               "DIRECT ends with the P&O of its paper. After each search, Idea B, Idea C, PSO and GWO hand over to the "
               "same parabolic local stage. The stage refines the peak with at most three tests by parabolic "
               f"interpolation {cite('pai', 'brent')}, holds the array voltage, and checks the peak each second with a "
               f"three-point measurement that removes a steady drift of the light {cite('sera')}."))
    d.add(table(["Part", "Rule", "Source"], [
        ["Level test", "New search if |P − P_ref| > 5 % of P_ref", cite("wang", "furtado")],
        ["Steady test", "Slope of a line fit over 10 periods (0.2 s) at most 1 %/s", cite("boztepe")],
        ["Voltage hold", "Hold the voltage of the peak between checks", cite("boztepe", "furtado")],
        ["Power floor", "Level test off below 260 W (5 % of the rated power), on again above 286 W",
         "This project, after " + cite("furtado")],
        ["Timer", "New search after 900 s of tracking", cite("wang", "koutroulis")],
    ], "Restart rule", [1100, 2766, 1000]))
    d.add(body("Table III gives the restart rule of all the searches. The steady test lets the level test run only "
               "when the light is steady, which is also a condition of the ceiling. The power floor stops the false "
               "searches at dawn and dusk, when the power rises slowly by more than 5 %. Over four full days it "
               "reduced the searches of Idea C from 8413 to 521."))

    d.add(h1("Test Plan"))
    d.add(table(["Phase", "Test", "Bench"], [
        ["1b", "Start-up on all patterns, 25 °C and 45 °C, sensors on and off", "Static"],
        ["1c", "Start-up on 99 patterns", "Simulink"],
        ["2", f"EN 50530 irradiance ramps on P0 and R1 {cite('en50530')}", "Static, Simulink"],
        ["3", f"40 cloud events from the Oahu data {cite('oahu')}", "Simulink"],
        ["3n", "100 pattern steps under 1 to 30 x sensor noise", "Static"],
        ["4", f"Four full days, weather of Vijayawada {cite('tmyx')}, clouds from {cite('oahu')}, open sky and "
              "morning shade", "Static"],
        ["compute", "Time of one decision of the compiled controller", "PC"],
    ], "Test phases", [800, 3066, 1000]))
    d.add(body("The main measure is the tracking efficiency η = ∫P dt / ∫P_GMPP dt over each test profile, where "
               "P_GMPP is the power at the GMPP at each instant. It counts the energy lost during the search and the "
               "energy lost on a wrong peak in one unit. EN 50530 defines the dynamic MPPT efficiency in the same way. "
               "The tests also count the runs that end on a peak other than the GMPP, the time to reach 99 % of the "
               "GMPP power after a change, the number of searches, and the computation of the controller."))
    d.add(body("Limits of the tests. EN 50530 defines the ramps for an array with no shade, so the ramps on "
               "R1 go beyond the standard. The start-up and shut-down test (Annex B.4) and the static MPPT "
               "efficiency test of EN 50530 were not run. The 1 x sensor noise has only the datasheet noise of "
               "the sensors and the ADC. The converter model is averaged and has no switching ripple, so the "
               "10 x and 30 x levels stand for the noise of real hardware. The processing time was measured "
               "on a PC, not on the target controller (TMS320F28379D)."))

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
                    "Summary of the final tests", [1500, 1500, 900, 1100, 1700, 1200, 1100, 1120]), wide=True)
    else:
        d.add(body("[Summary table: run make_figures.m.]"))
    d.add(body("Start-up. Table V and Fig. 4 give the main result. Idea C ended on a wrong peak in 1 of 99 Simulink "
               "start-ups and in 0.78 % of the static start-ups. DIRECT ended on a wrong peak in 26 of 99 and in "
               "10.24 %. The two searches took the same mean time, 0.51 s (Fig. 3). The difference is the stop rule: "
               "DIRECT stops on a fixed budget, and Idea C stops only when its measurements rule out a better peak. "
               "PSO and GWO found the GMPP almost as often as Idea C, but each of their searches took 2.4 to 2.6 s."))
    d.add(body("Ramps and cloud events. On the EN 50530 ramps (Fig. 5), Idea C reached 99.52 % on average and 98.95 % "
               "on the worst row. On the 40 cloud events in Simulink (Fig. 7), it reached 98.72 % on average and "
               "recovered to 99 % of the GMPP power in 1.13 s. DIRECT was close on both tests (99.42 % and 98.62 %), "
               "because a cloud edge seldom moves the GMPP to another peak. PSO and GWO lost 3 to 8 points on the "
               "cloud events, because their long searches run the array far from its peak. On the ramps of the "
               "pattern with one peak, INC from start-up reached up to 99.84 %, because it needs no search."))
    d.add(body("Pattern steps and sensor noise. On 100 steps that move the GMPP (Fig. 9), Idea C ended on a wrong "
               "peak after 6 steps and DIRECT after 12. The efficiency of Idea C did not change from 1 to 30 times "
               "the datasheet noise (96.1 %). DIRECT reached a higher mean efficiency on these steps (96.9 %) and "
               "recovered faster (0.83 s against 1.12 s). The cause of this difference is not yet analysed."))
    d.add(body("Full days and computation. Over four days with a 900 s timer (Fig. 8), Idea C delivered 99.968 % of "
               "the GMPP energy on the open-sky days, the highest share of the five searches, with 521 searches. "
               "These searches cost 0.016 % of the energy. One decision of the compiled controller took 0.085 µs on "
               "one PC core, and one search took 6.4 µJ of computation, against 9.9 µJ for DIRECT and 21 to 23 µJ for "
               "PSO and GWO (Fig. 10)."))
    d.add(body("Limits. In Simulink, Idea C lost 0.27 points on the cloud events against the static bench, and "
               "DIRECT lost 0.03 points. On slow and deep cloud edges, the plant does not settle within one 20 ms "
               "period of the parabolic check, and the settling error is larger than the signal of the check. Two "
               "corrections were tested and rejected. The cloud data come from one climate, and the controller has "
               "not yet run on hardware."))

    d.add(h1("Conclusion"))
    d.add(body("This report compared five global MPPT searches on a simulated four-by-four PV array. Idea C, an "
               "implementation of the measured power ceiling with best-first search and a corner split, found the "
               "GMPP more reliably than the DIRECT search of Nguyen and Low at the same search time: 1 wrong start-up "
               "of 99, against 26. It searched about five times faster than PSO and GWO and kept 3 to 8 points more "
               "energy on the cloud events. With a power floor in the restart rule, it delivered 99.968 % of the "
               "available energy over four open-sky days. Its stop rule needs no slope constant, no array model and "
               "no datasheet value."))
    d.add(body("The next steps are a real-time test of the controller with hardware in the loop on the OPAL-RT "
               "OP5707, an analysis of the parabolic check under slow cloud edges, and tests with the irradiance data "
               "of other climates."))

    d.add(h1("References"))
    for k in _ORDER:
        d.add(para("references", REFS[k]))      # the style "references" numbers the entries


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
