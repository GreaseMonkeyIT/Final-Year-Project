---
title: DIRECT (Dividing Rectangles) literature map, and our global-search ideas
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-10-22
status: literature search done. Ideas B and C built in Simulink on 2026-10-22 (Notes/gmppt_B_C_simulink.md)
---

# DIRECT literature map, and our global-search ideas

## 1. Summary

- The DIRECT literature is too large to list in full, because the applications alone cover many fields. This note lists the method papers and the papers that matter for our project. The BibTeX file is `Literature/direct_algorithm.bib`.
- Start with Jones and Martins (2021). It is the review by the author of DIRECT. Its section 2.3 lists the weaknesses of DIRECT, and section 3 lists the variants.
- DIRECT is rare in MPPT. Nguyen and Low (2010) is the only journal paper of quality that we found. Of the 348 works that cite it, the abstracts in OpenAlex show only one more DIRECT tracker: a conference paper by the same group (Low et al. 2011). A search of IEEE Xplore on 2026-10-22 found no other DIRECT tracker, in journals or in conferences.
- Our Idea C (BSP with a bound) has close prior art in global optimization. Bisection forms of DIRECT exist (BIRECT, HALRECT, Chiter 2005). The rule "split the interval with the highest upper bound" is the Piyavskii-Shubert rule from 1972. We must cite these papers if we present Idea C.
- Idea C also has GMPPT prior art. Tiong et al. (2017, conference) use a binary search that removes the regions where the MPP cannot lie. Xu et al. (2021, IEEE TIE) use the monotonic output of the array to shrink the scan range. The bound itself is therefore not new.
- Sampled-data extremum seeking with DIRECT or Shubert (Khong et al. 2013, Nešić et al. 2013, both Automatica) gives a control-theory frame for our tracker, with closed-loop convergence results.
- No journal paper that we found adapts DIRECT to noisy samples. The two noise papers are conference papers. Our power samples are noisy, so this is a gap that we can state.

## 2. How the search was done

1. Web search for the main papers of each variant.
2. The reference list of Jones and Martins (2021), from the PDF of the authors.
3. OpenAlex title search for "dividing rectangles", "DIRECT algorithm", "DIRECT-type", "DIRECT method", "DIRECT optimization", "DIRECT global", "potentially optimal", "BIRECT" and "without the Lipschitz constant". A filter kept only titles where DIRECT is the algorithm. This gave 134 candidates, and a manual pass removed the false matches.
4. OpenAlex scan of all 348 works that cite Nguyen and Low (2010), to find other DIRECT trackers.
5. IEEE Xplore search on 2026-10-22, journals and conferences, with these queries:
   - "dividing rectangles" (42 results)
   - DIRECT search, DIRECT algorithm or dividing rectangle, with maximum power point, MPPT or photovoltaic (21 results)
   - extremum seeking with DIRECT, Lipschitz, Shubert, Piyavskii or global optimization (139 results)
   - Lipschitz, branch and bound or upper bound, with maximum power point, MPPT or GMPPT (105 results)
   - bisection, binary search, interval halving, golden section or Fibonacci, with partial shading or GMPPT (24 results)
   - skip, search space reduction or exclusion, power trapezium or restricted voltage window, with GMPPT (27 results)
   - Piyavskii, Shubert or Lipschitzian optimization (61 results, no MPPT paper)

Limits:

- We did not read the full text of most papers in this note. The one-line descriptions come from the abstracts and from Jones and Martins (2021).
- Xplore searches the metadata and the abstract. A paper that uses DIRECT only inside its method section can still be missing.

## 3. Literature map

Keys refer to `Literature/direct_algorithm.bib`. "(conf.)" marks a paper that is not a journal paper. The two papers `jones1993direct` and `nguyen2010direct` are in `Literature/gmppt_global_search.bib`.

### 3.1 Foundations

| Key | What it is |
|---|---|
| `piyavskii1972`, `shubert1972` | One-dimensional Lipschitz search. Each new sample goes where the upper bound is highest. DIRECT generalizes this. |
| `jones1993direct` | The original DIRECT. It tests all Lipschitz constants at once, so it needs no constant. |
| `jones2001encyclopedia` | Jones adds nonlinear constraints and integer variables (book chapter). |
| `hansen1995lipschitz`, `strongin2000book` | Background on Lipschitz optimization (chapter and book). |

### 3.2 Reviews, books and benchmarks

