---
title: Novelty check for Ideas B and C, what we borrow and what we add
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-10-22
status: prior art read in full text, ideas tested on static curves only
---

# Novelty check for Ideas B and C

## 1. Summary

- **No single paper has the combination that B and C share.** That combination is (a) a ceiling on the power in a duty gap, computed only from the measured V and I of the two neighbouring samples, (b) no Lipschitz constant, datasheet limit, model or module count, and (c) a stop test that certifies every remaining gap.
- **Every part of that combination exists on its own.** The inequality is in Boztepe 2014 and Wang 2016. Best-first search by a bound with a certificate stop is in Abujarad 2026 (model bounds) and Khong 2013 (Lipschitz bounds). Halving is in Chiter 2005, BIRECT, HALRECT and Tiong 2017. Shubert-type search in duty space is in Li 2019 (LIPO).
- **Idea B** has the safer claim: a model-free certification step for the hardware-validated DIRECT tracker of Nguyen and Low (2010). It replaces their heuristic hand-over rule. Khong et al. (2013) already added a bound-based stop to DIRECT, but theirs needs a known Lipschitz constant.
- **Idea C** is a member of the Piyavskii-Shubert family of interval branch-and-bound methods. Its new part is narrow: the Lipschitz envelope is replaced by the measured monotone-current ceiling. As a result, C needs no tuned constant and ends with an explicit certificate. LIPO (Li 2019) and PRISM (Abujarad 2026) are the closest GMPPT methods.
- **Both claims are still unproven outside our static-curve harness.** The closest prior art has hardware results (Nguyen and Low, Xu, Abujarad, Li, Boztepe, Wang). We need at least the Simulink results with converter dynamics.
- **Update 2026-10-22: Simulink results now exist** (`Notes/gmppt_B_C_simulink.md`). In the model with the averaged converter, B and C reach the global peak on all nine project patterns (99.4 to 99.8 %). DIRECT stops on the lower peak of R1 (97.5 %). The controller applies the duty sequence that the static model predicts, on all 27 searches. A valid ceiling needs a 40 ms probe in this converter, so a search takes 0.42 to 0.78 s. There are still no hardware results.
- **Update 2026-10-22: the baselines of section 8 now run on the same harness** (`Notes/gmppt_m1_m4_comparative_study.md`, section 11). With a valid constant, LIPO and the Lipschitz stop of Khong are as reliable as B and C but need about twice the probes. LIPO with half the constant is as reliable and as cheap as C on our sets, but its bound is then not valid. So the case for C rests on the constant-free certificate, not on cost.

## 2. What B and C do

### 2.1 The ceiling

Take two neighbouring samples at duties d1 < d2, with measured (V1, I1) and (V2, I2).

1. The buck-boost into a fixed load maps duty to voltage monotonically: R_pv = R (1 - D)^2 / D^2 falls as D rises. So V1 >= V2.
2. The current of a series-parallel array with bypass diodes does not rise when the voltage rises. Each string has this property, and parallel strings add their currents.
3. For any duty d in [d1, d2], the voltage V(d) is between V2 and V1. Thus V(d) <= V1, and I(d) <= I(V2) = I2.
4. So P(d) <= V1 x I2 for every point in the gap.

Conditions for the ceiling to hold:

- Each sample is taken in steady state. Update 2026-10-22: a 20 ms probe is too short for a large duty jump, so a search probe lasts 40 ms (`Notes/pv4x4_shading_and_po.md`, section 5.1).
- The irradiance and temperature do not change during the search.
- The duty-to-voltage map is monotonic (true for the usual converters in continuous conduction).
- The sensors are exact. With bounded sensor error, the ceiling must be widened (section 8).

### 2.2 Idea B

