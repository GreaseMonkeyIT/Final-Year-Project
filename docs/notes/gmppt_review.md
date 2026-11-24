---
title: Review record of the global searches, the local stage and the restart rule
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-11-21
status: first version, then integrated on 2026-11-21 (section 10)
---

# Review record

## 1. How the review was done

- Each file in `fable_controller/controller/` was written from the source papers on the disk and from the task definition. No code was copied from `archive/`.
- The task definition said that no code must run. On 2026-11-21 the user permitted checks in a scratch copy outside the project: no tuning, no change of a model or of a project file. Section 9 lists what was run. All other sections are a review by reading.
- Three research agents collected the secondary sources of section 4. Their reports say which documents they opened. Items that they could not open are marked UNVERIFIED.
- Line numbers refer to the files of 2026-11-21.

Short names of the sources:

| Name | Source |
|---|---|
| NL10 | Nguyen and Low, IEEE Trans. Ind. Electron. 57(10), pp. 3456-3467, 2010 |
| I12 | Ishaque, Salam, Amjad and Mekhilef, IEEE Trans. Power Electron. 27(8), pp. 3627-3638, 2012 |
| M16 | Mohanty, Subudhi and Ray, IEEE Trans. Sustain. Energy 7(1), pp. 181-188, 2016 |
| G14 | Mirjalili, Mirjalili and Lewis, Adv. Eng. Softw. 69, pp. 46-61, 2014, and the GWO.m code of its first author |
| L08 | Liu, Duan, Liu, Liu and Kang, IEEE Trans. Ind. Electron. 55(7), pp. 2622-2628, 2008 |
| TASK | The task definition of 2026-11-21 (sections 4.3 to 4.5 define the ceiling check and Ideas B and C) |

## 2. Trace tables: source against code

### 2.1 DIRECT (`gmppt_direct.m`)

| Source item | Where in the source | Code |
|---|---|---|
| Division into three, two new samples at the outer centers | NL10 section III-A, Fig. 1(a), p. 3458 | `divide`, lines 240-257. New length h = L0 / 3^lev, line 244 |
| Potentially optimal interval, Eq. (11) | NL10 p. 3458 | `isPoi`, lines 290-320: same length, line 304. Shorter intervals, line 312. Longer intervals, line 314 |
| Eq. (12), eps = 0.03 in the global stage | NL10 p. 3458 | `isPoi`, line 297. Value `p.dir_eps_g` |
| eps = 0 in the local stage | NL10 p. 3458 | Not read by the code. The local stage divides the best interval (line 223) |
| Absolute sampling interval, Eqs. (13) to (18) | NL10 pp. 3458-3459 | `pv4x4_config.m`, fields `dir_Dlo_abs` and `dir_Dhi_abs`. Selected in lines 75-81 |
| Three first samples at the centers of the three thirds | NL10 section IV-B, Fig. 3 | Lines 84-86 |
| Eq. (19), limit 0.1 | NL10 p. 3459 | Line 106 |
| Eq. (20), limit 0.2 | NL10 p. 3459 | Line 107 |
| Both true: partial shading, global stage | NL10 p. 3459 | Lines 108-109 |
| Three samples on one stair: uniform, local stage | NL10 p. 3460, Fig. 5(b) | Lines 110-111 |
| Only one true: divide the best interval, take two samples, identify again | NL10 p. 3459, Fig. 5(a) | Lines 112-129 (division) and 134-159 (second test, lines 152-153) |
| Global stage divides the potentially optimal interval with the largest length | NL10 section IV-C, pp. 3460-3461, Fig. 6 | `largestPoi`, lines 273-288. Called in lines 174 and 208 |
| Skip rule 1: V_D3 < Voc / 3, D3,3 not taken | NL10 p. 3461 | Line 178 |
| Skip rule 2: I_D2 < Isc / 3 or V_D2 > 0.9 Voc, D2,2 not taken | NL10 p. 3461 | Lines 180-181 |
| Skip rules 3 and 4: (19) or (20) false, the third is not divided | NL10 p. 3461 | `isBlocked`, lines 267-271. Used in lines 165 and 278 |
| Nine intervals of length 1/9 after the fourth iteration | NL10 p. 3461 | Stage 3 ends when no third of level 1 is open, lines 163-168 |
| Two best samples are consecutive: local stage | NL10 p. 3461 | `twoBestAreNeighbours`, lines 322-343. Line 188 |
| If not: two more global cycles | NL10 p. 3461 | Stage 4, lines 202-215 |
| Local stage: the interval with the highest power is the only one divided | NL10 section IV-D, p. 3462 | Lines 223, 228 |
| Stop, Eq. (21) | NL10 p. 3462 | Line 224 |
| P&O with the step dcr after the search | NL10 p. 3462, Fig. 8 | `finish`, lines 259-265. `mppt_controller.m`, lines 150-153 |
| New search when the power changes | NL10 Fig. 8, p. 3462 | `mppt_controller.m`, lines 165-210 (section 2.7) |
| Sampling time 0.05 s | NL10 p. 3462 | Not used. One probe is `p.Tsearch` = 40 ms (project value) |

### 2.2 Ceiling check (`gmppt_ceiling.m`), Idea B (`gmppt_ideab.m`), Idea C (`gmppt_ideac.m`)

| Source item | Where in the source | Code |
|---|---|---|
| Store sorted by duty | TASK 4.3, step 1 | `gmppt_store_add.m`, lines 31-36 (`st.ord`) |
| P_best | TASK 4.3, step 2 | `gmppt_store_add.m`, line 38. `gmppt_ceiling.m`, line 55 |
| U = V1 I2 for two neighbours | TASK 4.3, lemma | Line 68 |
| Open gap: U > (1 + eps_c) P_best and d2 - d1 > tau | TASK 4.3, step 3 | Lines 59 and 75 |
| Sensor error option delta_s | TASK 4.3 | Lines 58-59 and 75 |
| No open gap: hand over at the best sample | TASK 4.3, step 4 | Lines 92-95 |
| Split the open gap with the highest U. Tie below 1e-9: higher duty | TASK 4.3, step 5 | Lines 75-82. The loop goes up in duty, so a tie replaces the earlier gap |
| Store full: stop at the best sample | TASK 4.3, step 6 | Line 92 |
| Certificate ratio Cert | TASK 4.3 | Lines 72-74 and 85. `st.certAll` (line 86) is an addition |
| Idea B: DIRECT up to the end of the global stage | TASK 4.4, steps 1-2 | `gmppt_ideab.m`, line 25. `gmppt_direct.m`, lines 194-198 and 218-222 (`globalOnly`) |
| Corner split: line through (x, ln R), x = ln((1 - D) / D) | TASK 4.4, step 3 | `cornerDuty`, lines 109-125. Line 119 solves the line. Line 120 gives the duty |
| Clamp with theta = 0.1 | TASK 4.4, step 3 | Line 124 |
| Idea C: samples at Dlo, the middle and Dhi | TASK 4.5, step 1 | `gmppt_ideac.m`, lines 32-34 |
| Idea C: midpoint split, corner split as an option | TASK 4.5, step 2 | `gmppt_ideac.m`, line 55. `gmppt_ceiling.m`, lines 101-104 |

### 2.3 PSO (`gmppt_pso.m`)

