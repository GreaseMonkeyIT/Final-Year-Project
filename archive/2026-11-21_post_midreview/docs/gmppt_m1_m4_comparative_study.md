---
title: Comparative study of M1 to M4, and a preliminary cross-check on the 4 x 4 array
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-10-01
status: preliminary results (static P-V curves, not Simulink)
---

# Comparative study of M1 to M4, and a preliminary cross-check

## 1. Summary

- DIRECT (M4) is a good choice for the final output, but not because it is the fastest. The papers do not show that it is the fastest. On our array, M1 uses fewer operating points. DIRECT is the most general method of the four, and it is the only one with hardware results.
- Plain DIRECT misses the global peak in 6 % to 12 % of random shading cases on our array. It samples the global hill, but at a point below a sample on a lower hill. Its local stage then refines the wrong hill.
- A bound from the I-V curve removes this failure. Between two samples, the power cannot be more than V(left) x I(right). DIRECT plus this check found the global peak in 99.7 % to 100 % of 1800 random cases. It needs about 4 more operating points (about 80 ms at 20 ms for each point).
- The same bound does not make DIRECT faster. As a pruning rule inside DIRECT, it saved 0.1 operating points on average. It makes DIRECT reliable, not fast.
- The bound itself is not new. Wang, Li and Ruan (2016) skip voltage intervals with the same inequality. Abujarad et al. (2026) use a best-first branch-and-bound with model-based bounds. The new part is the use of the measured bound as a stop test for DIRECT. Update 2026-10-22: Khong et al. (2013, Automatica 49(7)) already stop DIRECT with a bound, but their bound needs a known Lipschitz constant. See `Notes/novelty_check_ideas_B_C.md`.
- M2 needs the voltage and current of every module, temperature, and a trained neural network (its Appendix A). The main text says that it needs only the PV voltage and current. For a 16-panel array, M2 is not practical.
- M3 is a conference paper (PEDSTC 2023). Under the journal-only rule, it cannot be a source. Section 3.3 gives two journal alternatives. Decision of 2026-10-23: M3 stays as a comparison baseline, and the thesis marks it as a conference paper.
- Update 2026-10-22: section 11 compares B and C with LIPO, the Lipschitz stop of Khong et al. (2013) and the skip sweep of Boztepe et al. (2014). Section 12 gives the effect of sensor noise and of the two tolerances.

## 2. Scope and sources

The study uses journal papers only. The IEEE papers came from IEEE Xplore through the institute access. The full list, with DOIs, is in `Literature/gmppt_global_search.bib`.

The study has two parts:

1. A check of the claims in test.docx against the primary papers (section 3).
2. A preliminary cross-check (sections 4 to 6). All four methods and three variants of our ideas run on the same model of our array.

## 3. The four methods: what the papers say

### 3.1 Facts checked against the papers

| | M1 Zaki 2023 | M2 Alombah 2025 | M3 Kouchaki 2023 | M4 Nguyen & Low 2010 |
|---|---|---|---|---|
| Venue | Sci. Rep. (journal) | Sci. Rep. (journal) | PEDSTC (conference) | IEEE Trans. Ind. Electron. (journal) |
| Array | 4 series x 2 parallel, 250 W panels | 3 series, 60 W panels | 4 series, 95 W panels | 3 x 20 W panels on solar array simulators, 2 x 2 real 20 W panels |
| Converter | Boost, 2.5 kHz | Boost, 30 kHz | DC-DC with a PI voltage loop | Buck-boost, 20 kHz, 10 Ω load |
| Sensors | V, I, and Vload | V and I of each module, temperature (Appendix A) | V, I | V, I |
| Prior data | Voc ratio 0.7 to 0.8, N | Trained ANN for the array | Voc, Isc, ξ(G) of the module | Voc, Isc ranges for the duty interval |
| Global stage | Up to N candidates, stop when power falls | Window [Va, Vb], then confinement | 2 + Ns probes, then Ns corrected probes | Interval trisection, 9 samples, then local trisection |
| Validation | Simulation | Simulation | Simulation | Hardware |
| Reported time | Under 0.2 s | 64 ms and 68 ms (uniform case) | About 1 s (dynamic case) | GP region at the 8th or 9th sample (50 ms each) |

### 3.2 Corrections to test.docx