1. Run a simplified form of the DIRECT of Nguyen and Low (2010): PSC test, globally biased trisection (9 samples), skip rules, then locally biased trisection. Correction of 2026-11-08: this form departs from the paper in three steps (the case where only one shading test holds, the skip rules, and the local stop). `Notes/idea_B_theory_and_baselines.md`, section 5.1, lists them. A form that follows the paper is now `mppt.alg = 6`.
2. Before the hand-over to P&O, sort all DIRECT samples by duty.
3. For each pair of neighbours, compute the ceiling V1 x I2.
4. If the gap with the highest ceiling exceeds 1.02 times the best power and is wider than 0.01 in duty, sample its midpoint. Repeat.
5. When no gap fails, hand over to P&O from the best sample.

### 2.3 Idea C

1. Sample D = 0.30, 0.54 and 0.78.
2. Compute the ceiling of every gap between neighbours.
3. Sample the midpoint of the gap with the highest ceiling, if that ceiling exceeds 1.02 times the best power and the gap is wider than 0.01 in duty.
4. Repeat until no gap fails. Then hand over to P&O from the best sample.

### 2.4 Results so far (1800 random cases, static P-V curves, `crosscheck/`)

| Method | GMPP found | Mean search samples |
|---|---|---|
| DIRECT (Nguyen and Low) | 88 to 94 % | 9.5 to 10.3 |
| Idea A: the ceiling as a pruning rule inside DIRECT | 88 to 93 % | 9.4 to 10.1 |
| Idea B | 99.7 to 100 % | 13.6 to 15.5 |
| Idea C | 99.7 to 100 % | 12.8 to 14.3 |

## 3. The prior art that we read

All PDFs are in `Literature/`. The per-paper notes are in `Notes/prior_art_reading_notes_B_C.md`.

| Paper | Type | What it shares with B or C | What is different |
|---|---|---|---|
| Nguyen and Low 2010, IEEE TIE | Journal, hardware | Base of B. DIRECT in duty, P&O hand-over | Hand-over when "the two samples that have the highest powers are consecutive". No bound, no certificate |
| Low et al. 2011, ISPACS | Conference | DIRECT tracker | Fast irradiance change, single peak |
| Boztepe et al. 2014, IEEE TIE | Journal, hardware | The ceiling in measured form: V_min = P_store / I_1 | One-way scan on a voltage grid. Uses Voc and Isc at STC and a fixed 0.9 Voc limit |
| Wang et al. 2016, IEEE TIE | Journal, hardware | Same inequality: jump to V = P_m / I_sc(j+1) | One-way scan. The judge step uses a 0.85 Isc heuristic |
| Furtado et al. 2018, IEEE TIE | Journal, hardware | Region that holds every GMPP | Bounds from STC datasheet values. Sweep |
| Kermadi et al. 2019, IEEE TIE | Journal, hardware (PV simulator) | The Wang skip inside PSO | Random search. No certificate |
| Kermadi et al. 2021, IEEE TIE | Journal, hardware | Skip zones, upward and downward scans | Sweep |
| Xu et al. 2021, IEEE TIE | Journal, hardware | Uses the monotone I-V curve to end the scan | Global limits from STC values (I_GMPP,STC, 0.9 Voc,STC). Sweep |
| Zhou et al. 2022, IEEE TIE | Journal, hardware | Skip in duty | Sweep |
| Sun et al. 2023, IEEE TSTE | Journal, hardware | Many skip passes | Sweep |
| Ahmed et al. 2023, IEEE TPEL | Journal, hardware | I_min = P_best / 0.9 Voc stop | 0.8 Voc peak spacing. Sweep |
| Aquib et al. 2020, IEEE TPEL | Journal, hardware | Skip | Settling-time test, not a power bound |
| Li et al. 2019, IEEE Access | Journal, hardware | Piyavskii-Shubert in duty: ends first, then sample at the highest bound | Lipschitz constant k = 1500 from simulation. Stops on iteration count |
| Tiong et al. 2017, CENCON | Conference, simulation | Binary search in duty that drops "the region where the MPP cannot lie" | The drop is a power comparison, not a bound. Trapped at a local peak in at least one case |
| Kumaresan et al. 2022, ECCE | Conference, simulation | Bisection with a 2 % tolerance | Bisection on the power level, not on duty |
| Ramana et al. 2018, eTechNxT | Conference, hardware | "Bisection" | Root finding for a duty, not a search partition |
| Abujarad et al. 2026, IEEE TPEL | Journal, hardware | Best-first branch-and-bound in duty, stop when no bound beats the best, "identified with certainty" | Bounds from a calibrated logistic I-V model per layer. Needs the module count |
| Hadiby et al. 2026, IEEE JESTPE | Journal, hardware | Search space reduction | Random agents. No bound |
| Bharadwaj and John 2021, IEEE Access | Journal, hardware | "Rectangular power comparison" | Predicted peak powers from per-module voltage sensors. Not a bound |
| Jones and Martins 2021, J Glob Optim | Journal (review) | DIRECT, its stop rules, its variants | DIRECT stops on a budget only |
| Sergeyev and Kvasov 2006, SIAM J Optim | Journal | End-point sampling, lower bounds over intervals | Set of Lipschitz constants. Trisection |
| Chiter 2005, AMC | Journal | 1-D DIRECT with bisection | Samples at 1/3 and 2/3. Potential optimality |
| BIRECT 2018, HALRECT 2024, J Glob Optim | Journal | Bisection forms of DIRECT | Lipschitz-based selection. n-D benchmarks |
| Nešić et al. 2013, Automatica | Journal | Shubert as a sampled-data extremum seeker | Known Lipschitz constant |
| Khong et al. 2013, Automatica 49(7) | Journal | DIRECT with a bound-based stop, then hold the input | Bound from a known Lipschitz constant. Simulation |
| Khong et al. 2013, Automatica 49(9) | Journal | Framework, robustness to bounded measurement error | General theory |

