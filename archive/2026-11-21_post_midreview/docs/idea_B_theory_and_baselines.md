---
title: Idea B, its theory, a refined form, and two baselines
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-11-08
status: static, MATLAB and Simulink results final. PSO values not yet checked against the original paper
---

# Idea B: theory, a refined form, and two baselines

## 1. Summary

**Question.** Is Idea B (the DIRECT tracker with a ceiling check) theoretically the best tracker?

**Answer.** Not in an absolute sense. No search method is the best on every P-V curve (section 3.6). The theory supports a narrower statement. Under four physical assumptions (section 2):

1. The ceiling V1 x I2 is the lowest bound on the power between two samples that these assumptions can prove (Proposition 1).
2. At its stop, Idea B states how much power it can have missed (Proposition 2). DIRECT and PSO give no such statement. LIPO and the stop of Khong et al. give one only with a known Lipschitz constant.
3. The best-first order of the check splits only gaps whose ceiling is at least the global peak (Proposition 3).
4. A certificate costs probes. On some curves, any method that uses only these assumptions needs many probes (Proposition 4).

So Idea B is the only method in this study that needs no tuned constant or model and also proves, at its stop, a bound on what it missed. Idea C shares the same property. This kind of bound is not new in optimization: it is the bound of monotonic optimization (Tuy 2000, Matthiesen et al. 2020). We found no GMPPT paper that uses that theory. That is the claim that the thesis can make.

**Idea B refined** (`mppt.alg = 8`, section 4). Three changes to Idea B save 1.7 probes on average (12.7 against 14.4) and keep the same stop test. On the 1800 random cases it finds the global peak in 100 % of the noise-free cases and in 99.9 % of the cases with 0.5 % noise.

**Two baselines** (section 5):

- DIRECT as written in Nguyen and Low (2010), `mppt.alg = 6`. Our earlier DIRECT (`mppt.alg = 3`) is a simplified form of this paper.
- PSO after Ishaque et al. (2012), `mppt.alg = 7`. PSO is the most used global search in the GMPPT literature. The original paper was not available, so some of its values come from secondary sources.

**Static results, 1800 random cases** (ranges over the six sets, `crosscheck/results_all.md`):

| Method | Global peak found | Worst case | Mean search probes | Max probes | Mean power in the first 1 s |
|---|---|---|---|---|---|
| DIRECT, simplified (alg 3) | 88.0 to 93.7 % | 85.9 % | 9.5 to 10.3 | 13 | 95 to 96 % |
| DIRECT as in the paper (alg 6) | 90.0 to 97.0 % | 89.2 % | 12.1 to 13.5 | 16 | 94 to 96 % |
| PSO, 3 particles (alg 7) | 93.3 to 98.0 % | 74.9 % | 31.0 to 32.5 | 60 | 89 to 90 % |
| PSO, 5 particles | 95.0 to 99.0 % | 77.8 % | 56.3 to 58.8 | 100 | 85 to 87 % |
| Idea B (alg 4) | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 | 23 | 95 to 96 % |
| Idea B refined (alg 8) | 100 % | 98.0 % | 11.7 to 13.9 | 24 | 96 % |

## 2. Setting and assumptions

The tracker sets the duty D of the buck-boost converter. One probe applies one duty and measures V and I after the converter settles. The search range is D = 0.30 to 0.78.

- **A1. Monotone current.** The array current does not rise when the voltage rises. This holds for every series-parallel array with bypass diodes: each string has this property, and parallel strings add their currents.
- **A2. Monotone converter map.** A higher duty gives a lower PV voltage. For the buck-boost into a fixed resistive load, the input resistance R(D) = V / I falls as D rises.
- **A3. Steady state.** Each sample is a settled operating point. In `MPPT_4x4.slx` a search probe lasts 40 ms for this reason (`Notes/pv4x4_shading_and_po.md`, section 5.1).
- **A4. Fixed curve and exact sensors.** The irradiance and the temperature do not change during the search, and the sensors are exact. Section 3.7 gives what happens when A3 or A4 fails.

Notation. Two neighbouring samples in duty are (d1, V1, I1) and (d2, V2, I2) with d1 < d2. A2 gives V1 >= V2. A1 then gives I1 <= I2. The gap is the duty interval between them. Its ceiling is U = V1 I2. P_best is the highest sampled power.

## 3. Theory

### 3.1 The ceiling is the tightest bound from two samples

**Lemma** (Boztepe et al. 2014, Wang et al. 2016). Under A1 to A3, every duty d in the gap gives P(d) <= V1 I2.

Proof. A2 gives V2 <= V(d) <= V1. A1 and V(d) >= V2 give I(d) <= I2. Thus P(d) = V(d) I(d) <= V1 I2.

**Proposition 1.** No smaller bound follows from A1, A2 and the samples. For every small delta > 0 there is a current curve that agrees with every sample, obeys A1, and has a point in the gap with a power above V1 I2 - delta.