1. M1, array: the paper uses four series groups of two parallel 250 W panels, not four single modules.
2. M1, duty formula (Eq. 10): it assumes a boost converter with a stiff output voltage. Our model is a buck-boost into a 10 Ω load, so the output voltage changes with the duty. We cannot use Eq. 10 directly. M1 needs a voltage loop or a mapping through the load resistance.
3. M1, stop rule: the search stops at the first candidate with less power than the one before. This assumes that the candidate powers rise to one maximum and then fall.
4. M2, sensors: test.docx says that M2 uses only the PV voltage and current. Appendix A says that the estimator "uses the current and voltage on each module". It also uses temperature and a trained neural network. The base study (Harrison et al. 2023) trained its network on 400 patterns of one 3-module string.
5. M2, step sizes: the main text gives Δd = 0.008 (MSMPP-P&O) and 0.001 (MSMPP-INC). Appendix B gives 0.08. The paper is not consistent. test.docx follows the main text.
6. M3, probe points: V1 = 0.5 Voc of one module and V2 = 0.8 Ns Voc are correct as written. My earlier remark that they were not consistent was wrong.
7. M3, ξ(G): the paper gives ξ as linear in G, 0.17 at 100 W/m² and 0 at 1000 W/m². The paper does not give the shade-test threshold as a number.
8. M4, speed claim: "two times faster and 10 % higher tracking efficiency" is against one method only (Patel and Agarwal 2008), under fast changes. The paper gives no absolute tracking time for simulation.

### 3.3 M3 and the journal-only rule

M3 is a conference paper. Two journal papers use the same idea, 0.8 Voc candidates plus a shading test:

- Bi et al. 2020, IEEE Trans. Ind. Appl.: a shading vector selects the 0.8 Voc region of the GMPP with k-nearest neighbors.
- Ghasemi et al. 2016, IEEE Trans. Power Electron.: shading detection and smooth MPPT.

Decision (2026-10-23): keep M3, and say in the thesis that it is a conference paper.

## 4. Cross-check method

### 4.1 Model

`crosscheck/pvarray.py` is a numpy model of the 4 x 4 Emmvee E325P72 array. It uses the values of `pv4x4_config.m`: n = 1.0, Rs = 4.41 mΩ for each cell, 3 bypass groups for each panel, and 15SQ045 bypass diodes. The script `crosscheck/validate_model.py` compares it with the Simulink sweeps of `PV4x4_sweep.slx`. On the nine patterns of `shading_patterns.m`, the difference is less than 1.75 % of the GMPP at every voltage.

The converter is the ideal averaged buck-boost of `MPPT_4x4.slx`, into 10 Ω. A duty D sets the input resistance R (1 - D)² / D².

### 4.2 Units of cost

One probe is one applied operating point. In `MPPT_4x4.slx`, one probe takes one MPPT period of 20 ms. The cross-check counts probes and does not simulate the transient. This is the correct unit for hardware, because the settling time sets the cost of each point, not the arithmetic.

### 4.3 Harness check

Offline P&O from duty 0.30 reaches 46.6 % (P1), 35.0 % (R1) and 95.9 % (P3) of the GMPP. The Simulink runs gave 46.6 %, 35 % and 96 %. The offline harness therefore reproduces the Simulink trackers.

### 4.4 Methods as implemented

| Method | Implementation |
|---|---|
| M1 | Eq. 10 with r = 0.8, N = 4, Vdiode = 3 x 0.37 V. Shade test of Eq. 11 to 13 with a 40 W/m² threshold. Ideal voltage loop. |
| M2 | Best case. The harness gives the exact window [Va, Vb] (GMPP ± 4 % of Voc), so the estimator costs no probes and no sensors. Confinement with λd = 0.05 (paper) and 0.01. |
| M3 | Probes at 0.5 Voc and 0.8 Ns Voc, threshold 50 W/m². Ns irradiance probes, Ns corrected probes with the paper's ξ(G). Ideal voltage loop. |
| M4 | DIRECT as in the paper. Duty interval 0.30 to 0.78. PSC test of Eq. 19 and 20. Nine globally biased samples, and two more cycles if the two best samples are not neighbors. Locally biased trisection to 0.005. The skip rules of section IV-C. |
| Idea A | M4 plus pruning. DIRECT skips a new sample if V(left) x I(right) of its neighbors is below the best power. |
| Idea B | M4, then a bound check before the hand-over. The check splits each gap whose bound V(left) x I(right) is more than 2 % above the best power. It stops when such gaps are narrower than 0.01 in duty. |
| Idea C | BSP: samples at the interval ends and the middle, then always split the gap with the highest bound. Same 2 % and 0.01 limits. |