| Source item | Where in the source | Code |
|---|---|---|
| Position = duty, velocity = duty step | I12 Eq. (13), p. 3630 | Lines 123-129 |
| Three particles | I12 Fig. 8 (N_P = 3), p. 3631 | Size of `p.pso_D0` |
| Start: velocity 0 | I12 Fig. 8 | Line 74 |
| First iteration: the start duties are the Pbest values | I12 p. 3631 | Line 106 (`st.it == 1`) |
| Pbest and Gbest | I12 section IV-A, Fig. 8 | Lines 105-116 |
| Velocity, Eq. (12), r1 and r2 in U(0, 1) | I12 p. 3630 | Lines 121-124 |
| Position, Eq. (13) | I12 p. 3630 | Line 129 |
| Small perturbation of the Gbest particle | I12 p. 3631, Fig. 5(b) | Lines 125-127 |
| w = 0.4, C1 = 1.2, C2 = 1.6 | I12 section V, p. 3633 | `p.pso_w`, `p.pso_c1`, `p.pso_c2` |
| Restart: Eq. (16) | I12 p. 3632 | Line 61 |
| Restart: Eq. (17), K1 or K1 / 2 | I12 p. 3632 | Lines 57-60 |
| Restart: Eq. (19), K2 = 0.05 | I12 pp. 3632-3633 | Lines 62-66 |
| Restart test "(14)", P_thr = 1.5 % | I12 Fig. 8, p. 3633 | Replaced by the restart test of the controller |
| Fixed duty at the end | I12 pp. 3628, 3631 | `st.end_kind = 2`, line 138. `mppt_controller.m`, lines 154-155 |
| Sampling interval 0.1 s | I12 p. 3633 | Not used. One probe is 40 ms |

### 2.4 GWO (`gmppt_gwo.m`)

| Source item | Where in the source | Code |
|---|---|---|
| Position = duty | M16 section III-B, Eq. (6), p. 183 | Lines 55, 114 |
| One probe for each wolf, then the update | M16 Fig. 5, p. 184 | Lines 70-79, then 83-118 |
| Alpha, beta, delta: the three best solutions | M16 section III-A, p. 182 | Lines 85-98 |
| a goes from 2 to 0 in equal steps | M16 p. 183. G14 code: a = 2 - l (2 / Max_iter), l from 0 | Line 101 |
| A = 2 a r1 - a | M16 Eq. (4) | Line 109 |
| C = 2 r2 | M16 Eq. (5) | Line 110 |
| Distance |C X_L - X| | G14 code (D_alpha). M16 Eq. (2) prints X_p in both terms | Line 111 |
| X_L = X_L - A dist | M16 Eq. (3). G14 code (X1) | Line 112 |
| New position = mean of X1, X2, X3 | G14 code | Lines 112 and 114 |
| New r1 and r2 for each leader | G14 code | Lines 107-108 |
| Positions kept in the limits | G14 code | Line 114 |
| Fixed duty at the end | M16 p. 183 | `st.end_kind = 2`. `mppt_controller.m`, lines 154-155 |

### 2.5 Variable-step INC (`vsIncStep` in `mppt_controller.m`)

| Source item | Where in the source | Code |
|---|---|---|
| dV, dI, dP of two periods | L08 Fig. 2, p. 2623 | Lines 295-296, 313 |
| Step = N |dP/dV|, Eq. (4) | L08 p. 2623 | Line 313 |
| Upper limit ΔDmax. Above it, the fixed step ΔDmax | L08 p. 2624 | Line 314 |
| N < ΔDmax / |dP/dV| at the fixed step ΔDmax, Eq. (6) | L08 p. 2624 | `p.vs_N` in `pv4x4_config.m`. `gmppt_methods.md`, section 7.2 |
| dI/dV > -I/V: D - step. dI/dV < -I/V: D + step | L08 Fig. 2 | Lines 315-319 |
| dI/dV = -I/V: no change | L08 Fig. 2 | Line 310, with the hold band `p.eps_inc` |
| dV = 0 and dI = 0: no change | L08 Fig. 2 | Lines 297-301, with the band `p.eps_di` |
| dV = 0 and dI > 0: D + step. dI < 0: D - step | L08 Fig. 2 | Lines 302-307, with `p.vs_hold_dir = 1` |
| Update V(k-1), I(k-1) each period | L08 Fig. 2 | `mppt_controller.m`, line 248 (`Vold`, `Iold`) |

### 2.6 Controller and config changes

| Change | Code |
|---|---|
| Local stage selected by `p.local` | `mppt_controller.m`, lines 148, 212-224 |
| Ending of the paper with `p.paper_end = 1` | Lines 149-157 |
| Restart test on periods of the same duty | Lines 165-190 |
| Timer | Lines 191-194 |
| History of the last four local periods | Lines 195-200 |
| Restart data for the search | Lines 202-208 |
| Real duty step of the local stage (`dDv`) | Lines 130, 216, 219, 221, 247 |
| Branches of `p.alg` = 1, 2 and 9 | Lines 226-246, not changed |

## 3. Second reading of each paper, after the code was written

Each entry is a place where the second reading differs from the first reading or from the code.

| No. | Paper | Finding | Action |
|---|---|---|---|
| S1 | NL10 | Section IV-C names the two new samples in the order DJ,3 then DJ,2. Sections III-A and IV-B name the left sample first. | No change. The order is not fixed. The code takes Dj,2 first. Listed in section 8.1 |
| S2 | NL10 | Eq. (21) uses the length of the absolute sampling interval. The code uses the length of the interval that is active (`st.L0`). | No change. The two are the same with `dir_range = 1`. Listed in section 8.1 |
| S3 | NL10 | The skip rules could also apply to the division of the extra samples (for example rule 1 when D3 is divided there). The text says that two samples are taken. | No change. Open question 8.3, item 2 |
| S4 | NL10 / TASK | `gmppt_ideab.m` passed the end state of DIRECT (`end_kind = 1`) to the controller when the store was full. Idea B has no ending of its own. | Fixed: lines 26-30 set `end_kind = 0` |
| S5 | I12 | The flowchart (Fig. 8) sets Pbest from the powers of this iteration and the iteration before only. The text defines Pbest as the personal best position. | No change. The code keeps the best so far. Listed in section 8.1 |
| S6 | I12 | Eq. (18) defines ΔP = P - P_old, and the next sentence says that ΔP > 0 is a fall of the insolation. The reported values are 1350 (fall) and 675 (rise). | The code follows the reported values: full K1 for a fall of the power. Listed in section 8.1 |
| S7 | I12 | The flowchart tests "(14)" for a restart. Eq. (14) is the vector of the duties. The paper prints no formula for the test. | The restart test of the controller replaces it. Listed in section 8.2 |
| S8 | G14 | The published code does not move the old alpha to beta when a new alpha comes. With 3 wolves, beta or delta can stay at their start value (zero). | The code keeps the three best points in rank order, as the text of M16 defines the leaders. Listed in section 8.1 |
| S9 | G14 | The published code puts the positions back into the limits at the start of the next iteration. The code does it at the update. | No change. The effect is the same, because the next step is the probe |
| S10 | L08 | In the branch dV = 0, the flowchart raises the duty when the current rose. The first design took the direction of the INC of `p.alg = 2`, which is the opposite. | Changed before the code was complete: `p.vs_hold_dir = 1` (the paper) is the default, and -1 gives the other direction |
| S11 | L08 | The flowchart calculates N |dP/dV| before the test dV = 0, so the step is not defined in that branch. | The code uses `p.vs_dDmin` there. Listed in section 8.1 |
| S12 | Controller | The first version compared the power only with the period before, or with the period two before. A scratch run (P1 to P0 at 2 s, P&O local stage) showed no restart: after a rise of the power the P&O does not turn, so no pair of periods with the same duty was on both sides of the change. | Fixed: the test looks back four local periods (lines 167-172). The P&O visits each of its three duties again in four periods |
| S13 | TASK | The ceiling check covers only the duties between the lowest and the highest sample. Idea B does not sample the ends of the range. | No change in the code. Stated in the header of `gmppt_ceiling.m` and in `gmppt_methods.md`, section 3.3. Open question 8.3, item 5 |