## 4. Feature comparison

Y = yes, P = partly, N = no.

| Paper or idea | Ceiling from two measured neighbours | Needs no constant, model or datasheet limit | Best-first by bound | Halving | Certificate stop | Duty domain | Hardware |
|---|---|---|---|---|---|---|---|
| Boztepe 2014 | P (one sample plus best power) | N (STC values, 0.9 Voc) | N | N | P | N | Y |
| Wang 2016 | P (one sample plus best power) | N (Voc, 0.85 factor) | N | N | P | N | Y |
| Xu 2021 | N (global limits) | N (STC values) | N | N | P | N | Y |
| Li 2019 (LIPO) | N (Lipschitz) | N (k = 1500) | Y | N | N | Y | Y |
| Tiong 2017 | N (comparison) | Y | N | Y | N | Y | N |
| Abujarad 2026 (PRISM) | N (model) | N (logistic model, module count) | Y | N | Y (model-based) | Y | Y |
| Nguyen and Low 2010 | N | Y | N (DIRECT) | N (trisection) | N | Y | Y |
| Khong 2013 (DIRECT ES) | N (Lipschitz) | N (known L) | N (DIRECT) | N | Y | general | N |
| Shubert 1972, Nešić 2013 | N (Lipschitz) | N (known L) | Y | N | Y | general | N |
| Chiter 2005, BIRECT, HALRECT | N | Y | N (DIRECT-type) | Y | N | general | N |
| **Idea B** | **Y** | **Y** | **Y (inside the check)** | **Y (inside the check)** | **Y** | **Y** | **not yet** |
| **Idea C** | **Y** | **Y** | **Y** | **Y** | **Y** | **Y** | **not yet** |

## 5. Idea B: what we borrow and what we add

### 5.1 Borrowed