After the global stage, every method hands over to the same P&O (step 0.005). Any method can use the local stage of M1 (enhanced INC) or M2. A common local stage therefore keeps the comparison fair.

### 4.5 Test sets

- The nine project patterns (P0 to R5).
- 300 random panel-level patterns: a shadow covers each panel with probability 0.4, at 100 to 900 W/m².
- 300 random shadow edges: the shadow rises from the bottom of each string and does not follow the panel edges. A shadow can cover one bypass group of a panel alone.
- 300 random group-level patterns: a shadow covers each bypass group on its own with probability 0.3. This is a stress case.
- Each random set ran with no noise and with 0.5 % Gaussian noise on V and I.

### 4.6 Metrics

- GMPP found: final power at 98 % of the GMPP or more.
- Worst case: the lowest final power in the set.
- Search probes: operating points before the hand-over to P&O.
- Power in the first 1 s: the mean power over the first 50 probes, as a percentage of the GMPP. This includes the power lost while the search runs.

## 5. Results

### 5.1 Nine project patterns, no noise

Cells: search probes / final power as a percentage of the GMPP.

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| P&O, start D = 0.30 | 0 / 99.7 | 0 / 46.6 | 0 / 99.8 | 0 / 95.9 | 0 / 35.0 | 0 / 99.8 | 0 / 99.8 | 0 / 99.8 | 0 / 99.8 |
| M1 | 2 / 99.8 | 3 / 99.8 | 2 / 99.8 | 3 / 99.8 | 4 / 97.3 | 2 / 99.8 | 2 / 99.7 | 2 / 99.7 | 2 / 99.8 |
| M2 best case, λd 0.05 | 7 / 99.7 | 8 / 99.6 | 40 / 99.8 | 40 / 99.8 | 6 / 99.3 | 40 / 99.8 | 40 / 99.8 | 40 / 99.8 | 6 / 99.8 |
| M3 | 2 / 99.8 | 9 / 99.8 | 2 / 99.8 | 9 / 99.8 | 9 / 99.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 2 / 99.8 |
| M4 DIRECT | 9 / 99.7 | 11 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 |
| Idea B: DIRECT + bound check | 11 / 99.7 | 12 / 99.7 | 11 / 99.8 | 17 / 99.8 | 16 / 99.5 | 12 / 99.8 | 13 / 99.8 | 12 / 99.8 | 12 / 99.7 |
| Idea C: BSP + bound | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 18 / 99.8 | 16 / 99.3 | 14 / 99.7 | 16 / 99.8 | 11 / 99.8 | 12 / 99.7 |

R1 has two peaks within 2.2 % of each other (2499 W and 2562 W). M1 and DIRECT stop on the lower one. The bound check finds the higher one.

M2 with λd = 0.05 reaches the 40-probe limit on five patterns. On our array, a duty step of 0.05 moves the voltage by about 30 V. The window is about 15 V wide. The confinement jumps over the window again and again. The value of λd comes from a 3 x 60 W system and does not transfer.

### 5.2 Random patterns, 1800 cases

Ranges over the six random sets (3 shading types, with and without noise). The full tables are in `crosscheck/results_all.md`.

| Method | GMPP found | Worst case | Mean search probes | Max probes | Power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 4 to 60 % | 21.6 % | 0 | 0 | 41 to 58 % |
| M1 | 76 to 96 % | 79.4 % | 2.4 to 2.9 | 4 | 98 % |
| M2 best case, λd 0.05 | 89 to 100 % | 90.1 % | 14.8 to 20.0 | 40 | 92 to 93 % |
| M2 best case, λd 0.01 | 99.7 to 100 % | 96.5 % | 25.8 to 31.4 | 37 | 72 to 78 % |
| M3 | 75 to 99 % | 80.4 % | 9 | 9 | 92 to 94 % |
| M4 DIRECT | 88 to 94 % | 85.9 % | 9.5 to 10.3 | 13 | 95 to 96 % |
| Idea A: DIRECT + bound pruning | 88 to 93 % | 87.7 % | 9.4 to 10.1 | 13 | 95 to 96 % |
| Idea B: DIRECT + bound check | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 | 23 | 95 to 96 % |
| Idea C: BSP + bound | 99.7 to 100 % | 97.9 % | 12.8 to 14.3 | 24 | 94 % |

What the table shows:

1. M1 is the cheapest search (3 probes) and has the highest power in the first second. It fails when the peaks do not sit at the 0.8 Voc positions. On panel-level shading it finds the GMPP in 96 % of cases. On shadow edges and group-level shading, it finds it in only 76 % to 88 %.
2. M3 has the same weakness and costs 9 probes.
3. M2 is reliable only with a perfect window and a small λd. It is then the slowest method (26 to 31 probes), and the window still needs per-module sensors.
4. DIRECT is general but misses 6 % to 12 % of cases. When it misses, it can lose up to 14 % of the power until the next search.
5. Idea B keeps the speed of DIRECT in the first second and removes almost all the misses.

## 6. Answers to the two questions

### 6.1 Is DIRECT the fastest?

No, not on the evidence. We cannot compare the published times directly:

- M2 reports 64 ms with a 5 ms perturbation period.
- M1 reports under 0.2 s, and the paper does not give its sampling period.
- DIRECT reports sample counts at a 50 ms sampling interval on hardware.

On a common harness, M1 needs about 3 probes and M3 needs 9. DIRECT needs about 10, and M2 needs 15 to 31.

The case for DIRECT is different:

- It needs no 0.8 Voc rule, no peak count, and no module model.
- It is the only one of the four methods with hardware results.
- It uses the same topology as our model (buck-boost into 10 Ω).

### 6.2 Can our ideas make DIRECT faster?

Not faster. They make it reliable at almost the same cost.

| Idea (from the ideas note) | Prior art | Result here |
|---|---|---|
| BSP with a DIRECT-like selection rule | Tiong et al. 2017 (conference, binary search that removes regions). Piyavskii 1972 and Shubert 1972 (split where the bound is highest). Added 2026-10-22, see `Notes/direct_literature_and_ideas.md`. | Idea C: as reliable as Idea B, about 13 probes, a little less power in the first second |
| BVH / branch-and-bound with a measured bound | Wang et al. 2016 (same inequality, sequential skip). Abujarad et al. 2026 (branch-and-bound, model bounds). Furtado et al. 2018 (power trapezium). Xu et al. 2021 (monotonic output of the array, added 2026-10-22). | Idea A (pruning) saves 0.1 probes. Idea B (stop test) removes the misses for about 4 probes. |
| Lipschitz bound | DIRECT itself. Li et al. 2019 (LIPO, constant from simulation). | Not run |
| Simulated annealing | Lyden and Haque 2016. Lyden et al. 2021 (SA plus P&O). | Not run. Random search does not give a fixed probe count. |

Why pruning does not help: the 9 globally biased samples of DIRECT are far apart. The bound between two neighbors is therefore almost never below the best power. The bound only becomes tight after DIRECT has finished.

Why the stop test helps: we checked the 26 DIRECT misses of the panel-level set (no noise). In each miss, at least one sample was on the global hill. The gap next to that sample has a bound above the best power. The check splits that gap and finds the hill.

The bound needs no model and no constant. It uses only the fact that the array current does not increase with the voltage. This holds for any series-parallel array with bypass diodes.

## 7. Updated comparison

| Method | Search cost on our array | GMPP found (random) | Measured quantities | Prior data | Evidence | Practicality for our project |
|---|---|---|---|---|---|---|
| M1 | 2 to 4 probes | 76 to 96 % | V, I, Vload | Voc, N, 0.8 rule | Simulation | 2. Fast, but fails on sub-panel shading. Eq. 10 needs changes for our buck-boost. |
| M2 | 15 to 31 probes (best case) | 89 to 100 % | V and I of each module, temperature | Trained ANN | Simulation | 4. Per-module sensors and a trained network. |
| M3 | 9 probes | 75 to 99 % | V, I | Voc, Isc, ξ(G) | Simulation, conference paper | 3. Same weakness as M1, and not a journal source. |
| M4 DIRECT | 9 to 13 probes | 88 to 94 % | V, I | Duty interval | Hardware | 1. General, and on hardware. Needs the bound check (Idea B). |
| DIRECT + bound check | 11 to 23 probes | 99.7 to 100 % | V, I | Duty interval | This cross-check only | Recommended final method |

## 8. Limits of this cross-check