## 4. Online cross-check

### 4.1 DIRECT of Nguyen and Low

| Source | Type | What it restates | Agreement with the code |
|---|---|---|---|
| Bidram, Davoudi and Balog, IEEE J. Photovolt. 2(4), 2012, section III-C | journal | Division into three, the two inequalities, eps = 0.03 in the global mode and "reduced further" in the local mode, about ten sampling cycles | Agrees on the division and on eps = 0.03. It gives no zero for the local mode. The code takes 11 to 15 probes on the nine patterns |
| Ali et al., Energies 13(12), art. 3256, 2020, section 2.9 | journal | Center sample, division into three, Eqs. (11) and (12) in the form of the paper | Agrees |
| Low, Nguyen and Soon, Proc. ISPACS 2011 | conference paper, same authors | Same division and inequalities, eps = 0.03 global and 0 local, stop when (Dmax - Dmin) / 3^n is below a set value | Agrees. It supports the reading of S2: the stop uses the active interval |
| Xiao et al., Proc. IECON 2011, section III-D | conference paper | The new sample with the larger power becomes the new center | Different: it describes only a local search |
| Jones and Martins 2021, Finkel and Kelley 2004, Khong et al. 2013 (general DIRECT) | journal, report, journal | The rule of potentially optimal intervals for a minimum, all such intervals divided in each iteration | Agrees with `isPoi` after the change of sign for a maximum. NL10 divides only one interval per cycle, as the code does |

No opened source restates the shading test of Eqs. (19) and (20), the case of only one true test, the four skip rules, the test that ends the global stage, or the P&O after the search. The reading of these steps comes from NL10 alone. The thesis of T. L. Nguyen (NTU, 2011) is the most probable place for more detail. It could not be opened.

### 4.2 PSO of Ishaque et al.

| Source | Type | What it restates | Agreement with the code |
|---|---|---|---|
| Ishaque and Salam, IEEE Trans. Ind. Electron. 60(8), 2013 | journal, same first author | A later method: 3 particles, w = 0.4, no random numbers, no c1 and c2, velocity limit 0.035, a small perturbation of the Gbest particle, start duties between a calculated d_min and d_max, end when the velocity change and the voltage gap are small | Agrees on 3 particles, w = 0.4 and the perturbation. It is a different method for the rest. The code has no velocity limit, as I12 has none |
| Lian, Jhang and Tian, IEEE J. Photovolt. 4(2), 2014 | journal | Says that I12 has random numbers and that the 2013 paper removed them. Own values 0.4, 1.5, 1.5 with 3 particles | Agrees that I12 uses r1 and r2 |
| Mohanty et al. 2016 (M16), Kumar et al., IEEE Trans. Sustain. Energy 8(3), 2017, Kumar and Rao, Int. J. Renew. Energy Dev. 5(3), 2016 | journals | They name I12 as "improved PSO" and list w from 1 to 0.1, c1 from 2 to 1, c2 from 1 to 2 | Different from I12. These six values are those of Liu et al., IEEE Trans. Energy Convers. 27(4), 2012, Table III. The code follows I12 itself |
| Chtita et al., Sci. Rep. 12, 10637, 2022 | journal | Constant w = 0.4, C1 = 1.6, C2 = 1.2, 6 particles | c1 and c2 are exchanged against I12. The code follows I12 |
| Koad, PhD thesis, Brunel University London, 2017 | thesis | Says that I12 removed the random numbers | Different from I12, whose Eq. (12) has r1 and r2 |

Summary. The secondary sources do not agree with each other on the values of I12. The code takes each value from I12 itself (section V, p. 3633). No secondary source restates the restart rule of Eqs. (16) to (19). No open code that implements I12 was found.

### 4.3 GWO of Mohanty et al.

| Source | Type | What it restates | Agreement with the code |
|---|---|---|---|
| Mirjalili, GWO.m (code of the first author of G14) | code | a = 2 - l (2 / Max_iter), A and C for each leader with new random numbers, D = |C X_L - X|, X = (X1 + X2 + X3) / 3 | Agrees. Checked on 2026-11-21. The update of the leaders differs (S8) |
| Mohanty, Subudhi and Ray, IEEE Trans. Energy Convers. 32(1), 2017 | journal, same authors | 3 wolves, fixed start duties with equal spacing from 10 % to 90 %, the form with one leader, P&O after the wolves come together | Agrees on 3 wolves and fixed start duties. The code uses three leaders (decision of the user) |
| Chtita et al., Sci. Rep. 12, 2022 | journal | Three leaders and the mean of X1, X2, X3. 6 wolves, 30 iterations | Agrees on the update. Different numbers |
| Alshareef, Automatika 65(4), 2024 | journal | Three leaders and the mean. 4 duties at 0.1, 0.4, 0.6, 0.9 for its own method | Agrees on the update |
| Kumar and Rao, Int. J. Renew. Energy Dev. 5(3), 2016 and 6(3), 2017 | journals | "GWO of Satyajit et al. 2016" with 6 or 4 wolves, random start duties from 0.1 to 0.9, 100 iterations | Different numbers. M16 itself gives none |
| Ghilani et al., J. Eur. Syst. Autom. 57(5), 2024 | journal | The form with one leader, as M16 prints it | Different form. The code uses three leaders |

Summary. Sources that give an update with three leaders agree with the code. Sources that copy M16 print the form with one leader. The number of wolves is from 3 to 6, and the number of iterations from 30 to 100, or not given.

### 4.4 Variable-step INC of Liu et al.

| Source | Type | What it restates | Agreement with the code |
|---|---|---|---|
| Mei et al., IEEE Trans. Ind. Electron. 58(6), 2011 | journal | D(k) = D(k-1) ± N |dP/dV|. N < ΔDmax / |dP/dV|. ΔDmax is the upper limit. If the rule fails, the fixed step ΔDmax is used | Agrees: line 314 limits the step to `vs_dDmax` |
| Tian et al., J. Power Electron. 14(1), 2014 | journal | Same formula. Keeps the condition "fixed step = ΔDmax" on |dP/dV| | Agrees with the reading of 7.2 in `gmppt_methods.md` |
| Ye et al., Electronics 11(1), art. 43, 2022 | journal | The slope in the rule for N is the largest slope at the largest step under standard test conditions | Agrees with the use of the uniform curve P0. The code also checks the other eight patterns |
| Isaloo and Amiri, J. Eng. Sci. Technol. 11(4), 2016 | journal | Same formula and rule. ΔDmax = 0.05, N = 0.01 for its own plant | Agrees on the rule. The numbers are for another plant |
| Owusu-Nyarko et al., Electronics 10(19), art. 2331, 2021 | journal | Same formula. Warns that a small dV gives a large step | Agrees. The limit `vs_dDmax` covers this |

