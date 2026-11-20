---
title: Thesis text, global search with a measured power ceiling (draft)
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-10-22
status: draft for the methods and results chapters (task T9 of HANDOFF_ideas_B_C.md)
---

# Thesis text: global search with a measured power ceiling

Notes for the authors, not for the thesis:

- The working labels of the project are Idea B and Idea C. The text below calls them "the DIRECT tracker with a ceiling check" and "the ceiling-guided bisection". The user accepted these names on 2026-10-23.
- M3 (Kouchaki 2023) stays as a comparison baseline. The thesis marks it as a conference paper (decision of 2026-10-23).
- Citations use the BibTeX keys of `Literature/gmppt_global_search.bib` and `Literature/direct_algorithm.bib`. Conference papers are marked as conference papers.
- The wording follows `Notes/novelty_check_ideas_B_C.md`, section 7. Section 4 of this file lists the claims that the thesis must not make.
- The numbers come from `Notes/gmppt_m1_m4_comparative_study.md` (static cross-check), `Notes/gmppt_B_C_simulink.md` (Simulink) and `Notes/pv4x4_shading_and_po.md` (model and settling).

## 1. Methods

### 1.1 The tracking problem

The array is a 4 x 4 series-parallel array of Emmvee E325P72 panels. Each panel has three bypass diodes. Under partial shading, the P-V curve of the array has several peaks. P&O and incremental conductance stop on the first peak that they reach. In our model, P&O from start-up reaches only 46.6 % of the global peak under row shading and 34.9 % under an inter-row shadow.

The tracker sets the duty cycle D of a buck-boost converter directly, with no voltage loop. The converter feeds a 10 Ohm load. In steady state, the converter input resistance is R_in = (R (1 - D)^2 + R_L) / D^2, where R is the load resistance and R_L the inductor resistance. A higher duty gives a lower array voltage. The global search therefore works on the duty interval [0.30, 0.78], which covers the array voltage from near Voc down to about 0.15 Voc.

A global search applies a sequence of duty values (probes). For each probe, the controller waits for the converter to settle and then measures the average array voltage and current. The search ends with a hand-over to P&O at the best duty.

### 1.2 A power ceiling between two samples

Lemma. Suppose that the array current I(V) does not increase with V, and that the converter maps duty to voltage monotonically, so that d1 < d2 gives V(d1) >= V(d2). Take steady-state samples (V1, I1) at d1 and (V2, I2) at d2. Then every duty d in [d1, d2] gives P(d) <= V1 I2.

Proof. Monotonicity gives V2 <= V(d) <= V1. Because I(V) does not increase, V(d) >= V2 gives I(d) <= I(V2) = I2. Thus P(d) = V(d) I(d) <= V1 I2.

Conditions:

1. Each string of cells with bypass diodes has a current that does not increase with V, and parallel strings add their currents. So the property holds for any series-parallel array with bypass diodes.
2. Each sample is in steady state.
3. The irradiance and the temperature do not change during the search.
4. The sensors are exact. With a relative error of at most delta on each sensor, the true ceiling is at most V1 (1 + delta) I2 (1 + delta), and the true best power is at least P_best (1 - 2 delta).

The inequality is not new. Boztepe et al. use it in measured form to skip voltages in a one-way scan [boztepe2014rvw]. Wang et al. use it to jump over a voltage interval [wang2016ssj]. This work uses the same inequality for every gap between two neighbouring samples of a search, and as a stop test.

### 1.3 The DIRECT tracker with a ceiling check

We implement a simplified form of the DIRECT-based GMPPT of Nguyen and Low [nguyen2010direct]. Before the hand-over to P&O, we add a check from the scan-and-skip literature [boztepe2014rvw, wang2016ssj]: the power between two neighbouring samples cannot exceed V(left) x I(right). Khong et al. stop DIRECT with a bound that needs a Lipschitz constant [khong2013directes]. Our check uses the measured current instead, so it needs no constant. The check is an instance of monotonic optimization [tuy2000monotonic]: the region under the I-V curve is a normal set, P = V I increases in V and in I, and each ceiling is the value of a polyblock vertex [zhang2012monotonic].

Steps:

1. Run a simplified form of the DIRECT of [nguyen2010direct]: the partial-shading test on the first three samples, the globally biased stage with skip rules, the two extra cycles when the two best samples are not neighbours, and the locally biased trisection of the best interval while its width divided by 3 is 0.005 in duty or more. This form departs from the paper in three steps: it treats the case where only one shading test holds as uniform, its skip rules 1 and 2 drop a whole third and rules 3 and 4 are absent, and its local stage stops one trisection earlier than Eq. (21) of the paper.
2. Put all the samples (duty, V, I) in one list, in order of duty.
3. For each pair of neighbours d1 < d2, compute the ceiling U = V1 I2.
4. Keep the gaps with U > (1 + eps) P_best and d2 - d1 > tol. We use eps = 0.02 and tol = 0.01.
5. If no gap is left, go to step 6. Else sample the midpoint of the gap with the highest U, and go to step 2.
6. Hand over to P&O at the sample with the highest power.

Sources of the parts:

| Part | Source |
|---|---|
| DIRECT: trisection, potentially optimal intervals | Jones et al. [jones1993direct], as described in [jones2021direct25] |
| DIRECT for GMPPT: duty interval, shading test, global and local stages, skip rules, P&O hand-over | Nguyen and Low [nguyen2010direct] |
| The ceiling V1 I2 | Boztepe et al. [boztepe2014rvw], Wang et al. [wang2016ssj] |
| A bound-based stop rule for DIRECT | Khong et al. [khong2013directes] |
| Best-first refinement by a bound, with a stop when no bound beats the best | Piyavskii [piyavskii1972], Shubert [shubert1972], as restated in [nesic2013shubert]. In GMPPT: Abujarad et al. [abujarad2026prism] |

### 1.3a The refined form of the DIRECT tracker with a ceiling check

The refined form keeps the stop test of section 1.3 and changes three steps:

1. It does not run the two extra cycles of DIRECT after the neighbour test. That test is part of the hand-over rule of DIRECT, which the ceiling check replaces.
2. It does not run the locally biased stage of DIRECT. The ceiling check refines the region of the best sample anyway.
3. It splits a gap at the duty where the input resistance V / I equals V1 / I2, not at the duty midpoint. There the load line passes through the corner (V1, I2) of the box that holds every point of the gap. A point with a power near the ceiling can only lie near this duty, and after the split the two new ceilings are equal. This is the projection step of the polyblock algorithm [tuy2000monotonic, zhang2012monotonic]. In the converter, one duty setting does the projection. The duty comes from a straight line through the two measured values of ln(V / I) against ln((1 - D) / D), which is exact for the ideal buck-boost and needs no converter value.

On 900 noise-free random cases the refined form uses 12.7 probes on average against 14.4, with the same certificate (`Notes/idea_B_theory_and_baselines.md`, section 4).

### 1.4 The ceiling-guided bisection

We implement a best-first bisection search of the Piyavskii-Shubert type [shubert1972], as LIPO does for GMPPT [li2019lipo]. In place of the Lipschitz bound, each gap uses the measured ceiling V(left) x I(right) of Boztepe et al. [boztepe2014rvw] and Wang et al. [wang2016ssj].

Steps:

1. Sample D = 0.30, 0.54 and 0.78.
2. Do steps 2 to 6 of section 1.3 on these samples.

Sources of the parts:

| Part | Source |
|---|---|
| Sample where the upper bound is highest, stop when the best is near the bound | Piyavskii [piyavskii1972], Shubert [shubert1972] |
| The same rule in duty space for GMPPT, both ends sampled first | Li et al. [li2019lipo] |
| Bisection that reuses the samples of the parent interval | Chiter [chiter2005sampling], BIRECT [paulavicius2018birect], HALRECT [stripinis2024halrect] |
| Samples at the ends of each interval | Diagonal methods [sergeyev2006diagonal] |
| Binary search for MPPT under partial shading | Tiong et al. [tiong2017binary] (conference paper) |
| Best-first branch and bound with a certificate stop in GMPPT | Abujarad et al. [abujarad2026prism] |
| Three seeds at the low, middle and high end of the duty range | Abujarad et al. [abujarad2026prism], Nguyen and Low [nguyen2010direct] |
| The ceiling | Boztepe et al. [boztepe2014rvw], Wang et al. [wang2016ssj] |

