# Paper review — Ahessab et al. (2024), IANN-PSO hybrid MPPT with DSP F28379D

*Prepared for: Implementation of MPPT for PV Arrays Under Partial Shading Conditions (B.Tech final year project)*

---

## 1. Citation

Ahessab H, Gaga A, Elhadadi B. "Enhanced MPPT controller for partially shaded PV systems using a modified PSO algorithm and intelligent artificial neural network, with DSP F28379D implementation." *Science Progress*, 2024; **107**(4): 1–26. DOI: [10.1177/00368504241290377](https://doi.org/10.1177/00368504241290377)

**Authors' affiliation:** Research Laboratory of Physics and Engineers Sciences (LRPSI), Research Team in Embedded Systems, Engineering, Automation, Signal, Telecommunications and Intelligent Materials (ISASTM), Polydisciplinary Faculty (FPBM), Sultan Moulay Slimane University (USMS), Beni Mellal, Morocco.

**Licence:** Creative Commons CC BY-NC 4.0. Figures, tables and text may be reproduced for non-commercial use with attribution — this covers academic project reports, so their figures can be reused directly provided the source is cited.

---

## 2. Where it was published

This is a **journal article, not a conference paper.** It was not presented at a conference; it appeared as an *Original Research Article* in an issue of a journal. Anyone asking "where was this presented" should be told: published in *Science Progress*, Volume 107, Issue 4 (2024), pages 1–26.

**About the venue — *Science Progress*:**

| Attribute | Value |
|---|---|
| Publisher | SAGE Publications Ltd (United Kingdom) |
| ISSN | 0036-8504 (print), 2047-7163 (online) |
| Type | Multidisciplinary, fully open access, peer reviewed |
| Scope | Engineering & technology, physics, chemistry, life sciences, computing, earth sciences, medicine (excludes social sciences) |
| Impact factor | 2.6 (5-year 2.7) |
| SJR (2025) | 0.515, **Q1** by SCImago in its category |
| h-index | 56 |
| Indexing | Science Citation Index Expanded (SCIE), Scopus, MEDLINE |
| Ethics | Member of COPE (Committee on Publication Ethics) |
| History | Published since 1916; a long-established title |

---

## 3. Validity of the publication

**It is a legitimate, citable source.** The relevant checks all pass:

1. **Indexed in SCIE and Scopus.** This is the practical test most universities apply. A paper in an SCIE-indexed journal is acceptable as a reference in a B.Tech project report, a literature survey, or a paper of our own.
2. **Established publisher.** SAGE is a mainstream academic publisher, not a predatory one. The journal is not on Beall's list or its successors.
3. **COPE member with a declared peer review process.** Conflicts of interest, funding, ethical approval and author contributions are all declared in the paper, which is what a properly handled submission looks like.
4. **Long publication history** (since 1916) with a respectable h-index of 56.
5. **Content is verifiable.** The work includes both MATLAB-Simulink simulation and a physical bench setup — DSP board, fabricated PCB, real panels, oscilloscope traces. Hardware-validated results are the exception rather than the rule in this area, and they raise confidence considerably.

**Honest positioning.** *Science Progress* is a solid mid-tier, broad-scope open access journal, not a specialist power-electronics venue. For work of this kind the top-tier references are *IEEE Transactions on Power Electronics*, *IEEE Transactions on Industrial Electronics*, *IEEE Transactions on Energy Conversion*, *IET Renewable Power Generation* and *Solar Energy*. Practically this means:

- Cite it with confidence as evidence of what the ANN-seeded PSO approach achieves and how it is built.
- For any headline number we intend to *quote as fact* in our report (efficiency percentages, tracking times), corroborate it against a second source or, better, reproduce it ourselves in simulation. That is standard practice for any single-source figure regardless of venue, and it also gives us original results to present.
- Prefer re-deriving design values from the governing equations rather than copying component values, since the paper does not state the load-side operating point the values were computed for.

**Verdict:** valid, credible, safe to build on. Use it as a primary reference and as a design template; generate our own numbers for the comparison table.

---

## 4. What the paper actually does

**System under test**

| Item | Value |
|---|---|
| PV module | 16 W, Vmp 12 V, Imp 1.33 A, Isc 1.46 A, Voc 14.4 V |
| Array | 8 modules — two series strings of 4, connected in parallel |
| Array rating | 64 W at 48 V per string; 128 W total |
| Protection | One bypass diode per module, one blocking diode per string |
| Converter | DC–DC boost, fsw = 50 kHz, L = 5 mH, Cin = 47 µF, Cout = 220 µF |
| Controller | TI LAUNCHXL-F28379D, dual core, 100 MHz, 16 ADC channels, 12-bit acquisition used |
| Toolchain | MATLAB-Simulink model-based design, code deployed to the DSP; data logged to PC over RS232/USB |

**Method — the IANN-PSO hybrid**

Two stages:

1. **IANN (intelligent artificial neural network).** A feed-forward network takes the irradiance and temperature of each of the 8 modules as inputs and outputs `Iann`, an estimate of the array current at the global MPP. Trained by Levenberg-Marquardt on 200 shading cases; 2 hidden layers, 10 neurons in the hidden layer, 1 output.
2. **PSO seeded by the IANN.** Rather than scattering particles randomly across the whole duty-cycle range, the swarm is initialised around `Iann` — one particle at `Iann` itself and the others at 40%, 80% and 120% of it. PSO then converges inside that reduced range. On a sudden irradiance change the IANN supplies a fresh seed and the swarm reinitialises.

PSO parameters used: 8 particles, c1 = 1.1–1.2, c2 = 2, inertia w = 0.4, max 1000 iterations.

**Shading cases (Table 3 of the paper)** — irradiance in W/m² for modules PV1…PV8:

| Case | PV1 | PV2 | PV3 | PV4 | PV5 | PV6 | PV7 | PV8 | Character |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1000 | 800 | 800 | 100 | 100 | 600 | 600 | 1000 | Heavy, multi-level shading |
| 2 | 1000 | 800 | 800 | 600 | 1000 | 1000 | 1000 | 600 | Light shading |
| 3 | 1000 | 1000 | 1000 | 1000 | 1000 | 1000 | 1000 | 1000 | Uniform (control case) |

Resulting global peaks from their P–V curves (Fig. 6): approximately 78 W, 110 W and 128 W.

**Headline results**

- Simulation: PSO settles in ≈2.7–2.8 s; IANN-PSO in ≈0.1 s.
- Hardware: PSO takes ≈35–50 s; IANN-PSO ≈10–15 s. Reinitialisation after an environmental change completes within ≈40 s.
- Efficiency comparison across five algorithms (Fig. 15): P&O lowest (≈40–56%), then Cuckoo (≈71%), IANN alone (≈70–77%), PSO (≈81–86%), IANN-PSO highest (≈98–100%).

---

## 5. Why this is a good basis for our project

**Direct problem match.** Same topic, same array topology, same protection scheme, same converter stage, same multi-peak phenomenon. It maps cleanly onto our notebook:

| Our chapter | What this paper supplies |
|---|---|
| Ch. 7 — From one panel to an array | An 8-module series/parallel array with stated parameters we can model exactly |
| Ch. 8 — What partial shade does to the circuit | Bypass and blocking diode placement, hot-spot rationale, Fig. 1 |
| Ch. 9 — The multi-peak characteristic | Fig. 6: three measured P–V curves with global and local peaks marked |
| Ch. 10.4 — Metaheuristic search | A complete, parameterised PSO implementation for MPPT |
| Ch. 10.5 — Hybrid, two-stage trackers | The central worked example of the family: prior estimate, then local search |
| Ch. 4.5 — How a tracker is scored | A scoring template: tracking time, efficiency, steady-state oscillation, relative error |

**Three concrete things to take from it:**

1. **A benchmark to measure ourselves against.** Their three shading cases are fully specified, so we can reproduce them in our own model and compare our tracker against their published PSO and IANN-PSO results. Comparing against a named, published baseline is far stronger in a viva than comparing against a baseline we wrote ourselves.

2. **A hardware reference design.** If our project includes a build, Figures 10–14 give a complete signal chain: PV → boost converter → resistive load, with I and V sensors into the DSP ADC, MPPT computing duty cycle, ePWM driving a MOSFET gate driver. The Simulink model-based-design workflow (Fig. 12) is exactly the route we would take with an F28379D or a similar TI part.

3. **Support for our argument about search cost.** The paper reports both simulated and measured tracking times for the same algorithm, and they differ by roughly two orders of magnitude (0.1 s simulated vs 10–15 s on the bench). This is the clearest published evidence we have that the real cost of an MPPT search is the number of operating points physically applied and allowed to settle, not the arithmetic — which is the central claim of our Chapter 11. Their own conclusion goes further and states that with a sufficiently accurate network output, "the need for a stochastic search method like PSO could potentially be eliminated, making it possible to employ faster search algorithms such as P and O and INC." That is a useful quotation: an author of a PSO-hybrid paper conceding that the stochastic stage becomes unnecessary once good prior information is available.

**Design equations worth reusing** (Section "DC–DC boost converter"):

- Inductor: `L = Vpv · (Vload − Vpv) / (ΔIL · fsw · Vload)`
- Ripple current: `ΔIL = 0.4 · Iload,max · (Vload / Vpv)`
- Output capacitor: `Cout = D · Iload,max / (ΔVload · fsw)`
- Input capacitor: `Cin = ΔIL / (8 · ΔVpv · fsw)`

---

## 6. Notes for when we reuse the material

Light, practical points — none of these undermine the work, they are just things to settle for ourselves rather than copy:

- **Re-derive the converter component values.** The paper gives L, Cin and Cout but not the load voltage or maximum load current they were computed for, so the values cannot be checked against the equations as printed. Plug in our own operating point. In particular, choose the input-voltage ripple deliberately: for a PV input we want a small ripple (roughly 1–2% of Vpv) so the operating point stays close to the MPP.
- **Quote power figures from one place.** The global peak powers appear slightly differently between Figure 6, Table 7 and the discussion text (e.g. ~78 vs 79 W for Case 1). Pick the Figure 6 values (78 / 110 / 128 W), state which source we used, and produce our own numbers from simulation for the comparison table.
- **Use simulation and hardware timings separately.** Do not mix their 0.1 s simulated figure with their 10 s measured figure in the same comparison; keep the two columns distinct, as they do in the discussion.
- **Consider the sensing requirement in our design.** The IANN needs per-module irradiance as its input, which implies one irradiance sensor per panel. The authors flag this themselves as the main obstacle to deployment and suggest inferring irradiance from the PV current and voltage curves instead. This is a good, well-defined extension for us: any method that gets its prior from the array's own electrical measurements rather than from added sensors is more deployable, and we can say so with the paper's own conclusion as support.
- **Report our ANN training honestly.** Their network reports R = 1 on training, validation and test. If we build a comparable network, we should hold out a genuinely unseen set of shading patterns and report whatever we get, including the misses.

---

## 7. Ready-to-use citation entries

**IEEE style**

> H. Ahessab, A. Gaga, and B. Elhadadi, "Enhanced MPPT controller for partially shaded PV systems using a modified PSO algorithm and intelligent artificial neural network, with DSP F28379D implementation," *Science Progress*, vol. 107, no. 4, pp. 1–26, 2024, doi: 10.1177/00368504241290377.

**BibTeX**

```bibtex
@article{ahessab2024iannpso,
  author  = {Ahessab, Hajar and Gaga, Ahmed and Elhadadi, Benachir},
  title   = {Enhanced {MPPT} controller for partially shaded {PV} systems using a
             modified {PSO} algorithm and intelligent artificial neural network,
             with {DSP} {F28379D} implementation},
  journal = {Science Progress},
  volume  = {107},
  number  = {4},
  pages   = {1--26},
  year    = {2024},
  doi     = {10.1177/00368504241290377},
  note    = {SAGE Publications, open access, CC BY-NC 4.0}
}
```

---

## 8. Summary

A credible, SCIE- and Scopus-indexed, peer-reviewed open access journal article from SAGE — published, not conference-presented. Its subject matter sits directly on top of ours, it is one of the few papers in this area that carries a design all the way to working hardware, and it supplies a fully specified benchmark we can reproduce. It is a sound basis to build the project on, provided we generate our own numerical results for anything we present as our own finding.

**Sources for the journal assessment:** [SAGE journal page](https://journals.sagepub.com/home/sci) · [SCImago Journal Rank](https://www.scimagojr.com/journalsearch.php?q=23697&tip=sid)