No opened source gives a lower limit of the step or says what the method does for dV = 0. Both are choices of this project (section 8.1).

### 4.5 Restart rules

`gmppt_methods.md`, section 8, gives the result. Of 17 sources, five print a relative power change against a threshold, four an absolute power change, three a slope or a shift of the peak, and three give no formula. Thresholds are from 1.5 % to 10 %. Timers of commercial inverters are from 3 min to 4 h, and papers use 1 to 15 min for a real system. 15 min is a common value. Not verified: the default values of Huawei, ABB or FIMER, Sungrow, GoodWe and Growatt.

## 5. Hand trace on a made-up example with three peaks

### 5.1 The example

All the numbers are made up for this trace.

- I-V curve: I = 10 A up to 30 V. A straight line to 6 A at 36 V. 6 A up to 66 V. A straight line to 3 A at 72 V. 3 A up to 100 V. A straight line to 0 A at 108 V.
- Peaks: 300 W at 30 V, 396 W at 66 V (the GMPP), 300 W at 100 V.
- Converter: ideal buck-boost with a 10 Ohm load, R = 10 ((1 - D) / D)². The peaks are at the duties 0.6461, 0.4881 and 0.3539.
- Config: the defaults of `pv4x4_config.m`, with `dir_Voc` = 108 V and `dir_Isc` = 10 A. Range 0.30 to 0.78, L0 = 0.48.

Check of one point by hand: D = 0.48667 gives R = 10 (0.51333 / 0.48667)² = 11.126 Ohm. On the line from 66 V to 72 V, I = 39 - 0.5 V. Then V / 11.126 = 39 - 0.5 V gives V = 66.115 V and I = 5.942 A, so P = 392.89 W.

The duties of each probe below were taken from a scratch run of the code (section 9). The decision at each probe was then checked by hand against the rule in the source.

### 5.2 DIRECT (`p.alg = 3`): 15 probes, hand-over at 0.48864

| Probe | D | V | I | P | Decision |
|---|---|---|---|---|---|
| 1 | 0.54000 | 43.539 | 6.000 | 261.23 | D1 = a + L0/2 |
| 2 | 0.38000 | 79.861 | 3.000 | 239.58 | D2 = a + L0/6 |
| 3 | 0.70000 | 18.367 | 10.000 | 183.67 | D3. Eq. (19): (10 - 6) / 10 = 0.40 >= 0.1, true. Eq. (20): (79.861 - 43.539) / 79.861 = 0.455 >= 0.2, true. Partial shading. Global cycle: the largest potentially optimal interval is D1 (best of the three thirds). Divide D1: 0.54 ± 0.16/3 |
| 4 | 0.48667 | 66.115 | 5.942 | 392.89 | D1,2 |
| 5 | 0.59333 | 34.109 | 7.261 | 247.66 | D1,3. Thirds left: D2 (239.58) and D3 (183.67). Divide D2. Skip rule 2: I_D2 = 3 < 10/3, so D2,2 (0.32667) is not taken |
| 6 | 0.43333 | 69.833 | 4.084 | 285.17 | D2,3. Divide D3. Skip rule 1: V_D3 = 18.367 < 108/3 = 36, so D3,3 (0.75333) is not taken |
| 7 | 0.64667 | 29.854 | 10.000 | 298.54 | D3,2. All thirds are divided. Two best: 392.89 at 0.48667 and 298.54 at 0.64667. Between them lie 0.54 and 0.59333, so they are not neighbours. Two more global cycles. All intervals have level 2, so the single potentially optimal one is the best: 0.48667. Divide: ± 0.16/9 |
| 8 | 0.46889 | 67.481 | 5.260 | 354.92 | |
| 9 | 0.50444 | 57.904 | 6.000 | 347.42 | Second extra cycle: the best interval of level 2 is 0.64667 (298.54). Divide: ± 0.01778 |
| 10 | 0.62889 | 31.452 | 9.032 | 284.08 | |
| 11 | 0.66444 | 25.504 | 10.000 | 255.04 | Local stage. Best: 0.48667, level 3, length 0.48/27 = 0.0178 > 0.0025. Divide: ± 0.005926 |
| 12 | 0.48074 | 66.585 | 5.707 | 380.02 | |
| 13 | 0.49259 | 63.663 | 6.000 | 381.98 | Best is still 0.48667, level 4, length 0.005926 > 0.0025. Divide: ± 0.001975 |
| 14 | 0.48469 | 66.274 | 5.863 | 388.58 | |
| 15 | 0.48864 | 65.708 | 6.000 | 394.25 | Best: 0.48864, level 5, length 0.001975 <= 0.0025. End, Eq. (21). Hand-over at 0.48864 (99.6 % of 396 W) |

### 5.3 Idea B refined (`p.alg = 4`): 8 probes, hand-over at 0.48667

Probes 1 to 7 are those of DIRECT. After probe 7 the global stage ends, and the ceiling check starts. P_best = 392.89 W at 0.48667. The open limit is 1.02 x 392.89 = 400.75 W.

| Gap (duty) | V1 | I2 | U = V1 I2 | Open? |
|---|---|---|---|---|
| 0.38000 to 0.43333 | 79.861 | 4.084 | 326.1 | no |
| 0.43333 to 0.48667 | 69.833 | 5.942 | 415.0 | yes |
| 0.48667 to 0.54000 | 66.115 | 6.000 | 396.7 | no |
| 0.54000 to 0.59333 | 43.539 | 7.261 | 316.1 | no |
| 0.59333 to 0.64667 | 34.109 | 10.000 | 341.1 | no |
| 0.64667 to 0.70000 | 29.854 | 10.000 | 298.5 | no |

Corner split of the open gap: R* = 69.833 / 5.942 = 11.752 Ohm. At d1 = 0.43333: R = 69.833 / 4.084 = 17.10 Ohm, x1 = ln(0.56667 / 0.43333) = 0.26826. At d2 = 0.48667: R = 66.115 / 5.942 = 11.127 Ohm, x2 = 0.05334. The line gives x* = 0.26826 + (ln 11.752 - ln 17.10) (0.05334 - 0.26826) / (ln 11.127 - ln 17.10) = 0.0807, so d* = 1 / (1 + e^0.0807) = 0.47984. The clamp [0.43867, 0.48133] does not change it.

| Probe | D | V | I | P | Decision |
|---|---|---|---|---|---|
| 8 | 0.47984 | 66.656 | 5.672 | 378.08 | New gaps: 0.43333 to 0.47984 with U = 69.833 x 5.672 = 396.1, and 0.47984 to 0.48667 with U = 66.656 x 5.942 = 396.1. Both are below 400.75. No open gap. Hand-over at 0.48667 (99.2 % of 396 W). `certAll` = 396.7 / 392.89 = 1.0097 (the gap 0.48667 to 0.54). `cert` = 396.1 / 392.89 = 1.0082 (the gaps that do not touch the best sample) |