Proof. Take the curve I(V) = I2 for V2 <= V <= V1 - h, then a straight fall to I1 at V1. It does not rise with V. Samples at lower voltages have currents of I2 or more, and samples at higher voltages have currents of I1 or less, so the curve agrees with all of them. The converter map is continuous, so some duty in the gap puts the operating point at V = V1 - h. There, P = (V1 - h) I2. Let h go to 0.

The two neighbours give the tightest bound. A sample further away gives a voltage limit that is higher, or a current limit that is higher, so its bound is weaker. Proposition 1 means that the stop test of Idea B is the strongest stop test that A1 and A2 allow. A real array cannot follow the extreme curve exactly. A bypass diode that turns on gives a steep fall of current, which comes close to it.

### 3.2 What the stop test certifies

**Proposition 2.** When the check of Idea B stops, the highest power P* in the search range obeys

P* <= max( (1 + eps) P_best, U of each gap that is not wider than tol ).

Proof. The stop test leaves no gap wider than tol with U > (1 + eps) P_best. The lemma bounds each gap by its ceiling. Every point of the range is a sample or lies in a gap.

The bound is known at the stop, because every ceiling is a product of two measurements. The tracker can report it. The narrow gaps are the weak part. A gap that is narrower than tol can have a ceiling above (1 + eps) P_best, and the theory does not exclude a hill inside it. The two gaps next to the best sample are always among these, because near a smooth peak the ceiling falls only in proportion to the gap width. The P&O stage then climbs that hill.

As a measure, `crosscheck/run_ideab_refined.py` computes Cert = max U / P_best over the gaps that do not touch the best sample. On the 900 noise-free random cases, Idea B ends with Cert = 1.016 on average and 1.034 at most. So the search proves that no point outside the hill of the best sample has more than 1.034 P_best.

The same measure on the samples of DIRECT as in the paper gives Cert = 1.082 on average and 1.369 at most. So at the hand-over of DIRECT, the samples cannot exclude a point with 37 % more power than the best sample. DIRECT hands over anyway, and that is where its misses come from.

### 3.3 The best-first order

The check always splits the open gap with the highest ceiling. With a fixed split rule, the gaps form a tree that does not depend on the order of the splits. The midpoint rule and the corner rule (section 3.5) both use only the two ends of a gap, so both give a fixed tree.

**Proposition 3.**

1. Every method that ends with the certificate of Proposition 2 must split each gap wider than tol whose ceiling is above (1 + eps) P*.
2. The best-first order never splits a gap whose ceiling is below P*.

Proof. (1) P_best <= P* at all times. Such a gap never passes the stop test unless it is split. (2) If P* is at a sample, then P_best = P*, and the stop test closes every gap with U <= (1 + eps) P*. Otherwise P* is inside an open gap g*, and U(g*) >= P* by the lemma. The best-first order takes the open gap with the highest ceiling, so the gap that it splits has U >= U(g*) >= P*.

So the best-first order can only waste splits on gaps with a ceiling between P* and (1 + eps) P*. With eps = 0 and a fixed tie rule, it splits no gap that another method with the same tree could avoid. This is the classic result for best-bound-first branch and bound: Ibaraki (1976) shows that this order is optimal for the number of nodes that it expands, not for the memory that it uses. With a tolerance (eps > 0) the result holds only up to the band [P*, (1 + eps) P*], as stated above. Idea B starts the check from the DIRECT samples, not from the root of a tree. DIRECT gives a high P_best early, which closes many gaps at once.

### 3.4 A certificate costs probes

**Proposition 4.** Take a curve with constant power on the search range, I(V) = P0 / V. It obeys A1. Every gap then has U / P_best = V1 / V2. The stop test with tol = 0 needs V1 / V2 <= 1 + eps in every gap, so it needs at least ln(Vmax / Vmin) / ln(1 + eps) gaps.

On our range, Vmax / Vmin is about 6.7 (D = 0.30 is near Voc, D = 0.78 near 0.15 Voc). With eps = 0.02 this gives about 96 gaps. Proposition 1 shows that no method that uses only A1 and A2 can do better on this curve. Real P-V curves are much cheaper: on the current-source side of a hill, I is almost constant, so the ceilings stay low. On the 1800 random cases Idea B needs 23 probes at most.

The tolerance tol bounds the cost. With midpoint splits, every final gap is wider than tol / 2, so the check takes at most 2 x 0.48 / 0.01 = 96 gaps. With the corner split, a child is at least theta = 0.1 of its parent, so the bound is weaker: 0.48 / (0.1 x 0.01) = 480 gaps. In the controller, the arrays hold 64 samples, and the search ends at the best sample when they are full. No case of this study came near that limit.

### 3.5 Where a hidden peak can be: the corner duty