### 1.5 What the stop test certifies

When the search of section 1.3 or 1.4 stops, every gap wider than tol has a ceiling of at most (1 + eps) P_best. Under the conditions of section 1.2, no duty in such a gap gives more than (1 + eps) P_best. A gap narrower than tol has no guarantee. A narrow peak inside such a gap can be missed.

### 1.6 Implementation in the controller

The controller is a MATLAB function that runs once per control sample (50 us). It is called from a MATLAB Function block in the Simulink model. The search is a step function. It takes the averages of the last probe and returns the next probe duty. The state uses only fixed-size arrays (64 entries), so Simulink Coder can generate C code from it for a real-time target.

Timing:

| Item | Value | Reason |
|---|---|---|
| Search probe | 40 ms, average of the last 10 ms | A large duty jump starts a ringing of the inductor and the input capacitor at about 670 Hz. It decays with a time constant of about 6 ms, because the array adds almost no damping in its current-source region. With 20 ms and the average of the second half, a probe can be 4.4 % off its settled power. With 40 ms and the last 10 ms, the worst error is 0.21 %. |
| P&O period | 20 ms, average of the last 10 ms | Steps of 0.005 in duty settle to 0.08 %. |
| Start-up wait | 60 ms at D = 0.30 | The input capacitor charges. |

After the hand-over, the search starts again if |P - P_ref| > 0.05 P_ref, where P_ref is the power of the first P&O period. A timer restart is also available. Power-change and timer restarts are common practice [boztepe2014rvw, wang2016ssj, xu2021mmpt].

### 1.7 Methods for comparison

In the static harness, all methods use the same array model and the same P&O stage after the search:

- P&O from start-up.
- M1 to M4 of the project brief: Zaki et al. [zaki2023hybrid], Alombah et al. [alombah2025msmppt], Kouchaki et al. (conference paper), and DIRECT [nguyen2010direct].
- LIPO [li2019lipo], with the Lipschitz constant tuned on the nine test patterns (k = 44 504 W per unit duty), and with k / 2.
- DIRECT with the Lipschitz stop of Khong et al. [khong2013directes], with the same constant.
- The skip sweep of Boztepe et al. [boztepe2014rvw], with grid steps of 0.5 and 1.0 times VocP, the Voc of one bypass group (15.3 V).

- DIRECT as written in Nguyen and Low [nguyen2010direct], with the values that the paper leaves open stated (`Notes/idea_B_theory_and_baselines.md`, section 5.1).
- PSO after Ishaque et al. [ishaque2012pso], with three particles, w = 0.4, c1 = 1.2 and c2 = 1.6. These values come from a review table [magalhaes2026pso] and must be checked against the original paper.

The Simulink comparison covers P&O, DIRECT, the two trackers of sections 1.3 and 1.4, the refined form of section 1.3a, DIRECT as written in the paper, and PSO. M1 and M3 need a voltage loop, which the Simulink model does not have.

## 2. Results

The results in this section are results of this work: the implementation on the model of the 4 x 4 Emmvee E325P72 array, the comparison on 1800 random shading cases, and the Simulink results.

### 2.1 Static comparison on 1800 random cases

The static harness evaluates each method on the P-V curves of the array model, with the ideal converter map. One probe is one applied operating point. There are three random sets of 300 patterns: shading by panel, shadow edges that do not follow the panel edges, and shading of single bypass groups. Each set runs with no noise and with 0.5 % Gaussian noise on V and I.