- The curves are static. Converter transients, the 1-sample delay, and the averaging of `MPPT_4x4.slx` are not in it. The probe count is correct, but the time per probe is an assumption (20 ms).
- M1 and M3 have an ideal voltage loop. In our direct-duty model, they need one more loop or a duty mapping. This makes them slower, not faster.
- M2 is a best case. Its estimator is not implemented.
- The cross-check uses one temperature (25 °C). Temperature changes move the 0.8 Voc positions and can hurt M1 and M3 more than DIRECT.
- The random patterns use uniform random irradiance. They are a stress test, not a field distribution.

## 9. Next steps

1. Decide about M3: keep it as a conference reference, or replace it with Bi et al. 2020.
2. Read Wang et al. 2016 and Abujarad et al. 2026 in full before we claim the bound check as new.
3. Implement DIRECT and the bound check in `mppt_controller.m` (mppt.alg = 3 and 4), with the same 20 ms period.
4. Run `run_po_demo.m` on the nine patterns.
5. Compare the Simulink results with section 5.1.
6. Implement M1 with a duty mapping for the buck-boost, so that the comparison in Simulink is fair.

Status on 2026-10-22: item 1 was decided on 2026-10-23: keep M3 and mark it as a conference paper. Item 2 is done (`Notes/novelty_check_ideas_B_C.md`). Items 3 to 5 are done for DIRECT, Idea B and Idea C (`Notes/gmppt_B_C_simulink.md`). Item 6 is not done. The work now covers Ideas B and C only, so M1 stays in the static cross-check.

## 10. Files

| File | Content |
|---|---|
| `Literature/gmppt_global_search.bib` | 17 journal references with DOIs, and the M3 conference reference as a comment |
| `Literature/alombah2025_msmppt_supplementary.docx` | M2 supplementary material (Appendix A to C) |
| `crosscheck/pvarray.py` | Numpy model of the 4 x 4 array |
| `crosscheck/validate_model.py` | Compares the model with the Simulink sweeps in `crosscheck/simulink_curves/` |
| `crosscheck/algos.py` | P&O, M1 to M4, and Ideas A to C |
| `crosscheck/runrand.py` | Random pattern generator and runner |
| `crosscheck/run_all.py` | Makes `results_all.md` and `results_all.json`. Run time about 1.5 min. |
| `crosscheck/run_robust.py` | Ideas B and C under sensor noise, and the tolerance sweep (section 12). Makes `results_robust.md` and `results_robust.json`. Run time about 2 min. |
| `crosscheck/run_simulink_curves.py` | DIRECT, B and C on the Simulink curves, with the log of every probe. Makes `simulink_curves_runs.json` for `gmppt_static_check.m` and `run_settling_check.m`. |

To run again: open a terminal in `crosscheck/` and type `python run_all.py`. It needs Python 3 and numpy only. The scripts write UTF-8 files, also on Windows.

## 11. Baselines from the closest prior art (2026-10-22, task T7)

A reviewer will ask how B and C compare with the closest published methods on the same harness. `crosscheck/algos.py` now has three of them. `run_all.py` prints them in every table of `crosscheck/results_all.md`.

### 11.1 Methods as implemented

| Method | Implementation |
|---|---|
| LIPO (Li et al. 2019, IEEE Access) | Piyavskii-Shubert search on the duty. Sample 0.30 and 0.78, then always the argmax of the upper envelope min_j (P_j + k abs(D - D_j)). Stop when the envelope maximum is below 1.02 P_best, or after 40 probes. The envelope is evaluated on a duty grid of 0.0001. |
| LIPO, k halved | The same, with k / 2. This shows the effect of a constant below the true slope. |
| DIRECT + Lipschitz stop (Khong et al. 2013, Automatica 49(7)) | DIRECT as in M4, up to the hand-over. Then, while an interval has P(centre) + L w / 2 > 1.02 P_best, trisect the interval with the highest bound. The test covers every interval, also the intervals that the skip rules marked dead. Stop after 40 probes. This is Idea B with a Lipschitz bound in place of the measured ceiling. |
| Skip sweep (Boztepe et al. 2014, IEEE TIE) | Measure the start-up point Q (duty 0.30): Pstore = P_Q. The window is [Pstore / Isc_STC, 0.9 Voc_STC]. Probe its lowest voltage. After probe k, Vmin = Pstore / I_k, and the next probe is the lowest grid voltage v_k + j VGSTEP at or above Vmin. Stop above 0.9 Voc_STC. VGSTEP = 0.5 VocP and 1.0 VocP (VocP = 15.3 V, the Voc of one bypass group), the two ends of the range in the paper. Ideal voltage loop, as for M1 and M3. |