Every point of the gap lies in the box V2 <= V <= V1, I1 <= I <= I2. The ceiling V1 I2 is the power at the corner (V1, I2) of this box. The load line I = V / R passes through this corner when R = R* = V1 / I2. Because R1 = V1 / I1 >= R* >= V2 / I2 = R2, some duty d* in the gap has R(d*) = R*. We call d* the corner duty of the gap.

**Proposition 5.**

1. If a point in the gap has P >= (1 - eta) V1 I2, then its resistance is between (1 - eta) R* and R* / (1 - eta). So a point with a power near the ceiling can only be near the corner duty.
2. After a sample (V*, I*) at the corner duty, the two new ceilings are equal: V1 I* = V* I2.

Proof. (1) V <= V1 and I <= I2, so V I >= (1 - eta) V1 I2 needs V >= (1 - eta) V1 and I >= (1 - eta) I2. Then R = V / I is at most V1 / ((1 - eta) I2) and at least (1 - eta) V1 / I2. (2) At d*, I* = V* / R* = V* I2 / V1, so V1 I* = V* I2.

Part 1 says that the corner duty is the best single place to look for a peak that could beat the ceiling test. Part 2 says that the split at d* leaves no side of the gap with a higher ceiling than the other. The midpoint rule has neither property.

**This split is not new.** The region under the I-V curve is a normal (downward closed) set, and P = V I increases in V and in I. So the GMPP is a monotonic optimization problem (Tuy 2000). The polyblock algorithm of that theory keeps vertices such as (V1, I2), takes the vertex with the highest value, and projects it onto the boundary along the ray from the origin (Zhang et al. 2012, section 3.2, Prop. 3.3 and Eq. 3.3). The ray through (V1, I2) is the load line R = V1 / I2. So a probe at the corner duty is that projection, and the two new ceilings are the two new vertices. The generic algorithm finds the projection by a bisection on the ray. In the converter, one duty setting does it. That is the only difference, and it is a detail of the application.

**How the controller finds d*.** The ideal buck-boost has ln R = ln R_load + 2 x, with x = ln((1 - D) / D). Both ends of the gap give a measured pair (x, ln R). A straight line through them gives the x where ln R = ln R*, and so d*. This needs no converter value, not even R_load. On another converter the line is only an estimate. The probe then lands near d*, not on it, and the ceilings stay valid, because the lemma holds for any point in the gap. A clamp keeps d* at least 0.1 of the gap width from each end, so every split makes progress.

Part 2 makes ties common: the two children of a split have equal ceilings. The code breaks a tie (ceilings within a relative 1e-9) in favour of the gap with the higher duty, in Python and in MATLAB alike.

### 3.6 What each method guarantees

| Method | Needs | Statement at the stop |
|---|---|---|
| DIRECT, Jones et al. (1993) | No constant | Finds the global peak only in the limit, as the samples become dense (Jones and Martins 2021, section 2). In practice it stops on a budget. A meaningful stop rule is hard to give (Sergeyev and Kvasov 2006). |
| DIRECT for GMPPT, Nguyen and Low (2010) | Shading thresholds, Voc and Isc for the skip rules | None. The switch to the local stage when the two best samples are neighbours is a heuristic. |
| PSO, Ishaque et al. (2012) | w, c1, c2, the number of particles, a stop value | None. The original PSO is not even sure to converge to a local optimum (van den Bergh and Engelbrecht 2010). |
| LIPO, Li et al. (2019), DIRECT with the stop of Khong et al. (2013) | A Lipschitz constant k of P(D) | A bound, but only if k is at least the true slope. Our study (section 11 of `Notes/gmppt_m1_m4_comparative_study.md`) shows that half of the tuned k gives no valid bound. |
| Skip scan, Boztepe et al. (2014) | Voc of one bypass group, for the grid | Skips are safe, but the grid step limits what the scan can see. |
| Ideas B and C, and Idea B refined | eps and tol only | Proposition 2, from measurements only. The same kind of certificate is standard in monotonic optimization (Tuy 2000, Matthiesen et al. 2020). |

No-free-lunch theorem (Wolpert and Macready 1997): averaged uniformly over all objective functions, no search method beats another. The theorem holds only for classes of functions that are closed under permutation (Igel and Toussaint 2004). The P-V curves under A1 are not such a class, so a method that uses the monotone current can do better on them. A claim that one tracker is "the best" still needs a class of curves and a measure. Our class is A1 to A4, and our measure is the certificate at the stop.

### 3.7 When the theory fails

- **Unsettled samples (A3).** A probe that has not settled can show a current or a voltage that does not belong to the static curve. With 20 ms probes the error reached 4.4 % in our model. Hence the 40 ms probe.
- **A change of the shading during the search (A4).** The samples then belong to two different curves, and the ceilings mean nothing. The restart rule of the controller (`mppt.dP_restart`) starts a new search after the change. It cannot repair the search that was running.
- **Sensor error (A4).** With a relative error of at most delta on V and on I, the robust test compares V1 (1 + delta) I2 (1 + delta) with P_best (1 - 2 delta). Task T8 found no consistent gain from it at the noise levels tested (`Notes/gmppt_m1_m4_comparative_study.md`, section 12).
- **The converter map (A2).** The map must stay monotone during the search. A change of the load during the search breaks A2 in the same way as a change of the shading breaks A4.