| Method | Global peak found (98 % or more) | Worst case | Mean search probes | Max probes |
|---|---|---|---|---|
| DIRECT, simplified form of [nguyen2010direct] | 88.0 to 93.7 % | 85.9 % | 9.5 to 10.3 | 13 |
| DIRECT as written in [nguyen2010direct] | 90.0 to 97.0 % | 89.2 % | 12.1 to 13.5 | 16 |
| PSO, three particles [ishaque2012pso] | 93.3 to 98.0 % | 74.9 % | 31.0 to 32.5 | 60 |
| DIRECT with a ceiling check | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 | 23 |
| DIRECT with a ceiling check, refined form | 100 % | 98.0 % | 11.7 to 13.9 | 24 |
| Ceiling-guided bisection | 99.7 to 100 % | 97.9 % | 12.8 to 14.3 | 24 |
| LIPO, tuned k [li2019lipo] | 100 % | 98.1 % | 25.4 to 31.7 | 40 |
| LIPO, k / 2 | 99.7 to 100 % | 97.5 % | 12.6 to 16.5 | 37 |
| DIRECT with the Lipschitz stop [khong2013directes] | 100 % | 98.1 % | 30.8 to 35.5 | 39 |
| Skip sweep, 0.5 VocP [boztepe2014rvw] | 99.7 to 100 % | 97.4 % | 17.5 to 18.7 | 21 |
| Skip sweep, 1.0 VocP [boztepe2014rvw] | 94.3 to 99.3 % | 95.0 % | 10.2 to 10.5 | 11 |

Findings:

1. The simplified DIRECT misses the global peak in 6 to 12 % of the cases, and DIRECT as written in the paper in 3 to 10 %. In each miss that we checked, DIRECT had sampled the global hill, but at a point below a sample on a lower hill. Its local stage then refined the wrong hill.
2. The ceiling check removes almost all of these misses, for about 4 more probes.
3. The same ceiling does not make DIRECT faster. As a pruning rule inside DIRECT, it saves 0.1 probes on average. The early samples of DIRECT are far apart, so the ceiling of a gap is almost never below the best power. The ceiling becomes useful only as a final check.
4. With a valid Lipschitz constant, LIPO and the Lipschitz stop are as reliable but about twice as costly. With half the constant, LIPO is as reliable and as cheap as the ceiling-guided bisection on these sets, but its bound is then not valid and it gives no certificate.

### 2.2 Simulink results

The Simulink model has the averaged buck-boost converter, the input capacitor and the 50 us controller. From start-up, on nine shading patterns:

| Method | Global peak found | Final power | Search probes | Hand-over | Mean power in the first second |
|---|---|---|---|---|---|
| P&O | 6 of 9 | 34.9 to 99.8 % | 0 | 0.08 s | 33 to 58 % |
| DIRECT | 8 of 9 | 97.5 to 99.8 % | 9 to 11 | 0.42 to 0.50 s | 83 to 89 % |
| DIRECT with a ceiling check | 9 of 9 | 99.4 to 99.8 % | 11 to 17 | 0.50 to 0.74 s | 82 to 88 % |
| Ceiling-guided bisection | 9 of 9 | 99.4 to 99.8 % | 10 to 18 | 0.46 to 0.78 s | 81 to 85 % |
| DIRECT as written in the paper | 9 of 9 | 99.4 to 99.8 % | 11 to 15 | 0.50 to 0.66 s | 81 to 87 % |
| PSO, three particles | 9 of 9 | 99.4 to 99.8 % | 24 to 33 | 1.02 to 1.38 s | 76 to 83 % |
| DIRECT with a ceiling check, refined form | 9 of 9 | 99.5 to 99.8 % | 8 to 14 | 0.38 to 0.62 s | 83 to 89 % |

1. The Simulink controller applies exactly the duty sequence that the static model predicts with the converter loss included, on all 27 searches of the first three trackers, and on the 18 searches of DIRECT as written and PSO. The refined form gives the same probe counts and hand-over duties. Its corner duties follow the measured values, so they differ from the static ones by at most 1.6e-5 on seven patterns. On two patterns, two probes with equal ceilings come in the other order. The measured power of every probe is within 0.24 % of its static value.
2. The probe counts agree with the static harness within 2 probes, and the final powers within 0.3 %.
3. The mean power in the first second is 8 to 12 percentage points lower than in the static harness. The 40 ms probes and the 60 ms start-up wait explain all of this difference.
4. On the single-peak patterns, the searches also reach the peak sooner than P&O from start-up (0.42 to 0.78 s, against 0.96 to 1.24 s).

### 2.3 Changes of the shading