| Part of B | Source |
|---|---|
| The DIRECT method: trisection, potentially optimal intervals, epsilon | Jones, Perttunen and Stuckman 1993 |
| DIRECT for GMPPT: duty interval, PSC test, globally and locally biased modes, skip rules, P&O hand-over, buck-boost at 20 kHz | Nguyen and Low 2010 |
| Global stage followed by a local search | Nguyen and Low 2010, and DIRECT plus local search in general (DIRMIN, as described in Jones and Martins 2021) |
| The inequality P <= V(high-voltage end) x I(low-voltage end) | Boztepe et al. 2014, Wang et al. 2016, then Kermadi 2019, Xu 2021 |
| The idea of a bound-based stop rule for DIRECT | Khong et al. 2013 (Automatica 49(7)), after Piyavskii and Shubert |
| Best-first refinement by bound with a certificate stop | Lipschitz branch-and-bound (Shubert 1972, as restated by Nešić 2013), Abujarad et al. 2026 in GMPPT |
| Restart on a power change plus a timer | Boztepe 2014, Wang 2016, Xu 2021 |
| Hold the duty, wait, measure, choose the next duty | Sampled-data extremum seeking (Nešić 2013, Khong 2013) |

### 5.2 New

1. **A model-free certificate for DIRECT-based GMPPT.** The bound uses only the measured V and I of neighbouring samples and the non-increasing I-V curve. It needs no Lipschitz constant (unlike Khong 2013), no STC datasheet limits (unlike Xu 2021 and Furtado 2018), and no calibrated model or module count (unlike Abujarad 2026).
2. **It replaces a heuristic in a hardware-validated tracker.** Nguyen and Low hand over when the two best samples are neighbours, and then "the GP's region is considered to be found". B tests that assumption with a bound. When the test fails, B samples more instead of only reporting it.
3. **It gives DIRECT a meaningful stop rule in this setting.** Sergeyev and Kvasov (2006) write that "it is difficult to apply for DIRECT some meaningful stopping criterion". Jones and Martins (2021) write that better behaviour needs knowledge that allows bounds over subregions. The PV current property supplies that knowledge.
4. **An honest pair of results.** The same bound saves almost nothing as a pruning rule inside DIRECT (Idea A, 0.1 samples). The reason is that the early DIRECT samples are far apart. As a final certificate, it cuts the misses from 6 to 12 % to 0 to 0.3 % for about 4 more samples.

### 5.3 Risk

- **Medium.** A reviewer will cite Khong 2013 for "a bound-based stop for DIRECT" and Boztepe 2014 or Wang 2016 for the inequality. Our claim survives only if we state clearly that the new part is the combination: a measured ceiling with no constant, used as a certificate, inside the published PV DIRECT.

## 6. Idea C: what we borrow and what we add

### 6.1 Borrowed

| Part of C | Source |
|---|---|
| 1-D search that samples where the upper bound is highest and stops when the best is near the bound | Piyavskii 1972, Shubert 1972 |
| The same rule in duty space for GMPPT, both ends sampled first | Li et al. 2019 (LIPO) |
| Halving with reuse of samples | Chiter 2005, BIRECT 2018, HALRECT 2024 |
| Sampling the ends of each interval | Diagonal methods (Sergeyev and Kvasov 2006) |
| Binary search for MPPT under partial shading | Tiong et al. 2017, Kumaresan et al. 2022 |
| Best-first branch-and-bound with a certificate stop in GMPPT | Abujarad et al. 2026 |
| Three seeds at the low, middle and high end of the duty range | Abujarad et al. 2026 (0.4, 0.6, 0.8), Nguyen and Low 2010 (first three samples) |
| The ceiling inequality | Boztepe 2014, Wang 2016 |
| P&O hand-over, restart triggers | Common practice (Nguyen and Low, Xu, Wang) |

### 6.2 New

1. **The Lipschitz envelope is replaced by a physical ceiling.** Shubert and LIPO bound the power with a constant that must be known or tuned. LIPO uses k = 1500 from simulations of one array. C bounds each gap with V1 x I2 from its two measured ends, so nothing is tuned, and the bound holds for any series-parallel array with bypass diodes.
2. **Regions are dropped only when physics proves they cannot win.** Tiong's binary search drops a half after a power comparison, which assumes one peak, and it was trapped at a local peak. C keeps every gap whose ceiling can still beat the best.
3. **An explicit certificate with two tolerances.** At the end, every gap wider than 0.01 in duty has a ceiling within 2 % of the best power. LIPO stops on an iteration count. PRISM gives a certificate that depends on its fitted model.
4. **One sample per split.** The two ends of a gap are shared with its children, so each split costs one new sample. DIRECT trisection costs two. This is a known property of end-point bisection in 1-D, so it is a design benefit, not a novelty.