The Lipschitz constant is k = L = 44 504 W per unit duty. This is 1.2 times the largest |dP/dD| of the nine project patterns. It is above the largest slope of every random pattern (at most 0.74 k). k / 2 is below the largest slope of 185, 93 and 281 of the 300 panel, edge and group patterns.

A first version of the Lipschitz stop skipped the intervals that the skip rules of DIRECT had marked dead. It then missed 9 edge cases. In two of them the global peak was inside a dead interval. The version above checks every interval, as the ceiling check of Idea B does.

### 11.2 Nine project patterns, no noise

Cells: search probes / final power as a percentage of the GMPP.

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| Idea B | 11 / 99.7 | 12 / 99.7 | 11 / 99.8 | 17 / 99.8 | 16 / 99.5 | 12 / 99.8 | 13 / 99.8 | 12 / 99.8 | 12 / 99.7 |
| Idea C | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 18 / 99.8 | 16 / 99.3 | 14 / 99.7 | 16 / 99.8 | 11 / 99.8 | 12 / 99.7 |
| LIPO, k tuned | 13 / 99.8 | 19 / 99.7 | 19 / 99.8 | 39 / 99.8 | 33 / 99.4 | 31 / 99.8 | 26 / 99.7 | 19 / 99.8 | 21 / 99.8 |
| LIPO, k halved | 5 / 99.8 | 9 / 99.8 | 8 / 99.8 | 21 / 99.8 | 17 / 99.4 | 13 / 99.8 | 13 / 99.7 | 7 / 99.7 | 9 / 99.7 |
| DIRECT + Lipschitz stop | 17 / 99.8 | 25 / 99.8 | 25 / 99.8 | 39 / 99.8 | 39 / 99.4 | 35 / 99.8 | 33 / 99.8 | 21 / 99.8 | 27 / 99.8 |
| Skip sweep, 0.5 VocP | 21 / 99.8 | 17 / 99.8 | 21 / 99.8 | 19 / 99.8 | 14 / 99.4 | 17 / 99.8 | 20 / 99.8 | 21 / 99.8 | 21 / 99.8 |
| Skip sweep, 1.0 VocP | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 11 / 99.8 | 9 / 99.4 | 9 / 99.8 | 11 / 99.8 | 11 / 99.8 | 11 / 99.8 |

### 11.3 Random patterns, 1800 cases

Ranges over the six random sets, as in section 5.2.

| Method | GMPP found | Worst case | Mean search probes | Max probes | Power in first 1 s |
|---|---|---|---|---|---|
| M4 DIRECT | 88.0 to 93.7 % | 85.9 % | 9.5 to 10.3 | 13 | 95 to 96 % |
| Idea B | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 | 23 | 95 to 96 % |
| Idea C | 99.7 to 100 % | 97.9 % | 12.8 to 14.3 | 24 | 94 % |
| LIPO, k tuned | 100 % | 98.1 % | 25.4 to 31.7 | 40 | 89 to 91 % |
| LIPO, k halved | 99.7 to 100 % | 97.5 % | 12.6 to 16.5 | 37 | 93 to 95 % |
| DIRECT + Lipschitz stop | 100 % | 98.1 % | 30.8 to 35.5 | 39 | 88 to 90 % |
| Skip sweep, 0.5 VocP | 99.7 to 100 % | 97.4 % | 17.5 to 18.7 | 21 | 87 % |
| Skip sweep, 1.0 VocP | 94.3 to 99.3 % | 95.0 % | 10.2 to 10.5 | 11 | 92 % |

### 11.4 What the baselines show

1. With a constant that is a valid bound, the Lipschitz methods are reliable but slow. LIPO needs about twice the probes of C, and it often stops at the 40-probe limit. The Lipschitz stop for DIRECT needs about 2.3 times the probes of B. A valid constant must cover the steepest slope of the curve, so the bound is loose on the flat parts.
2. **LIPO with half the constant does as well as Idea C on these sets.** Its envelope is then not an upper bound on most curves. It still misses at most 1 case in 300, with a mean of 12.6 to 16.5 probes. So C is not better than a well-chosen LIPO on cost or on the miss rate. The difference is the type of guarantee. C needs no constant, and its stop test is a certificate under the conditions of section 4.4 of `HANDOFF_ideas_B_C.md`. LIPO with k / 2 gives no guarantee, and its good result depends on the test sets.
3. The skip sweep of Boztepe with VGSTEP = 1.0 VocP is the cheapest baseline (about 10 probes). It misses 1 to 6 % of the cases, most of them on the group set. With 0.5 VocP it misses at most 1 case in 300, for about 18 probes. Its one-way scan spends many probes at voltages where the power is low, so with 0.5 VocP its power in the first second is the lowest of all reliable methods (87 %). It also needs a voltage loop, which our direct-duty model does not have.
4. Of the reliable methods, Idea B keeps the highest power in the first second (95 to 96 %). Idea C and LIPO with k / 2 follow (93 to 95 %).