The skip rules removed the samples at 0.32667 and 0.75333. The lowest sample is at 0.38, so the peak at the duty 0.3539 (300 W) is outside the range of the gaps. In this example it is not the GMPP.

### 5.4 Idea C (`p.alg = 5`): 11 probes, hand-over at 0.48750

| Probe | D | V | I | P | Decision (open limit = 1.02 P_best) |
|---|---|---|---|---|---|
| 1 | 0.30000 | 102.957 | 1.891 | 194.70 | Dlo |
| 2 | 0.54000 | 43.539 | 6.000 | 261.23 | Middle |
| 3 | 0.78000 | 7.955 | 10.000 | 79.55 | Dhi. P_best 261.23. Gaps: 0.30-0.54 U = 102.957 x 6 = 617.7, 0.54-0.78 U = 43.539 x 10 = 435.4. Both open. Split the highest: 0.42 |
| 4 | 0.42000 | 70.596 | 3.702 | 261.34 | Open: 0.30-0.42 (381.1), 0.42-0.54 (423.6), 0.54-0.78 (435.4). Split 0.54-0.78 at 0.66 |
| 5 | 0.66000 | 26.538 | 10.000 | 265.38 | Open: 381.1, 423.6, 0.54-0.66 (435.4). 0.66-0.78 (265.4) is closed. Split 0.54-0.66 at 0.60 |
| 6 | 0.60000 | 33.645 | 7.570 | 254.69 | Open: 381.1, 423.6, 329.6, 336.4. Split 0.42-0.54 at 0.48 |
| 7 | 0.48000 | 66.643 | 5.678 | 378.43 | P_best 378.43, limit 386.0. Open: 0.42-0.48 (400.9), 0.48-0.54 (399.9). Split 0.42-0.48 at 0.45 |
| 8 | 0.45000 | 68.790 | 4.605 | 316.78 | Open: 0.45-0.48 (390.6), 0.48-0.54 (399.9). Split 0.48-0.54 at 0.51 |
| 9 | 0.51000 | 55.386 | 6.000 | 332.32 | Open: 0.45-0.48 (390.6), 0.48-0.51 (399.9). Split at 0.495 |
| 10 | 0.49500 | 62.449 | 6.000 | 374.69 | Open: 0.45-0.48 (390.6), 0.48-0.495 (399.9). Split at 0.4875 |
| 11 | 0.48750 | 66.048 | 5.976 | 394.71 | P_best 394.71, limit 402.6. Highest ceilings: 398.3 and 396.3, both below the limit and in gaps of 0.0075. No open gap. Hand-over at 0.48750 (99.7 % of 396 W). Cert = 0.9896, certAll = 1.0090 |

### 5.5 PSO (`p.alg = 6`): 42 probes, hand-over at 0.64620 (a local peak)

Random numbers from `gmppt_rand.m` with the seed 12345, in order: 0.096617, 0.833995, 0.947702, 0.035879, 0.011546, 0.051155.

| Probe | Particle | D | P | After the iteration |
|---|---|---|---|---|
| 1 | 1 | 0.38000 | 239.58 | |
| 2 | 2 | 0.54000 | 261.23 | |
| 3 | 3 | 0.70000 | 183.67 | Iteration 1. Pbest = the start duties. Gbest = 0.54 (261.23). v1 = 1.6 x 0.833995 x (0.54 - 0.38) = 0.21350. v2 = 0 (the Gbest particle), so v2 = 0.005 (small perturbation). v3 = 1.6 x 0.051155 x (0.54 - 0.70) = -0.01310. New duties: 0.59350, 0.54500, 0.68690 |
| 4 | 1 | 0.59350 | 247.84 | |
| 5 | 2 | 0.54500 | 250.92 | |
| 6 | 3 | 0.68690 | 207.76 | Iteration 2. Pbest: 0.59350 (247.84), 0.54 (261.23), 0.68690 (207.76). Gbest stays 0.54. New duties: 0.62883, 0.53524, 0.63581 |
| 7 | 1 | 0.62883 | 284.02 | |
| 8 | 2 | 0.53524 | 271.42 | |
| 9 | 3 | 0.63581 | 290.66 | Iteration 3. Gbest = 0.63581 (290.66). The swarm now moves to the peak at 0.6461 |
| 10 to 42 | | | | Iterations 4 to 14. Gbest goes to 0.64620 (299.76 W). After iteration 14, each velocity is below 0.005 and each particle is within 0.005 of Gbest. End |

Result: the hand-over is on the local peak of 300 W, not on the GMPP of 396 W. No particle came nearer to the GMPP duty 0.4881 than 0.535 after the first iteration. This is the behaviour of the method with 3 particles and these start duties on this made-up curve. No value was changed after this result.

### 5.6 GWO (`p.alg = 7`): 30 probes, hand-over at 0.48421

| Probe | Wolf | D | P | After the iteration |
|---|---|---|---|---|
| 1 | 1 | 0.38000 | 239.58 | |
| 2 | 2 | 0.54000 | 261.23 | |
| 3 | 3 | 0.70000 | 183.67 | Iteration 1. Leaders: alpha 0.54, beta 0.38, delta 0.70. a = 2. Wolf 1, alpha: A = 2 x 2 x 0.096617 - 2 = -1.6135, C = 1.6680, dist = |1.6680 x 0.54 - 0.38| = 0.5207, X1 = 0.54 + 1.6135 x 0.5207 = 1.3802. Beta: A = 1.7908, C = 0.0718, dist = 0.3527, X2 = 0.38 - 1.7908 x 0.3527 = -0.2517. Delta: A = -1.9538, C = 0.1023, dist = 0.3084, X3 = 0.70 + 1.9538 x 0.3084 = 1.3025. Mean 0.8103, limited to 0.78. New duties: 0.78, 0.53611, 0.34973 |
| 4 | 1 | 0.78000 | 79.55 | |
| 5 | 2 | 0.53611 | 269.54 | |
| 6 | 3 | 0.34973 | 290.79 | Iteration 2. Leaders: 0.34973 (290.79), 0.53611 (269.54), 0.54 (261.23). a = 1.8 |
| 7 to 12 | | | | Iterations 3 and 4. Probe 8 at 0.44173 gives 300.84 W, the new alpha |
| 13 | 1 | 0.66409 | 255.86 | |
| 14 | 2 | 0.48421 | 387.54 | The new alpha, near the GMPP |
| 15 to 30 | | | | Iterations 5 to 10. No better point. After iteration 10 the limit `gwo_itmax` ends the search. Hand-over at 0.48421 (97.9 % of 396 W) |

## 6. Code-generation checklist

Rules: persistent data of fixed size, no dynamic memory, no cell arrays, no recursion, no `sort` or `unique`, no `rand`, no string handling in the run-time path, each array bound checked.