### 6.3 Risk

- **High for the method, medium for the bound.** The search structure is the 1-D Lipschitz branch-and-bound family, and LIPO already brought that family to GMPPT. The defensible claim is the measured, constant-free ceiling and the certificate that follows from it.
- C is your own idea and you reached it independently. That still does not make the structure new. The thesis should say so plainly. Examiners respect that more than a claim that a reviewer can break with one citation.

## 7. Claims

### 7.1 How the thesis describes B and C

Decision of 2026-10-22: this is a B.Tech project. Its aim is a correct implementation and an honest evaluation, not a new method. The thesis therefore calls both ideas implementations and names the source of every part. It does not use "novel", "first" or "proposed method" for a borrowed structure.

- **B:** "We implement the DIRECT-based GMPPT of Nguyen and Low (2010). Before the hand-over to P&O, we add a check from the scan-and-skip literature (Boztepe et al. 2014, Wang et al. 2016): the power between two neighbouring samples cannot exceed V(left) x I(right). Khong et al. (2013) stop DIRECT with a bound that needs a Lipschitz constant. Our check uses the measured current instead, so it needs no constant."
- **C:** "We implement a best-first bisection search of the Piyavskii-Shubert type (Shubert 1972), as LIPO does for GMPPT (Li et al. 2019). In place of the Lipschitz bound, each gap uses the measured ceiling V(left) x I(right) of Boztepe et al. (2014) and Wang et al. (2016)."
- **The work of this project:** the implementation of both methods on the model of the 4 x 4 Emmvee E325P72 array, the comparison with M1 to M4 on 1800 random shading cases, and the finding that the ceiling helps as a final check but not as a pruning rule inside DIRECT. The thesis states these as results of this project.

### 7.2 Claims we must not make

- "First use of the V x I bound in GMPPT." Boztepe 2014 and Wang 2016 use it.
- "First branch-and-bound GMPPT." Abujarad 2026 is one, and LIPO is a Shubert-type search.
- "First binary-search GMPPT." Tiong 2017 and Kumaresan 2022 exist, and binary-search MPPT for uniform irradiance is older.
- "First stop criterion for DIRECT." Khong 2013 gives one.
- "Guaranteed GMPP" without the conditions in section 2.1 and the two tolerances.
- "DIRECT is the fastest method." Our cross-check does not support it.
- "A new split rule" for the corner split of Idea B refined. It is the projection step of the polyblock algorithm (section 11).
- "A new kind of certificate". Monotonic optimization gives the same kind (section 11).

## 8. Work that makes the evaluation stronger

1. **Write the ceiling as a lemma with a proof.** State the four conditions of section 2.1. The proof takes five lines and makes the certificate a formal result, not a heuristic.
2. **Make the ceiling robust to sensor error.** With relative errors dV and dI, use V1 (1 + dV) x I2 (1 + dI) against P_best (1 - dV - dI). This gives a certificate under bounded measurement error, which is the robustness notion of Khong et al. (2013, Assumption 7). No GMPPT paper that we read does this. Wang uses a 0.85 factor instead.
3. **Add the closest baselines to `crosscheck/`.** LIPO with k tuned on our array, and the Lipschitz stop of Khong 2013 applied to DIRECT. Add the Boztepe or Wang skip sweep as the measured-bound baseline. A reviewer will ask for these comparisons first.
4. **Run B and C in Simulink with the converter dynamics.** Then report the probe count, the miss rate, the worst case and the energy lost during the search (the metric of Xu 2021).
5. **Report how the tolerances trade off.** Vary epsilon and the duty tolerance, and show the cost in samples against the miss rate. This shows how the certificate works in practice.