## 4. Idea B refined

### 4.1 Steps

`mppt.alg = 8`, `direct_certified_plus` in `crosscheck/algos.py`.

1. Run the DIRECT of `mppt.alg = 3` up to the end of its globally biased stage: the first three samples, the shading test and, if it holds, the three global cycles with the skip rules.
2. Do not run the two extra cycles after the neighbour test. That test belongs to the hand-over rule of DIRECT, which the check replaces.
3. Do not run the locally biased stage of DIRECT. The check refines the region of the best sample anyway.
4. Run the ceiling check of Idea B (eps = 0.02, tol = 0.01) on all samples. Split the gap with the highest ceiling at its corner duty (section 3.5), not at its midpoint.
5. Hand over to P&O at the best sample.

The stop test, and so the certificate of Proposition 2, is the same as for Idea B.

### 4.2 What each change gives

From `crosscheck/results_ideab_refined.md`, 900 noise-free random cases (panel, edge and group shading). Cert is max U / P_best over the gaps that do not touch the best sample (section 3.2).

| Variant | Global peak found | Mean probes | Max probes | Cert mean | Cert max |
|---|---|---|---|---|---|
| Idea B | 100 % | 14.38 | 23 | 1.016 | 1.034 |
| B, no extra cycles | 100 % | 14.24 | 23 | 1.016 | 1.034 |
| B, no local stage | 100 % | 13.76 | 24 | 1.017 | 1.042 |
| B, corner split | 100 % | 13.80 | 23 | 1.016 | 1.035 |
| B, no extra cycles and no local stage | 100 % | 13.69 | 24 | 1.017 | 1.042 |
| Idea B refined (all three) | 100 % | 12.70 | 24 | 1.015 | 1.040 |

1. Each change alone saves 0.1 to 0.6 probes. Together they save 1.7. The corner split works better when the check starts from the coarse DIRECT samples, because then more gaps are wide.
2. The mean certificate is the same. The largest Cert rises from 1.034 to 1.040. Both are within the eps = 0.02 test for every gap wider than tol, so the difference comes from the narrow gaps.
3. With 0.5 % noise, Idea B refined finds the global peak in 99.9 % of the 900 cases (Idea B: 99.4 %) with 12.4 probes on average.

### 4.3 Equal certificate

A larger eps also saves probes, but it weakens the certificate. The table compares the two forms at the same eps, so the certificates are equal.

| eps | Idea B, probes | Idea B refined, probes | Cert mean, both |
|---|---|---|---|
| 0.02 | 14.38 | 12.70 | 1.015 to 1.016 |
| 0.03 | 13.50 | 11.62 | 1.021 |
| 0.04 | 12.57 | 10.50 | 1.026 |
| 0.05 | 11.95 | 9.70 | 1.030 |
| 0.06 | 11.59 | 9.11 | 1.034 to 1.035 |

The saving grows with eps, from 1.7 to 2.5 probes.

### 4.4 Changes that we tested and rejected

- **The window test.** A gap can only hide a point above (1 + eps) P_best at resistances between (1 + eps) P_best / I2^2 and V1^2 / ((1 + eps) P_best). A test of tol against the duty width of this window, in place of the full gap, saves about 4 probes at eps = 0.02. But the window shrinks to below tol while the ceiling is still up to about 6 % above P_best. So most of the saving comes from a weaker certificate. At an equal certificate (eps = 0 for the window, eps = 0.04 for Idea B refined, Cert 1.027 and 1.026), it saves only 0.24 probes. We keep the simpler test.
- **Another clamp of the corner split.** In a scratch test (with the extra cycles still in), theta = 0.05, 0.10 and 0.25 gave the same mean probes within 0.02.
- **The corner split for Idea C.** It works there too: 12.62 probes against 13.78, with the same certificate. The thesis can mention this as a result for Idea C. The controller does not have it.

### 4.5 Sources and what is new

| Part | Source |
|---|---|
| DIRECT for GMPPT, the global stage and the skip rules | Nguyen and Low (2010), in the simplified form of `mppt.alg = 3` |
| The ceiling V1 I2 | Boztepe et al. (2014), Wang et al. (2016) |
| Best-first split by a bound, stop when no bound beats the best | Piyavskii (1972), Shubert (1972), Khong et al. (2013) |
| Removal of the local stage and of the extra cycles | Our change. It follows from Proposition 2 |
| The split at the corner duty | The projection step of the polyblock algorithm (Tuy 2000, Zhang et al. 2012). We found it independently, then found the source. We found no GMPPT paper that uses it |