| File | Fixed sizes | Functions used | Array bounds |
|---|---|---|---|
| `mppt_controller.m` | Persistent scalars, `st`, `Dh` and `Ph` (1 x 4) | `min`, `max`, `abs`, `floor`, `isempty`, `zeros` | `Dh(j)` with j from 1 to 4. `p.Drep(j)` with the test of line 229, not changed |
| `gmppt_init.m` | Arrays from `size(p.Drep)`, `size(p.pso_D0)`, `size(p.gwo_D0)`, and 1 x 3 | `zeros`, `size` | No index |
| `gmppt_search.m` | Scalars | `switch`, `min`, `max` | No index |
| `gmppt_store_add.m` | No new array | `numel` | Line 20 returns if the store is full. The `while` loop of line 32 stops at k = 1 |
| `gmppt_direct.m` | `st.qD`, `st.qL` (1 x 3) | `abs`, `max`, `min`, `numel`, `Inf`, power `3^lev` | Each division is made only if `st.n + 2 <= nMax` (lines 170, 204, 224). Entries 1 to 5 exist when stage 2 reads them. `st.qi` is from 1 to 3 |
| `gmppt_ceiling.m` | Scalars | `log`, `exp`, `abs`, `max`, `min`, `numel` | The loop reads `st.ord(k+1)` with k up to `st.n - 1`. Line 92 ends the check when the store is full |
| `gmppt_ideab.m`, `gmppt_ideac.m` | Scalars | None | `st.qD` with indices 1 to 3 |
| `gmppt_pso.m` | Particle arrays of the size of `p.pso_D0` | `min`, `max`, `abs`, `numel` | Loops from 1 to Np. Line 135 ends the search before the store is full |
| `gmppt_gwo.m` | Wolf arrays of the size of `p.gwo_D0`, leaders 1 x 3 | `min`, `max`, `abs`, `numel` | Loops from 1 to Nw and 1 to 3. Line 120 ends the search before the store is full |
| `gmppt_rand.m` | Scalars | `mod` | No index. 16807 x s is below 2^53 |

Other points:

- No function calls itself. The call depth is at most 4 (controller, search, method, helper).
- The `while` loop of `gmppt_store_add.m` runs at most `p.Nmax` times. All other loops are `for` loops with a bound of `st.n`, Np, Nw, 3 or 4.
- Divisions. `I / V` in `incStep` and `vsIncStep` needs V > 0, as the INC of `p.alg = 2` already does. `vsIncStep` divides by dV only if |dV| >= 1e-6. `cornerDuty` takes logarithms only of positive values (line 112) and divides only if the two resistances differ (line 118). `isPoi` divides by a difference of lengths that is not zero, because equal levels take the other branch.
- `p.gwo_D0` needs at least 3 entries, so that the three leaders are set after the first iteration.
- Scratch check (section 9): `coder.screener` gave no message and no unsupported call. `codegen` made C code for the controller with dynamic memory off.

## 7. Interface checklist

| Item | Result |
|---|---|
| Signature `[D, Vm, Im, ph, np] = mppt_controller(V, I, p)` | Not changed |
| Signature `[st, D, fin] = gmppt_search(st, p, V, I)` and `st = gmppt_init(p)` | Not changed |
| First call with V = 0 and I = 0 returns the first probe duty | Each method: the branch `st.stage == 0` does not read V or I |
| The controller ignores `fin` on the first call | Lines 136 and 209 of the controller take only `st` and `Dk` |
| Later calls: next probe, or `fin = true` and the hand-over duty | Each method. `gmppt_search.m` passes the three outputs |
| `st.np` counts the applied probes | It is increased where a probe duty is returned: `nextProbe` in DIRECT, lines 105-106 of the ceiling check, and each probe branch of Idea C, PSO and GWO. It is not increased with `fin = true` |
| Hand-over duty in [Dmin, Dmax] | `gmppt_search.m`, line 44. The controller also limits the duty in line 247 |
| Probe duties in the search range | DIRECT and the ceiling check stay inside [a, b] by construction. PSO and GWO limit each position to [Dlo, Dhi] |
| Store overflow | Each method ends at its best sample before the store is full |
| `p.alg` = 1, 2, 9 | The branches are not changed. `dDv` is 0 for them, so line 247 gives the same duty. The scratch run gave the same log as the old controller in six cases (section 9) |
| `p.alg` = 8 | One probe at `p.Dstart`, then the local stage, as the old placeholder. The repeated restart of the old placeholder does not occur (section 9) |
| Existing fields of `mppt` | All are kept. `T_rescan` has a new default value (900 in place of 0). Used only for `p.alg` = 3 to 8 |
| `gmppt_static_run.m` | Works with the new files. It runs its own P&O after the search, so it does not use `p.local` |

## 8. Deviations, values not verified, and open questions

### 8.1 Deviations from a source

DIRECT (NL10):

1. The default range is 0.30 to 0.78, not the absolute interval of Eqs. (13) to (18). The interval of the equations is the option `dir_range = 1`.
2. The "specific sampling interval" from an estimate of Voc or Isc is not implemented. The paper gives no rule for the estimate.
3. Eq. (21) uses the length of the active interval, not always that of the absolute interval.
4. One probe lasts 40 ms, not 0.05 s.
5. The P&O with the step dcr after the search is an option (`paper_end = 1`). The default is the shared local stage.
6. The restart threshold ΔP_cr of the paper has no value. The restart rule of the controller is used.

PSO (I12):

7. The start duties, the size and the sign of the small perturbation, the end test and the limit of the iterations are not in the paper.
8. Each position is kept in [Dlo, Dhi]. The paper has no limit.
9. Pbest is the best position so far (text of the paper), not the rule of the flowchart.
10. The restart rule of Eqs. (16) to (19) is an option, off by default (decision of the user).
11. The fixed duty at the end is an option (`paper_end = 1`).

GWO (M16):

12. The update uses three leaders (G14), not the form with one leader that M16 prints (decision of the user).
13. The leaders are kept in rank order, not as the published GWO.m updates them.
14. The number of wolves, the start duties, the number of iterations and the end test are not in M16.

Variable-step INC (L08):

15. The hold band `eps_inc` replaces the exact test dI/dV = -I/V.
16. The step has a lower limit `vs_dDmin`.
17. After a hold, the move has the size `vs_dDmin`, because the step of the paper is not defined for dV = 0. The test is the current band `eps_di` of this project, and "after a hold" is the hold flag of the controller, not the test dV = 0.
18. The constant-voltage start program of the paper is not implemented.
19. One period lasts 20 ms, not 0.025 s.

Ceiling check (TASK):

20. `st.certAll` is an addition.
21. No deviation from the task definition is known.

### 8.2 Values and statements that are not verified