With the restart rule, each tracker starts one new search after each change of the shading, and none in a static run. The largest power change of P&O in a static run is 1.55 %, below the threshold of 5 %. The restart is necessary in one of the four changes tested. Without it, the two trackers stay on a lower peak at 97.5 to 97.6 %. With it, they reach 99.3 to 99.5 %. In the other three changes, the operating point lands on the hill of the new global peak, and P&O alone reaches it. There, the restart costs the energy of about 0.06 to 0.12 s at the global peak. Where the restart finds a peak 1.8 to 1.9 % higher, it repays its cost in 2.5 to 5 s.

### 2.4 Shading of single bypass groups

A real shadow does not follow the panel edges. A second Simulink model gives each of the 48 bypass groups its own irradiance. Three patterns test it: spots on single groups, a shadow edge with a soft border, and a diagonal shadow edge. Each curve has six peaks.

| Pattern | P&O | DIRECT | DIRECT with a ceiling check | Ceiling-guided bisection |
|---|---|---|---|---|
| Spots on single groups | 35.3 % | 95.5 % | 99.8 % (16 probes) | 99.7 % (16 probes) |
| Shadow edge with a soft border | 85.3 % | 91.6 % | 99.8 % (18 probes) | 99.8 % (19 probes) |
| Diagonal shadow edge | 94.2 % | 99.2 % | 99.2 % (15 probes) | 99.1 % (15 probes) |

Both trackers with the ceiling reach the global peak on all three patterns. DIRECT stops on a local peak on two of them, and P&O on all three. The 0.8 Voc method of the project brief (M1) needs a voltage loop, so it runs only in the static harness. There it reaches 92.5 to 95.7 % on these patterns.

### 2.5 Sensor noise and tolerances

1. With 0.5 % noise on the averaged V and I, each search misses the global hill in 1 of 900 cases.
2. With 1 % and 2 % noise, most misses come from the P&O stage after a correct search. The search itself misses the global hill in 0.9 to 6.6 % of the cases.
3. The ceiling test with sensor error bounds (section 1.2, condition 4, with delta equal to 3 times the noise level) does not reduce the search misses in a consistent way, and it costs 5 to 17 more probes. The likely weak point is the choice of the hand-over sample under noise. This work does not test a remedy.
4. The duty tolerance tol sets the risk of a miss. The ceiling tolerance eps sets most of the cost. eps = 0.02 and tol = 0.01 keep a margin on both.

### 2.6 Limits

- The converter model is averaged. It has no ripple and no switching losses.
- All results are from simulation. The project has no hardware results. The closest published methods have hardware results [nguyen2010direct, boztepe2014rvw, li2019lipo, abujarad2026prism].
- All panels are at 25 degC.
- The certificate holds only under the conditions of section 1.2. It does not cover a gap narrower than tol.

## 3. Short statement of the contribution

This work implements two global trackers from published parts and evaluates them on one array model, with the same converter and the same P&O stage. The first is the DIRECT tracker of Nguyen and Low with a final ceiling check. The second is a best-first bisection with the same ceiling. The evaluation shows that the measured ceiling removes almost all the misses of DIRECT as a final check, but saves almost nothing as a pruning rule. The evaluation also shows that a valid ceiling needs a probe of 40 ms in this converter, twice the P&O period, because the input filter has little damping when the array works as a current source.

## 4. Claims that the thesis must not make

From `Notes/novelty_check_ideas_B_C.md`, section 7.2:

- "First use of the V x I bound in GMPPT." Boztepe 2014 and Wang 2016 use it.
- "First branch-and-bound GMPPT." Abujarad 2026 is one, and LIPO is a Shubert-type search.
- "First binary-search GMPPT." Tiong 2017 and Kumaresan 2022 exist.
- "First stop criterion for DIRECT." Khong 2013 gives one.
- "Guaranteed GMPP" without the conditions of section 1.2 and the two tolerances.
- "Faster than DIRECT" or "faster than LIPO". The results do not support it.
- "Novel", "first" or "proposed method" for any borrowed structure.
- "A new split rule" or "a new certificate". The corner split is the projection step of the polyblock algorithm, and the certificate is that of monotonic optimization (Tuy 2000).
- "DIRECT misses R1" or "DIRECT misses 6 to 12 %" without "simplified form". DIRECT as written in the paper reaches R1.
- "Idea B is the best tracker." Say instead what it proves at its stop, and under which conditions (`Notes/idea_B_theory_and_baselines.md`, section 3).