## 12. Sensor noise and the two tolerances (2026-10-22, task T8)

Script: `crosscheck/run_robust.py`. Results: `crosscheck/results_robust.md`. The three random sets are pooled (900 cases). A miss is a final power below 98 % of the GMPP.

### 12.1 Robust ceiling

With a relative error of at most delta on each sensor, the true ceiling of a gap is at most V1 (1 + delta) I2 (1 + delta), and the true best power is at least P_best (1 - 2 delta). The robust test compares these two values. This is the notion of robustness to bounded measurement error of Khong et al. (2013, Automatica 49(9), Assumption 7). The test runs with delta = 0 and with delta = 3 times the noise level. The noise is Gaussian, so 3 standard deviations bound almost every sample.

A search miss is a case where the hand-over duty is not on the global hill: P&O with no noise, from the same hand-over duty, ends below 98 % of the GMPP. The other misses come from the noise in the P&O stage after a correct search.

| Method | Noise | delta | Misses | Search misses | Worst case | Mean search probes | Max probes | Power in first 1 s |
|---|---|---|---|---|---|---|---|---|
| Idea B | 0 | 0 | 0 | 0 | 99.0 % | 14.4 | 23 | 95.4 % |
| Idea B | 0.5 % | 0 | 1 | 1 | 97.5 % | 14.1 | 23 | 95.3 % |
| Idea B | 0.5 % | 1.5 % | 0 | 0 | 98.1 % | 18.9 | 34 | 94.5 % |
| Idea B | 1 % | 0 | 38 | 9 | 94.1 % | 13.7 | 21 | 95.2 % |
| Idea B | 1 % | 3 % | 47 | 10 | 94.9 % | 22.5 | 37 | 93.3 % |
| Idea B | 2 % | 0 | 194 | 47 | 91.1 % | 13.1 | 22 | 94.7 % |
| Idea B | 2 % | 6 % | 195 | 39 | 90.4 % | 28.9 | 47 | 90.4 % |
| Idea C | 0 | 0 | 0 | 0 | 99.0 % | 13.8 | 24 | 94.1 % |
| Idea C | 0.5 % | 0 | 2 | 1 | 97.9 % | 13.6 | 24 | 94.0 % |
| Idea C | 0.5 % | 1.5 % | 2 | 1 | 97.3 % | 18.6 | 31 | 92.7 % |
| Idea C | 1 % | 0 | 41 | 8 | 95.4 % | 13.2 | 22 | 93.9 % |
| Idea C | 1 % | 3 % | 43 | 15 | 94.1 % | 22.6 | 37 | 91.1 % |
| Idea C | 2 % | 0 | 190 | 44 | 90.2 % | 12.4 | 23 | 93.5 % |
| Idea C | 2 % | 6 % | 189 | 59 | 89.5 % | 29.1 | 48 | 87.9 % |

What the table shows:

1. At 0.5 % noise, B and C each have 1 search miss in 900 cases. The controller averages 200 samples for each search probe (`mppt.Navg_s`), so 0.5 % on the averages is a realistic level.
2. At 1 % and 2 % noise, about three quarters of the misses come from the P&O stage. P&O with a step of 0.005 cannot hold the peak when the power noise is larger than the power change of one step.
3. The robust ceiling does not reduce the search misses in a consistent way. For Idea B at 2 % noise they fall from 47 to 39. For Idea C they rise, from 8 to 15 at 1 % and from 44 to 59 at 2 %. The robust test adds 5 to 17 probes. A likely cause is the choice of the hand-over sample, not the certificate. The search hands over at the sample with the highest measured power. When two hills are close in power, a noisy sample on the lower hill can win, and more samples give more chances for this. This project has not tested this explanation.
4. Under noise, the certificate holds only for the measured values. A stronger hand-over, for example a second measurement of the best two samples before the hand-over, would address point 3. This project does not test it.