| Item | Status |
|---|---|
| `pso_K1` = 1.7e4 W per unit of duty | UNVERIFIED. An estimate with the ideal converter and two points. Used only with `pso_reinit = 1` |
| 3 wolves and fixed start duties with equal spacing (`gwo_D0`) | UNVERIFIED. From the report of a research agent on Mohanty et al. 2017. The paper is not on the disk |
| Restart test of I12 ("(14)", P_thr = 1.5 %) | The formula is not printed in the paper. Not implemented |
| `vs_N` = 4e-4 | Calculated from static curves by the rule of the paper. Not run in Simulink |
| `dir_alpha`, `dir_beta`, `dir_eta`, `dir_Isc_min`, `dir_Voc_min` | Values of this project. The paper gives none. Used only with `dir_range = 1` |
| Sources of the ceiling inequality (Boztepe et al. 2014, Wang et al. 2016) | Cited as the task definition gives them. Only the passages on the restart rule and on the skip process were read for this work |
| Tuy 2000 and Zhang et al. 2012 | Not on the disk and not read. Cited only for the corner split, as the task definition states it |
| Chiter 2005, BIRECT 2018, HALRECT 2024, Tiong et al. 2017, Matthiesen et al. 2020, Li et al. 2019 | Cited as the task definition gives them. Li et al. 2019 was read for the restart rule only |
| Secondary sources of section 4 | Collected by research agents. The agents list what they opened. Equations from PDF text can have lost signs and bars |
| Default scan intervals of Huawei, ABB or FIMER, Sungrow, GoodWe, Growatt | UNVERIFIED. Not used in the code |
| 0.06 % loss for a scan each 15 min (Koutroulis and Blaabjerg 2012) | Read in the open preprint. The paper takes the number from a talk on the PHOTON inverter tests (M. Trova, its reference [27]) |
| Park and Miller 1988 (generator of `gmppt_rand.m`) | Constants and citation confirmed by a web search. The paper itself was not opened |

### 8.3 Open questions for the integrator

1. **DIRECT, only one of Eqs. (19) and (20) true.** The second test uses the three samples around the new sample (`gmppt_methods.md`, section 2.4, item 2). The paper does not print this test. On this plant, Eq. (20) is false for seven of the nine patterns, so this path is the usual one. Is this reading accepted?
2. **DIRECT, skip rules in the division of the extra samples.** The code takes both samples there. Should skip rules 1 and 2 apply?
3. **DIRECT, skip rule 2 always fires** on the default range, because the current at D2 = 0.38 is always below Isc / 3. With Eq. (20) false, skip rule 4 removes the whole third of D2. The duties from 0.30 to 0.46 then have only the sample at 0.38 in the global stage. Should the skip rules use an estimate of Isc from the samples (for example I_D3), or other factors?
4. **Value of dcr.** 0.0025 gives a last interval of 0.00198. A value of 0.006 would end one level earlier and save two probes.
5. **Idea B, range of the certificate.** The gaps start at the lowest DIRECT sample and end at the highest. Should Idea B also sample `Dlo` and `Dhi` before the ceiling check?
6. **PSO, number of probes.** On the nine patterns the PSO takes 36 to 60 probes (1.4 s to 2.4 s). The end test `pso_tol` = 0.005 and the limit of 20 iterations are choices of this project. On the made-up example the PSO ends on a local peak.
7. **GWO, result.** With 3 wolves and 10 iterations, GWO hands over at 95.3 % of the GMPP on R1 and at 96.5 % on R5 (static check). The number of wolves and iterations are choices of this project.
8. **Direction after a hold.** `vs_hold_dir = 1` follows the paper. The INC of `p.alg = 2` uses the other direction. On a resistive load, the direction of the paper agrees with the move of the peak. Should the INC of `p.alg = 2` stay as it is?
9. **Restart reference.** `restart_ref = 1` does not see a slow change. `restart_ref = 2` sees it, but also restarts on a slow change of uniform irradiance. Which one is the default for the thesis runs?
10. **`T_rescan`.** The default is now 900 s. Each run script must set a value for its run time, or 0.
11. **Hold band and variable step.** At the edge of the hold band (0.30 I, about 10 W/V on the uniform array) the variable step is about 0.004, near the fixed step of 0.005. The step is small only inside the hold band, where the tracker does not move. A lower `eps_inc` would use more of the variable step.
12. **Model build.** The MATLAB Function block reads `mppt` from the model workspace. The new fields need a new build of `MPPT_4x4.slx` with the build script. The run scripts in `experiments/templates/` still have the old algorithm numbers.

## 9. Scratch checks

The checks ran in MATLAB R2025b on a copy of the files in a scratch folder outside the project. They read `results/pv4x4_sweeps.mat` and `src/plant/`. They changed no project file and no model. No value was tuned after a result. The plant was static: each duty gave the settled point at once, with the input resistance (R (1 - D)² + R_L) / D². The checks therefore say nothing about the converter dynamics.

### 9.1 Each search on the nine static curves (`gmppt_static_run.m`)

Probes of the search, and the power at the hand-over duty as a fraction of the GMPP:

| Pattern | DIRECT | Idea B | Idea C | PSO | GWO |
|---|---|---|---|---|---|
| P0 | 11, 1.0000 | 9, 0.9993 | 11, 0.9979 | 45, 1.0000 | 30, 0.9883 |
| P1 | 14, 1.0000 | 11, 1.0000 | 10, 0.9997 | 42, 1.0000 | 30, 0.9999 |
| P2 | 11, 0.9998 | 9, 0.9995 | 10, 0.9986 | 42, 1.0000 | 30, 0.9926 |
| P3 | 15, 0.9999 | 16, 0.9997 | 18, 0.9990 | 45, 1.0000 | 30, 0.9965 |
| R1 | 15, 1.0000 | 14, 1.0000 | 17, 0.9944 | 60, 1.0000 | 30, 0.9532 |
| R2 | 13, 0.9999 | 11, 0.9995 | 14, 0.9991 | 45, 1.0000 | 30, 0.9956 |
| R3 | 13, 1.0000 | 14, 1.0000 | 16, 1.0000 | 60, 1.0000 | 30, 1.0000 |
| R4 | 11, 1.0000 | 11, 0.9989 | 11, 0.9987 | 42, 1.0000 | 30, 0.9898 |
| R5 | 11, 0.9999 | 10, 0.9999 | 11, 0.9992 | 36, 1.0000 | 30, 0.9654 |

- `st.np` was equal to the number of applied probes in each of the 45 runs.
- Certificate ratios at the end: Idea B `cert` 1.003 to 1.022 and `certAll` 1.016 to 1.035. Idea C `cert` 1.008 to 1.021 and `certAll` 1.026 to 1.031.
- DIRECT paths: Eq. (19) was true for all nine patterns. Eq. (20) was true only for P1 and P3. The other seven patterns took the extra samples. Of these, R1, R2 and R3 were then found as shaded, and P0, P2, R4 and R5 as uniform. R4 has two peaks, and DIRECT still reached its GMPP through the local stage.
- GWO on R1 handed over at the duty 0.697, on a local peak.

### 9.2 Controller in a closed loop on the static plant

- **`p.alg` = 1, 2 and 9.** The old controller (`src/controller/`) and the new controller gave logs that are equal in each value, in six runs of 2 s with a change of the pattern at 1 s: P&O on P0 and P1, INC on P0, R1 and P3, replay on P1.
- **`p.alg` = 3 to 7, `p.local` = 1 and 2.** Start on P1, R1 or P3, change to P0 at 2 s, end at 4 s (30 runs). Each run made one search at the start and one search after the change, and no other search. One exception: the PSO on R1 was still in its first search at 2 s (60 probes), so it made one search only.
- **Change from P0 to R1 at 2 s** (10 runs): each method started one new search. The end power was 0.991 to 1.000 of the GMPP of R1, and 0.973 to 0.978 for GWO.
- **Variable-step INC.** In the run that was traced step by step (DIRECT on P1), it made one step of 0.001 after the hand-over and then held the duty. Over the 15 runs with `p.local = 2`, the power at the end of each phase was 0.998 to 1.000 of the GMPP after DIRECT and Idea B, and 0.991 to 1.000 after Idea C.
- **Timer.** `T_rescan` = 1 s with the power test off gave a new search each second of the local stage.
- **Options.** One run each, with no fault: `paper_end = 1` for DIRECT (the P&O then steps by 0.0025), PSO and GWO (the duty stays fixed). `pso_reinit = 1`. `restart_ref = 2` with both local stages. `dir_range = 1`. `c_corner = 1`. `delta_s = 0.01`. `vs_hold_dir = -1`. `p.alg = 8`.
- **Old fault.** With `p.alg = 8` (no search, hand-over at `Dstart`), the local stage climbed to the nearest peak and no restart occurred.