| Key | What it is |
|---|---|
| `jones2021direct25` | The main review. Weaknesses, the main variants, and a table that sorts the changes into five groups. |
| `stripinis2025review` | Review with a table of DIRECT applications by field. Open access. |
| `stripinis2023book` | Book on DIRECT-type methods and the DIRECTGO toolbox. |
| `sergeyev2017diagonal` | Book on the diagonal approach (samples at both ends of an interval). |
| `stripinis2024empirical` | Compares 12 combinations of selection rule and partition scheme. |
| `rios2013dfo` | Comparison of derivative-free solvers, DIRECT included. |
| `sergeyev2018metaheuristics` | DIRECT-type methods against metaheuristics on a small budget of samples. |
| `kudela2023bbob` (conf.) | DIRECT-type methods on the BBOB test set. |

### 3.3 Theory: convergence and scaling

| Key | What it is |
|---|---|
| `finkel2006additive` | DIRECT changes its behavior if a constant is added to the objective. |
| `liu2013linear` | The same problem for linear scaling. Some variants do not have it. |
| `finkel2004convergence` (report) | Convergence proof based on nonsmooth analysis. |
| `gablonsky2001thesis`, `finkel2005thesis` | The two NCSU PhD theses on DIRECT. |

### 3.4 Variants that change the selection rule

| Key | What it is |
|---|---|
| `gablonsky2001local` | DIRECT-l, locally biased. The authors say that it suits problems with few local minima. |
| `finkel2004restart` (report) | Adaptive restart of the balance parameter. |
| `mockus2011pareto`, `mockus2017plor` | Pareto selection (PLO, PLOR). |
| `liuzzi2010partition` | Two selection rules with convergence proofs. |
| `liu2015mrdirect`, `liu2017convergence` | MrDIRECT: multilevel selection for faster refinement. |
| `stripinis2018directgl` | DIRECT-GL: two-step global and local selection. |
| `chiter2006potentially`, `belkacem2024hyper`, `stripinis2022refinement`, `mustika2026pareto` | Other selection rules. |

### 3.5 Variants that change the partition or the sample points

This group is the prior art for Idea C.

| Key | What it is |
|---|---|
| `chiter2005sampling` | One-dimensional DIRECT. It bisects and samples at 1/3 and 2/3 of each interval. |
| `sergeyev2000partition`, `kvasov2003local`, `sergeyev2006diagonal` | Diagonal methods. They sample both ends of an interval and reuse the samples. ADC is the main algorithm. |
| `kvasov2012univariate` | Survey of one-dimensional Lipschitz methods. Our duty search is one-dimensional. |
| `liu2014bilevel` | DIRECT with a two-level partition. |
| `paulavicius2018birect`, `paulavicius2020gbbirect` | BIRECT: bisection, two samples on the diagonal. |
| `stripinis2024halrect` | HALRECT: halving with a multi-point sample scheme. |
| `paulavicius2014simplicial`, `paulavicius2014disimpl` | Simplices in place of rectangles. |
| `jia2023minimax`, `huyer1999mcs`, `liu2015edirect`, `kvasov2023extensions` (conf.) | Other partitions: minimax design, MCS, Voronoi cells, space-filling curves. |
| `tavassoli2014hd`, `tao2017block` | High-dimensional variants. Not relevant for one dimension. |

### 3.6 DIRECT with a local search

This is the same structure as our tracker: DIRECT finds the region, then P&O holds the point.

| Key | What it is |
|---|---|
| `liuzzi2010dirmin` | DIRMIN: a local search from the center of each selected interval. |
| `liuzzi2016local` | Derivative-free local searches inside DIRECT. |
| `campana2016ship` | Global and local hybrid on a ship design problem. |

### 3.7 Constraints, hidden constraints and multiple objectives

Keys: `dipillo2012penalty`, `dipillo2015dfepgo`, `dipillo2016direct`, `costa2018filter`, `liu2017edirectc`, `stripinis2019penalty`, `stripinis2021glh`, `na2017hidden`, `lovison2020multi`. These do not apply to a bounded duty search, but a reviewer can ask about them.

### 3.8 Noisy or failed samples

| Key | What it is |
|---|---|
| `carter2001pipeline` | Noisy objective in pipeline design. Jones and Martins cite it for simulations that fail. |
| `deng2007noisy` (conf.) | DIRECT for noisy functions. |
| `nicholas2015stochastic` (conf.) | DIRECT with repeated samples to reduce the variance. |

### 3.9 Software

| Key | What it is |
|---|---|
| `stripinis2022directgo` | DIRECTGO, a MATLAB toolbox with more than 50 DIRECT-type algorithms. |
| `stripinis2026gendirect` | GENDIRECT, a framework that builds DIRECT-type algorithms from parts. |
| `he2009vtdirect95` | VTDIRECT95, serial and parallel Fortran code. |
| `stripinis2026practical` | DIRECT-type method for medium-scale problems. |