### 12.2 Tolerance sweep

No noise. Cells: mean search probes / misses / worst case.

| Idea B: eps | tol = 0.005 | tol = 0.01 | tol = 0.02 |
|---|---|---|---|
| 0 | 20.5 / 0 / 99.0 % | 16.1 / 0 / 99.0 % | 13.2 / 2 / 96.9 % |
| 0.01 | 18.3 / 0 / 99.0 % | 15.2 / 0 / 99.0 % | 12.9 / 2 / 96.9 % |
| 0.02 | 15.7 / 0 / 99.0 % | 14.4 / 0 / 99.0 % | 12.7 / 2 / 96.9 % |
| 0.05 | 11.9 / 0 / 98.7 % | 11.9 / 0 / 98.7 % | 11.8 / 2 / 96.9 % |

| Idea C: eps | tol = 0.005 | tol = 0.01 | tol = 0.02 |
|---|---|---|---|
| 0 | 19.5 / 0 / 99.1 % | 15.5 / 0 / 99.0 % | 12.2 / 0 / 98.2 % |
| 0.01 | 17.6 / 0 / 99.1 % | 14.6 / 0 / 99.0 % | 11.8 / 0 / 98.2 % |
| 0.02 | 15.6 / 0 / 99.1 % | 13.8 / 0 / 99.0 % | 11.4 / 0 / 98.2 % |
| 0.05 | 11.0 / 0 / 98.6 % | 11.0 / 0 / 98.6 % | 10.3 / 0 / 98.2 % |

What the sweep shows:

1. The duty tolerance tol sets the risk. With tol = 0.02, Idea B misses 2 cases in 900. A gap of 0.02 in duty is about 15 V near the peaks, and it can hide a narrow peak. Idea C has no miss at any setting, but its worst case falls to 98.2 % with tol = 0.02.
2. eps sets most of the cost. From eps = 0 to eps = 0.05, the mean cost falls by 1.4 to 8.6 probes, with no new miss. The fall is largest with the smallest tol.
3. The present values (eps = 0.02, tol = 0.01) keep a margin on both. eps = 0.05 with tol = 0.01 saves 2.5 to 2.8 probes (100 to 110 ms at 40 ms for each probe) for a worst case of 98.6 to 98.7 %.

## 13. Two baselines for Idea B, and Idea B refined (2026-11-08)

`crosscheck/run_all.py` now has four more rows: DIRECT as written in Nguyen and Low (2010), PSO after Ishaque et al. (2012) with 3 and with 5 particles, and Idea B refined. The rows of sections 5 and 11 did not change. `Notes/idea_B_theory_and_baselines.md` gives the methods, the choices for the values that the papers leave open, the theory and the ablation.

Correction. The row "M4 DIRECT" of sections 5 and 11 is a simplified form of Nguyen and Low (2010), not the method as written. It differs in three steps (`Notes/idea_B_theory_and_baselines.md`, section 5.1).

Random patterns, 1800 cases, ranges over the six sets:

| Method | GMPP found | Worst case | Mean search probes | Max probes | Power in first 1 s |
|---|---|---|---|---|---|
| M4 DIRECT, simplified | 88.0 to 93.7 % | 85.9 % | 9.5 to 10.3 | 13 | 95 to 96 % |
| DIRECT as in the paper | 90.0 to 97.0 % | 89.2 % | 12.1 to 13.5 | 16 | 94 to 96 % |
| PSO, 3 particles | 93.3 to 98.0 % | 74.9 % | 31.0 to 32.5 | 60 | 89 to 90 % |
| PSO, 5 particles | 95.0 to 99.0 % | 77.8 % | 56.3 to 58.8 | 100 | 85 to 87 % |
| Idea B | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 | 23 | 95 to 96 % |
| Idea B refined | 100 % | 98.0 % | 11.7 to 13.9 | 24 | 96 % |

What the rows show:

1. The form of DIRECT that follows the paper misses fewer cases than the simplified form (3 to 10 % against 6 to 12 %), but it still misses. It costs 2 to 3 more probes.
2. PSO with three particles misses 2 to 7 % of the cases and costs about three times the probes of DIRECT. Its worst case (74.9 %) is the lowest of all global searches here. Five particles reduce the misses but double the cost.
3. Idea B refined finds the GMPP in every case of the six sets, with fewer probes than Idea B. On panel and edge shading it also needs fewer probes than DIRECT as in the paper.