Status on 2026-10-22:

| Item | Status | Where |
|---|---|---|
| 1. Lemma with proof | Done | `HANDOFF_ideas_B_C.md` section 4.4, `Notes/thesis_text_B_C.md` section 1.2 |
| 2. Robust ceiling | Done. The robust test does not reduce the misses under noise in a consistent way. Most misses at 1 % and 2 % noise come from the P&O stage. | `Notes/gmppt_m1_m4_comparative_study.md` section 12.1 |
| 3. Baselines | Done: LIPO (tuned k and k / 2), DIRECT with the Lipschitz stop of Khong, skip sweep of Boztepe (two grid steps) | same note, section 11 |
| 4. Simulink | Done: settling check, port check, controller check, start-up runs, restart, single-group shading. No hardware. | `Notes/gmppt_B_C_simulink.md` |
| 5. Tolerance trade-off | Done | `Notes/gmppt_m1_m4_comparative_study.md` section 12.2 |

## 9. Sources not obtained in full text

| Paper | Reason | What we used instead |
|---|---|---|
| Piyavskii 1972, Shubert 1972 | SIAM and Elsevier, no institute access | Exact restatements in Nešić 2013 and Khong 2013 |
| Jones et al. 1993 | Springer, no institute access | Jones and Martins 2021 (section 2.1), Nguyen and Low 2010 (section III) |
| Gablonsky and Kelley 2001, Paulavičius et al. 2018 (BIRECT) | Springer, no institute access | Jones and Martins 2021, Stripinis and Paulavičius 2024 |
| Elsevier versions of the Automatica papers | ScienceDirect showed a CAPTCHA | Accepted author versions from the University of Melbourne repository |

## 10. Files

| File | Content |
|---|---|
| `Notes/prior_art_reading_notes_B_C.md` | Notes for each paper: search variable, bound, pattern, stop rule, hand-over, validation |
| `Literature/*.pdf` | 37 papers, named by their BibTeX keys |
| `Literature/gmppt_global_search.bib`, `Literature/direct_algorithm.bib` | References |

## 11. Correction of 2026-11-08: monotonic optimization

A check of the global optimization literature for Idea B refined found a closer source than the ones in section 3.

- The region under the I-V curve is a normal set, and P = V I increases in V and in I. The GMPP is therefore a monotonic optimization problem (Tuy 2000, SIAM J. Optim. 11(2)).
- The ceiling V1 x I2 of a gap is the value of a polyblock vertex. Best-first search over these vertices, with a stop when no vertex beats (1 + eps) times the best value, is the polyblock algorithm (Zhang, Qian and Huang 2012, section 3.2, Algorithm 2).
- The corner split of Idea B refined is the projection step of that algorithm (`Notes/idea_B_theory_and_baselines.md`, section 3.5).
- Idea C with a midpoint split is, in one dimension, the mixed monotonic programming algorithm of Matthiesen et al. (2020, IEEE Trans. Signal Process. 68), with a best-first choice and a relative tolerance.

Effect on the claims:

1. Sections 5.2 (items 1 and 3) and 6.2 (items 1 and 3) are too strong as written. A constant-free certificate from monotonicity alone is standard in monotonic optimization.
2. What remains: we found no GMPPT paper that uses monotonic optimization. The work of this project is its application to a duty-controlled converter, where one duty setting does the projection, plus the implementation and the measured results.
3. Suggested wording for the thesis: "The ceiling check is an instance of monotonic optimization (Tuy 2000). Each gap is a polyblock vertex with the value V1 I2 (Boztepe et al. 2014, Wang et al. 2016), and the refined form splits a gap at the projection of that vertex (Zhang et al. 2012, section 3.2)."
4. The risk of section 5.3 rises from medium to high for any claim about the bound or the certificate. It stays low for the claims about the implementation and the results.