SciPy (`scipy.optimize.direct`) and NLopt also have DIRECT and DIRECT-l.

### 3.10 Applications in power and energy

| Key | What it is |
|---|---|
| `nguyen2010direct` | GMPPT with DIRECT, on hardware. Our M4. |
| `low2011ispacs` (conf.) | Same group, fast irradiance changes. |
| `muchen2024mppt` | MPPT with DIRECT in a low-profile journal. Not read. |
| `belfkira2011sizing` | Sizing of a wind, PV and diesel system. |
| `kvasov2008pss` | Tuning of power-system stabilizers with diagonal partitions. |
| `hao2016hev`, `wang2023phev` | Energy management of hybrid vehicles. |
| `zhu2002slider`, `marot2007contour` | IEEE journal applications outside energy. |
| `ahmad2017golden` | Not DIRECT. A GMPPT interval search of the same family (golden band search). |
| `zhang2012epepemc` (conf.), `azzouzi2006machine` (conf.) | Sizing of a PV, wind and diesel system, and design of a PM machine, with DIRECT. |
| `shen2014hess` | Sizing of a battery and ultracapacitor store with DIRECT. |

### 3.11 Sampled-data global extremum seeking

Extremum seeking is the control-theory name for MPPT-like problems: an unknown steady-state map from input to output, and a controller that searches for its maximum. The sampled-data form applies an input, waits for the plant to settle, measures, and lets an optimizer choose the next input. This is our tracker with a 20 ms probe.

| Key | What it is |
|---|---|
| `khong2013unified` | Framework with convergence results for any optimizer with a stated property. DIRECT and Shubert are examples. |
| `nesic2013shubert`, `nesic2012shubertcdc` (conf.) | Global extremum seeking with the Shubert algorithm. |
| `khong2012directes` (conf.) | Global extremum seeking with DIRECT. |
| `lee2015aero` | Global extremum seeking applied to an aerodynamic design (IEEE TCST). |
| `chong2017observer` (conf.) | DIRECT inside a supervisory observer. |

### 3.12 GMPPT prior art for the bound and for bisection (IEEE Xplore)

These keys are in `Literature/gmppt_global_search.bib`, section C2.

| Key | What it is |
|---|---|
| `xu2021mmpt` | Modified maximum power trapezium. Uses the monotonic output of the array to set a lower bound on the current range. Closest journal prior art for our bound. |
| `ahmed2023skip`, `kermadi2019hybrid`, `kermadi2021rapid`, `zhou2022single`, `sun2023ovs`, `aquib2020time` | Scan-and-skip methods. Each one skips voltage ranges that cannot hold the GMPP. |
| `hadiby2026ssr` | Search space reduction with random agents. Not a bound. Hardware on dSPACE. |
| `tiong2017binary` (conf.) | Binary search on the duty that removes regions where the MPP cannot lie. Closest GMPPT prior art for Idea C. |
| `kumaresan2022secant` (conf.) | Binary search on the power reference, then secant tracking. |
| `ramana2018bisection` (conf.) | A coarse search, then bisection. |
| `nugraha2019cuckoo`, `malathy2017fibonacci` (conf.), `cardoso2019fibonacci` (conf.) | Golden-section and Fibonacci search. |
| `shames2016guaranteed` (conf.) | A local stage with a convergence guarantee. Not read. |

## 4. Our global-search ideas

Source: `MPPT_Global_Search_Ideas_and_Context.docx` (the brainstorm note) and the cross-check of 2026-10-01 in `Notes/gmppt_m1_m4_comparative_study.md`.

### 4.1 The structure

The tracker has two stages. A global stage finds the region of the GMPP. A local stage (small-step P&O or INC) holds the point. A large change in shading starts the global stage again. The brainstorm note gave four candidates for the global stage.

| Candidate | Idea | Open problem in the note |
|---|---|---|
| A. DIRECT | Trisect the duty interval. Select "potentially optimal" intervals by power and width. | Bookkeeping and number of samples |
| B. BSP with a DIRECT-like selection | A binary tree of duty intervals. Select nodes by measured power and width. | BSP alone does not say which node to split |
| C. BVH, or branch-and-bound | Keep an upper bound for each region. Discard a region if its bound is below the best power. | How to get a reliable, tight bound |
| D. Simulated annealing | Accept a worse point with probability exp(-Δ/T). | Random, so no fixed number of samples |

### 4.2 What we found on 2026-10-01