What the thesis can call the work of this project:

- the use of the polyblock projection in a duty-controlled GMPPT, where one duty setting does the projection,
- the removal of the DIRECT stages that the certificate makes redundant,
- the measured results.

It must not call the split rule new.

## 5. The two baselines

### 5.1 DIRECT as written in Nguyen and Low (2010)

`mppt.alg = 6`, `direct_paper` in `crosscheck/algos.py`. Two independent readings of the paper (2026-11-07 and 2026-11-08) agree on these steps. The page numbers are of the journal.

| Step | The paper | `mppt.alg = 3` (simplified) | `mppt.alg = 6` |
|---|---|---|---|
| Shading test, only one of (19), (20) holds | Take more samples and test again (p. 3459, Fig. 5(a)) | Uniform | Divide the best third, then test again with the new sample between the pair that the failed test did not cover |
| Skip rules 1 and 2 | Skip only the outer child of s3 or s2 (p. 3461) | Whole third dead | Outer child only |
| Skip rules 3 and 4 | Do not divide s3 or s2 after a failed (19) or (20) | Absent | As the paper. The skip uses up the iteration, so the stage takes fewer samples (p. 3461) |
| Local stop, Eq. (21) | New spacing at most dcr | Stops one trisection earlier | As the paper |

Values that the paper does not give, and our choice:

| Item | Our choice |
|---|---|
| Duty range. The paper gets (0.45, 0.85) from Eqs. (13) to (18) with alpha, beta and eta that it does not give | The common range 0.30 to 0.78 of this study |
| dcr. The paper asks for a value below the P&O step | 0.0025. Any value in [0.0020, 0.0059) gives the same probes |
| The re-test after one failed condition. The paper describes only the case where (19) fails | The same rule for both cases |
| Ties | The lowest duty wins |
| Voc and Isc of the skip rules | Array values at STC |
| Skip rules 1 and 2 at the re-test division of step 2 | Applied (it matters in 3 of 900 random cases) |
| Restart | The common restart of all methods |

One departure that we chose: after the search, the paper runs P&O with the step dcr (p. 3462, Fig. 8). We use the common P&O of all methods, with the step 0.005, so that only the search differs. The paper also asks for dcr below the P&O step, so its text is not consistent on this point.

Two effects of the common range:

- s2 sits at D = 0.38, near Voc, where I < Isc / 3. So skip rule 2 holds on every curve, and the high-voltage child of s2 is never sampled.
- Test (20) fails alone in 421 of the 900 random cases. That is the case that the paper covers only with a short remark that a similar process applies. So the reading of that remark matters.

**Sensitivity to the reading.** `crosscheck/run_ideab_refined.py`, section 4, runs a second reading: the re-test always uses the triple (D2, best new sample, D3).

| Reading | Found, no noise | Worst | Mean probes | Found, 0.5 % noise |
|---|---|---|---|---|
| Pair of the test that held (default, alg 6) | 93.6 % | 89.2 % | 12.8 | 93.0 % |
| (D2, best new sample, D3) | 94.6 % | 92.7 % | 13.4 | 93.9 % |

The second reading finds the peak about 1 point more often and costs 0.6 more probes. Under both readings DIRECT misses 5 to 7 % of these cases. The thesis should give both lines.

An earlier scratch reading used the paper's own range 0.45 to 0.85. There it found the global peak in 95.3 to 98.7 % of the cases, with a worst case of 75.0 %. That range does not reach the low-voltage hills of our array.

### 5.2 PSO after Ishaque et al. (2012)

`mppt.alg = 7`, `pso` in `crosscheck/algos.py`.

**Why PSO.** PSO is the global search that GMPPT papers use most often as a reference. The IEEE TIE papers in our literature folder (Boztepe 2014, Kermadi 2019, Kermadi 2021) compare with PSO-based MPPT. Ishaque, Salam, Amjad and Mekhilef (2012, IEEE TPEL 27(8), pp. 3627-3638) is the most cited PSO tracker with the duty as the particle position. It also uses a buck-boost converter.

**Source status.** We could not get the full text. IEEE Xplore needs a sign-in, and the copies on other sites were blocked. The values below come from a review table (Magalhaes et al. 2026, Sustainability 18(11), 5442, Table 4) and from restatements. **The user must check them against the original paper.**

| Item | Value | Source |
|---|---|---|
| Particles | 3 | Review table |
| Inertia weight w | 0.4 | Review table |
| c1, c2 | 1.2, 1.6 | Review table. One snippet of another table shows c2 = 2 |
| Update | v = w v + c1 r1 (pbest - x) + c2 r2 (gbest - x), x = x + v | Standard PSO, restated by Koad et al. (2017, IEEE TSTE) |
| Start points | Fixed, not random | Review table ("selective") |
| Restart | Relative power change of 1.5 % | Snippet only. We use the common restart of all methods |

Our choices for the values that we could not find:

- Start points at both ends and the middle of the range, zero velocity.
- Stop when every |v| < 0.01 (two P&O steps), or after 20 iterations.
- One probe for each particle, then the personal bests, then the global best (synchronous update).
- r1 and r2 from a 32-bit linear congruential generator, the same in Python and MATLAB. In the static study the seed is fixed by the curve, so each run repeats.
- After the search, the common P&O, not a fixed duty as in the paper, so that only the search differs between the methods.

**These choices favour PSO.** A sweep over the start points and the stop value (`crosscheck/results_ideab_refined.md`, section 3) chose the best of the values tested. The centres of three equal parts gave a worst case of 74.3 % against 75.4 % for the ends. A stop value of 0.005 cost 6 more probes with the same success. Three different seed sets give 93.7 to 95.6 % success, so the seed changes the success rate by about 2 points.

**Why PSO misses.** With three particles, the swarm often agrees on a lower hill before a particle has landed on the global hill. Five particles raise the success to 95 to 99 % but double the probes.

**Seeds.** The static study fixes the seed by the curve. The controller and the Simulink runs use seed 1. With seed 1 on the 900 static cases, PSO finds the peak in 96.0 % of the cases with a worst case of 85.7 %. So the PSO numbers of the two harnesses come from different random draws.

**Controller limit.** The controller arrays hold 64 samples. The default PSO (3 particles, at most 20 iterations, 60 probes) fits. Five particles with 20 iterations need 100 probes, so the 5-particle row exists in the static study only. In the controller, the search ends at the best sample when the arrays are full.

## 6. Results

### 6.1 Nine project patterns, static (search probes / final % of the GMPP)

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| DIRECT, simplified | 9 / 99.7 | 11 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 |
| DIRECT as in the paper | 11 / 99.8 | 14 / 99.7 | 11 / 99.8 | 15 / 99.8 | 15 / 99.4 | 13 / 99.8 | 13 / 99.8 | 11 / 99.8 | 11 / 99.8 |
| Idea B | 11 / 99.7 | 12 / 99.7 | 11 / 99.8 | 17 / 99.8 | 16 / 99.5 | 12 / 99.8 | 13 / 99.8 | 12 / 99.8 | 12 / 99.7 |
| PSO, 3 particles | 33 / 99.8 | 36 / 99.7 | 30 / 99.8 | 39 / 99.8 | 30 / 99.5 | 27 / 99.8 | 36 / 99.8 | 42 / 99.8 | 30 / 99.8 |
| Idea B refined | 8 / 99.7 | 10 / 99.8 | 8 / 99.8 | 14 / 99.8 | 11 / 99.4 | 10 / 99.8 | 13 / 99.8 | 8 / 99.8 | 9 / 99.8 |

The PSO row uses a seed that depends on the curve (`crosscheck/run_all.py`). The Simulink runs use seed 1, which gives other probe counts (24 to 33).

DIRECT as in the paper reaches the global peak of R1. So "DIRECT misses R1" holds for the simplified form only.

### 6.2 MATLAB port

`gmppt_static_check.m` runs `gmppt_search.m` on the Simulink sweep curves and compares each probe duty with `algos.py`. All 54 runs (6 methods, 9 patterns) give the same duties (largest difference 4.4e-16). Algorithms 3, 4 and 5 give the same results as before the change.

An independent review transcribed the MATLAB code to Python and compared it with `algos.py` on 903 array curves and 3001 synthetic curves. These reach every path: one failed shading test of each kind, skip rules 1 to 4, ties and noise. The duties were the same on all of them. The review found one latent error, which is now fixed: with more than 3 PSO particles, the controller could write past its 64-sample arrays.

Code generation: `coder.screener` reports no message and no unsupported call for `mppt_controller.m`, `gmppt_search.m` and `gmppt_init.m` (2026-11-08).

### 6.3 Simulink

`run_gmppt_compare.m`, 72 runs, about 39 min. The cases are those of `run_gmppt_demo.m`. Each search probe lasts 40 ms. P&O, DIRECT (alg 3) and Idea B give the same results as `results/gmppt_results.mat` (largest difference 1.3e-6).

Set A, from start-up, nine patterns:

| Method | Global peak found | Final power | Search probes | Hand-over | Mean power in the first second |
|---|---|---|---|---|---|
| P&O | 6 of 9 | 34.9 to 99.8 % | 0 | 0.08 s | 33 to 58 % |
| DIRECT, simplified (alg 3) | 8 of 9 | 97.5 to 99.8 % | 9 to 11 | 0.42 to 0.50 s | 83 to 89 % |
| DIRECT as in the paper (alg 6) | 9 of 9 | 99.4 to 99.8 % | 11 to 15 | 0.50 to 0.66 s | 81 to 87 % |
| PSO, 3 particles, seed 1 (alg 7) | 9 of 9 | 99.4 to 99.8 % | 24 to 33 | 1.02 to 1.38 s | 76 to 83 % |
| Idea B (alg 4) | 9 of 9 | 99.4 to 99.8 % | 11 to 17 | 0.50 to 0.74 s | 82 to 88 % |
| Idea B refined (alg 8) | 9 of 9 | 99.5 to 99.8 % | 8 to 14 | 0.38 to 0.62 s | 83 to 89 % |