### 9.3 Code generation

- `checkcode` gave no message for the eleven files.
- `coder.screener` on the eleven files: no message, no unsupported call.
- `codegen` (library target, code only, dynamic memory off) was successful for `mppt_controller` with `p` as a run-time struct, and with `p` as a constant for `p.alg` = 1, 2, 3, 4, 5, 6, 7 and 9.

### 9.4 Not checked

- No run of `MPPT_4x4.slx`. The settling of the probes, the ripple of the averages and the solver are not in these checks.
- No run on the group-level patterns (`shading_patterns_grp.m`) or on random shading.
- No check on the real-time target.

## 10. Integration on 2026-11-21

The integrator (Claude Opus, in the project session) copied the files into `src/controller/` and `src/config/` and moved this note and `gmppt_methods.md` into `docs/notes/`. The user approved the answers below on 2026-11-21.

### 10.1 Answers to the open questions of 8.3

| Item | Answer |
|---|---|
| 1 | The reading is accepted. |
| 2 | Both samples are taken. The skip rules do not apply to the division of the extra samples. |
| 3 | The skip rules stay as the paper gives them. At D2 = 0.38 the array is near open circuit, which is the case that skip rule 2 is for. The random cases will show if the rule hides a global peak. |
| 4 | `dir_dcr` stays 0.0025. A value of 0.006 is larger than the P&O step, which the paper does not permit. |
| 5 | Idea B gets margin gaps with ceilings from `mg_Voc` and `mg_Isc`. An end is sampled only if its margin is open. See `gmppt_methods.md`, section 4, step 4. DIRECT (`p.alg = 3`) does not change. |
| 6 | The PSO settings stay for the baseline. |
| 7 | The GWO settings stay for the baseline. A check with 4 and 5 wolves follows later. |
| 8 | The INC of `p.alg = 2` does not change. `vs_hold_dir` = 1. |
| 9 | `restart_ref` = 1 is the default. The change test also runs `restart_ref` = 2. |
| 10 | Each run script sets `T_rescan`: 0 for the baseline, 1 s for the timer test. |
| 11 | `eps_inc` stays 0.30 for the baseline. |
| 12 | The models were made again with `build_mppt_4x4`. New run scripts were made from the templates (`experiments/run_gmppt_baseline.m`, `experiments/run_gmppt_restart_tests.m`). The templates stay as a record, with a note. |

### 10.2 Changes by the integrator

| File | Change |
|---|---|
| `gmppt_ceiling.m` | New input `margin`. With `margin = true`, the two margins are gaps (item 5). The default call of Idea C gives `false`, so Idea C does not change. |
| `gmppt_ideab.m` | Calls the ceiling check with `margin = (p.mg_on == 1)`. Header text. |
| `gmppt_ideac.m` | Calls the ceiling check with `margin = false`. |
| `pv4x4_config.m` | New fields `mg_on` = 1, `mg_Voc` = 183.2 V, `mg_Isc` = 36.44 A. Paths of the notes. No existing value changed. |
| `gmppt_direct.m`, `gmppt_gwo.m`, `gmppt_search.m` | Path of `gmppt_methods.md` in the header text only. |

### 10.3 Checks after the integration

- Static check (`gmppt_static_run.m`, the same plant as 9.1): the probe counts, the hand-over duties and the powers of algorithms 3 to 7 are equal to the table of 9.1. Idea B with `mg_on` = 0 and 1 gives the same result on the nine patterns: no margin opened.
- Unit test of the margins on made-up stores: an open margin with the highest ceiling gives a probe at `Dlo` or `Dhi`. A higher ceiling of a gap between samples is split first. After the end probe, the margin closes.
- `MPPT_4x4.slx` and `MPPT_4x4_grp.slx` were made again with the build script.
- Old against new controller in `MPPT_4x4.slx`, with a change of the pattern at 0.6 s: `p.alg` = 1, 2 and 9 gave equal logs (each duty, power and time step).
- `p.alg` = 1 and 2 against `results/mppt_results.mat` (24 runs of the mid-review): largest difference of the final power 0.000001 %.
- The Simulink baseline and the restart tests: `gmppt_baseline_2026-11-21.md`.

### 10.4 Value changes after the baseline (2026-11-21)

The user approved these changes after the baseline. `gmppt_local_stage_2026-11-21.md` gives the data.

| Field | Old value | New value | Reason |
|---|---|---|---|
| `c_corner` | 0 (midpoint split) | 1 (corner split) | Static check on the nine patterns: 93 probes in place of 118. Mean hand-over power 99.91 % in place of 99.85 % |
| `pso_D0` | 3 particles: 0.38, 0.54, 0.70 | 8 particles at the centers of 8 equal parts of the range | 50 seeds x 9 patterns: wrong peak in 10.7 % of the runs with 3 particles, 0 % with 8 |
| `pso_itmax` | 20 | 8 | 8 x 8 probes fill the store of 64 samples |
| `gwo_D0` | 3 wolves: 0.38, 0.54, 0.70 | 6 wolves at the centers of 6 equal parts of the range | 50 seeds x 9 patterns: wrong peak in 5.6 % of the runs with 3 wolves, 0 % with 6 |

The setting of Ishaque et al. (3 particles) stays available as a second case: `pso_D0` = [1/6, 1/2, 5/6] of the range and `pso_itmax` = 20.

### 10.5 Parabolic local stage (2026-11-21)

The user approved a third local stage after the analysis of `gmppt_local_stage_2026-11-21.md`. It is used with DIRECT, Idea B and Idea C only.

| File | Change |
|---|---|
| `mppt_controller.m` | New local stage `p.local = 3` (subfunctions `loc3Init`, `loc3Step`, `loc3Next`, `sgn`). The internal code of the hold of `paper_end = 1` changed from `loc = 3` to `loc = 0`. The timer of the restart counts the local time in control samples (`nl`) in place of `kt * Tmppt`. |
| `pv4x4_config.m` | New fields `par_kmax`, `par_tol`, `par_h`, `chk_eps`, `chk_T`, `chk_d`, `chk_db`, `chk_ramp`. Later the same day, with the approval of the user: `local` changed from 2 to the list [2 2 3 3 3 2 2 2] (3 for DIRECT, Idea B, Idea C, 2 for PSO and GWO). |
| `mppt_controller.m` (second change) | `p.local` can be a list with one entry for each `p.alg`. One value still applies to all searches. |
| `gmppt_methods.md` | Section 7.5. |

Checks: `checkcode` gives no message. The restart sets E, F and C give one search for each change. Section 6 of `gmppt_local_stage_2026-11-21.md` gives the results.