1. The bound has a simple answer. The array current does not increase with the voltage. Between two samples, the power is therefore at most V(left) x I(right). This needs no model, no Lipschitz constant and no Voc or Isc data.
2. Sample at interval ends for BSP, not at centers. Bisection with shared ends costs 1 new sample for each split and halves the width. DIRECT trisection costs 2 samples and divides the width by 3.
3. The cross-check (1800 random cases, static P-V curves) tested three variants:

| Variant | GMPP found | Mean search samples | Result |
|---|---|---|---|
| Plain DIRECT (M4) | 88 to 94 % | 9.5 to 10.3 | Misses when it samples the global hill off its peak |
| Idea A: DIRECT + bound pruning | 88 to 93 % | 9.4 to 10.1 | Saves 0.1 samples. Not useful. |
| Idea B: DIRECT + bound check before the hand-over | 99.7 to 100 % | 13.6 to 15.5 | Recommended method |
| Idea C: BSP + bound | 99.7 to 100 % | 12.8 to 14.3 | As reliable as Idea B, a little less power in the first second |

4. The bound makes DIRECT reliable, not faster. "DIRECT is the fastest" is not true on our array. M1 needs about 3 samples.
5. Prior art for the bound in GMPPT: Wang, Li and Ruan (2016, same inequality) and Abujarad et al. (2026, branch-and-bound with model bounds). The possible new part is the measured bound as a stop test for DIRECT.
6. Simulated annealing was not run, because random search gives no fixed number of samples.

## 5. What the literature changes for the ideas

1. **Idea C needs new citations.** Bisection forms of DIRECT exist: `chiter2005sampling`, `liu2014bilevel`, `paulavicius2018birect` and `stripinis2024halrect`. Diagonal methods (`sergeyev2006diagonal`) already sample the two ends of each interval. "Split the gap with the highest bound" is the rule of `piyavskii1972` and `shubert1972`. In GMPPT, `tiong2017binary` removes regions by bisection, and `xu2021mmpt` uses the monotonic output of the array. Idea C can claim only the combination: best-first bisection, a measured bound, and a stop test with a stated tolerance. Read `tiong2017binary` and `xu2021mmpt` in full before we write that claim.
2. **Idea B has one more prior-art paper (found 2026-10-22).** Khong et al. (2013, Automatica 49(7), `khong2013directes`) stop DIRECT when the best sample is within a tolerance of a Lipschitz bound. Our stop test needs no Lipschitz constant. The full borrowed-versus-new analysis is in `Notes/novelty_check_ideas_B_C.md`.
3. **Idea B fits a known weakness.** Jones and Martins (2021, section 2.3.2) say that the search near local minima delays the global minimum. Our miss case is a form of this weakness. Diagonal methods compute a lower bound over each interval from its end values (`sergeyev2006diagonal`). Read that part before we write the claim for the stop test.
4. **DIRECT-l is a cheap test.** `gablonsky2001local` says that the locally biased form suits problems with few local minima. Our array has few peaks. We can add DIRECT-l to `crosscheck/algos.py` with little work.
5. **Scaling matters for hardware.** `finkel2006additive` and `liu2013linear` show that the selection of DIRECT depends on the offset and scale of the objective. A gain or offset error in the power measurement can therefore change which intervals DIRECT selects. Check whether our M4 implementation has the balance term that causes this.
6. **Noise is an open area.** No journal paper in this search adapts DIRECT to noisy samples. Our cross-check already ran with 0.5 % noise. This can be a small, honest contribution.
7. **The hybrid is standard.** DIRECT followed by a local search is a known pattern (`liuzzi2010dirmin`, `liuzzi2016local`). Cite it to support the DIRECT then P&O structure.

## 6. Open items

1. Read `jones2021direct25` sections 2.3 and 3, and `sergeyev2006diagonal`, before the novelty claim for Ideas B and C.
2. Read `tiong2017binary`, `xu2021mmpt` and `khong2013unified` in full. The Xplore page showed a "Need access for your organization" banner on 2026-10-22, so check that the institute access is active first.
3. Build DIRECT and the bound check in `mppt_controller.m` (`p.alg` = 3 and 4). The controller has only P&O (1) and INC (2) at this date.
4. Optional: add DIRECT-l and Piyavskii-Shubert with the monotone bound to `crosscheck/algos.py`.

Status on 2026-10-22: items 1 and 2 are done (`Notes/prior_art_reading_notes_B_C.md`, `Notes/novelty_check_ideas_B_C.md`). Item 3 is done for DIRECT, Idea B and Idea C (`mppt.alg` = 3, 4, 5, `Notes/gmppt_B_C_simulink.md`). Item 4 is not done. LIPO, a Piyavskii-Shubert search with a Lipschitz constant, is in `crosscheck/algos.py` as a baseline.