Set C, winter morning (R1, then P1 at 1.2 s, then P0 at 2.4 s). Power in the last 0.3 s of each phase, % of the GMPP of that phase:

| Method | R1 | P1 | P0 |
|---|---|---|---|
| DIRECT, simplified | 97.5 % | 99.7 % | 99.7 % |
| DIRECT as in the paper | 99.5 % | 99.8 % | 99.8 % |
| PSO | 95.4 % | 98.6 % | 99.0 % |
| Idea B | 99.5 % | 99.7 % | 99.8 % |
| Idea B refined | 99.4 % | 99.8 % | 99.8 % |

Findings:

1. In Simulink, every global search except the simplified DIRECT reaches the global peak of all nine patterns. These nine patterns do not show the misses of DIRECT as in the paper and of PSO. The 1800 static cases show them (section 1).
2. Idea B refined hands over first on every pattern (0.38 to 0.62 s) and has the highest power in the first second of the four searches that reach every peak.
3. PSO needs 24 to 33 probes, so its search takes 1.0 to 1.4 s. In set C, a search after each change takes about 1 s of each 1.2 s phase. The last 0.3 s of a phase then still holds search probes, so its power and its voltage swing (up to 40 V) look worse than the tracking itself.
4. On R1, the time t98 of Idea B refined is 2.46 s, although its search ends at 0.54 s and no restart happens. The P&O ripple on this flat peak dips to 97.7 % of the final power, just below the 98 % line of t98. The other trackers dip to 98.2 % at least. This is a property of the metric and of the P&O, not of the search.

`check_gmppt_controller.m` compares the duty of every probe in Simulink with the static plant that has the converter loss (the RL map):

- Algorithms 3 to 7 apply the same duty sequence as the static plant on all 45 runs.
- Idea B refined gives the same probe count and the same hand-over duty (within 1e-5) on all nine patterns. Its duties differ from the static plant from the first corner split on, because the corner duty is a function of the measured V and I, and Simulink measures them with an error of up to 0.24 %. A midpoint or a trisection does not depend on the measurements, so the other methods repeat the static duties exactly.
  - On seven patterns, the largest duty difference is 1.6e-5.
  - On R2 and R4 it is 0.027 and 0.017. There, two probes come in the other order. A corner split gives two gaps with equal ceilings (Proposition 5), and the measurement error breaks this tie the other way. The same probes follow, so the count and the hand-over do not change.
- The measured power of every probe is within 0.243 % of its static value.

Solver warnings. Some runs print a solver warning ("unable to reduce the step size") near t = 0.145 s, at the large duty jump of the third probe. A check of all six searches on the nine patterns found it on one pattern for each method (R4 for algorithms 3, 4, 6 and 8, R1 for 5 and 7). Algorithms 3 and 4 give the same results as on 2026-10-23, so the warning was there before these changes. It comes from the model, not from the new code, and the probe errors above include its effect.

## 7. Files and how to run

| File | Content |
|---|---|
| `crosscheck/algos.py` | `direct_paper`, `pso`, `lcg`, `corner_duty`, `direct_certified_plus`. New options `local` and `extra` of `direct`, and `split` of `_bound_refine`. The defaults keep the old behaviour |
| `crosscheck/run_all.py` | Four new rows. `python run_all.py` (about 2 min) |
| `crosscheck/run_ideab_refined.py` | Ablation, certificate, equal-certificate sweep, PSO settings. Writes `results_ideab_refined.md` and `.json` (about 1 min) |
| `crosscheck/run_simulink_curves.py` | Three new methods in `simulink_curves_runs.json` |
| `gmppt_search.m`, `gmppt_init.m` | `mppt.alg = 6, 7, 8` |
| `pv4x4_config.m` | `theta_c`, `dcr6`, `pso_n`, `pso_w`, `pso_c1`, `pso_c2`, `pso_vstop`, `pso_itmax`, `pso_seed` |
| `gmppt_static_check.m`, `check_gmppt_controller.m` | Now cover algorithms 3 to 8 |
| `run_gmppt_compare.m` | Simulink runs of algorithms 1, 3, 4, 6, 7 and 8. Writes `results/gmppt_compare.*` and `fig_compare_*.png` |

## 8. References and novelty check

### 8.1 Novelty check of the refinement (2026-11-08)

A search of the GMPPT literature and of global optimization found:

- **The corner split is the projection step of the polyblock algorithm** of monotonic optimization (section 3.5). Read: Zhang, Qian and Huang (2012). Not read in full: Tuy (2000), Rubinov, Tuy and Mays (2001).
- **Idea C with the midpoint split is, in one dimension, the mixed monotonic programming algorithm** of Matthiesen et al. (2020). Its bound F(s, r) over a box, increasing in one argument and decreasing in the other, is the ceiling V1 I2. That paper bisects boxes at the midpoint, with a best-first choice and a relative tolerance.
- **No GMPPT paper that we found uses this theory, or a split at the corner of the I-V box.** Read in full: Boztepe et al. (2014), Wang et al. (2016), Li et al. (2018). Li et al. (2018) compute the buck-boost duty from a target load line, but their target is a power step, not the box corner, and they use no bound. Searched by text: Abujarad 2026, Li 2019, Furtado 2018, Kermadi 2019 and 2021, Sun 2023, Xu 2021, Tiong 2017. A full-text search of IEEE Xplore was not possible.

`Notes/novelty_check_ideas_B_C.md`, section 11, records the effect on the claims for Ideas B and C.

### 8.2 References for the theory

| Key | Reference | Status |
|---|---|---|
| tuy2000monotonic | H. Tuy, "Monotonic optimization: Problems and solution approaches", SIAM J. Optim. 11(2):464-494, 2000, doi 10.1137/S1052623499359828 | Not read in full |
| rubinov2001monotonic | A. Rubinov, H. Tuy, H. Mays, "An algorithm for monotonic global optimization problems", Optimization 49(3):205-221, 2001, doi 10.1080/02331930108844530 | Not read in full |
| zhang2012monotonic | Y. J. Zhang, L. Qian, J. Huang, "Monotonic optimization in communication and networking systems", Foundations and Trends in Networking 7(1):1-75, 2012, doi 10.1561/1300000038 | Read, section 3.2 |
| matthiesen2020mmp | B. Matthiesen, C. Hellings, E. A. Jorswieck, W. Utschick, "Mixed monotonic programming for fast global optimization", IEEE Trans. Signal Process. 68:2529-2544, 2020, doi 10.1109/TSP.2020.2983284 | Read (arXiv 1910.07853) |
| ibaraki1976 | T. Ibaraki, "Theoretical comparisons of search strategies in branch-and-bound algorithms", Int. J. Comput. Inf. Sci. 5(4):315-344, 1976, doi 10.1007/BF00998631 | Abstract only. Ibaraki, J. Oper. Res. Soc. Japan 25(3):292-320, 1982, read, confirms the framework |
| wolpert1997nfl | D. H. Wolpert, W. G. Macready, "No free lunch theorems for optimization", IEEE Trans. Evol. Comput. 1(1):67-82, 1997 | Citation checked. Check the doi |
| igel2004nfl | C. Igel, M. Toussaint, "A no-free-lunch theorem for non-uniform distributions of target functions", J. Math. Model. Algorithms 3(4):313-322, 2004, doi 10.1023/B:JMMA.0000049381.24625.f7 | Not read in full |
| jones2021direct25 | D. R. Jones, J. R. R. A. Martins, "The DIRECT algorithm: 25 years later", J. Glob. Optim. 79(3):521-566, 2021, doi 10.1007/s10898-020-00952-6 | Read, sections 2.1 and 2.2 |
| sergeyev2006diagonal | Y. D. Sergeyev, D. E. Kvasov, SIAM J. Optim. 16(3):910-937, 2006 | In the literature folder |
| vandenbergh2010pso | F. van den Bergh, A. P. Engelbrecht, "A convergence proof for the particle swarm optimiser", Fundamenta Informaticae 105(4):341-374, 2010 | Abstract read. Check the doi |
| ishaque2012pso | K. Ishaque, Z. Salam, M. Amjad, S. Mekhilef, "An improved particle swarm optimization (PSO)-based MPPT for PV with reduced steady-state oscillation", IEEE Trans. Power Electron. 27(8):3627-3638, 2012, doi 10.1109/TPEL.2012.2185713 | Not read. Values from magalhaes2026pso |
| magalhaes2026pso | Magalhaes, Pombo, Mendes, Calado, Mariano, Louro, "A review of PSO control parameters for MPPT under different conditions", Sustainability 18(11):5442, 2026, doi 10.3390/su18115442 | Read |
| li2018loadline | Li, Wen, Chu, Hu, Jiang, Solar Energy 169:353-361, 2018, doi 10.1016/j.solener.2018.04.055 | Read (accepted manuscript) |

We do not claim that the Piyavskii-Shubert choice is optimal in one step. We found no readable source for that statement (Sukharev 1971, 1972 are candidates).

## 9. Open items for the user

1. Get Ishaque et al. (2012, IEEE TPEL 27(8)) through the institute access and check the values of section 5.2.
2. Decide the name of Idea B refined in the thesis.
3. Decide whether the thesis keeps the simplified DIRECT (alg 3) as a result, or reports only the form that follows the paper.
