---
title: Global MPPT searches and the local stage of the tracker
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-11-21
status: integrated on 2026-11-21. Idea B margins added by the integrator (section 4). Simulink baseline in gmppt_baseline_2026-11-21.md
---

# Global MPPT searches and the local stage of the tracker

## 1. Scope

This note describes the code in `fable_controller/controller/`. Each method is an implementation of a published method, or of published parts. The note names the source of each part. Where a source does not give a step or a value, the note states the choice that the code makes and marks it as a choice of this project.

| `mppt.alg` | Method | File | Main source |
|---|---|---|---|
| 3 | DIRECT search | `gmppt_direct.m` | Nguyen and Low, IEEE Trans. Ind. Electron. 57(10), 2010 |
| 4 | Idea B refined: DIRECT global stage, then the ceiling check with the corner split | `gmppt_ideab.m`, `gmppt_ceiling.m` | Nguyen and Low 2010. Boztepe et al. 2014. Wang, Li and Ruan 2016. Tuy 2000 |
| 5 | Idea C: bisection that the ceiling guides | `gmppt_ideac.m`, `gmppt_ceiling.m` | Boztepe et al. 2014. Wang, Li and Ruan 2016. Piyavskii 1972. Shubert 1972 |
| 6 | Particle swarm optimization (PSO) | `gmppt_pso.m` | Ishaque et al., IEEE Trans. Power Electron. 27(8), 2012 |
| 7 | Grey wolf optimization (GWO) | `gmppt_gwo.m` | Mohanty et al., IEEE Trans. Sustain. Energy 7(1), 2016. Mirjalili et al., Adv. Eng. Softw. 69, 2014 |
| after 3 to 7 | Variable-step incremental conductance (INC) | `mppt_controller.m` | Liu et al., IEEE Trans. Ind. Electron. 55(7), 2008 |

Common rules for all the searches:

- The tracker sets the duty cycle D of the buck-boost converter. A higher duty gives a lower array voltage.
- One search probe lasts 40 ms (`mppt.Tsearch`). The controller averages the last quarter of the probe.
- The search range is `mppt.Dlo` = 0.30 to `mppt.Dhi` = 0.78, if this note does not say otherwise.
- Each search ends with a hand-over duty. The same local stage then starts for all the methods (section 7), so only the search is different between the methods.
- With `mppt.paper_end = 1`, each search ends as its own paper says. This is off by default.
- The store of one search has 64 samples (`mppt.Nmax`). A search that would need more ends at its best sample.

Terms. A sample is the measured point (D, V, I) of one probe. P = V I is its power. The global maximum power point (GMPP) is the highest peak of the P-V curve.

## 2. DIRECT search of Nguyen and Low (`mppt.alg = 3`)

Source: T. L. Nguyen and K.-S. Low, "A global maximum power point tracking scheme employing DIRECT search algorithm for photovoltaic systems," IEEE Trans. Ind. Electron., vol. 57, no. 10, pp. 3456-3467, 2010. DIRECT ("dividing rectangles") is the Lipschitz search of Jones, Perttunen and Stuckman (J. Optim. Theory Appl. 79, 1993). The equation, figure and section numbers in this section are those of Nguyen and Low.

### 2.1 What it does

Each sample is the center of one interval of the duty axis. A division cuts an interval into three equal parts and takes one new sample at the center of each outer part. The search first decides from three samples if the array has partial shading. With shading, it divides the largest intervals first (globally biased stage). Then it divides only the interval of the best sample (locally biased stage) until that interval is short.

### 2.2 Steps

1. **Sampling interval** [a, b] of length L0 = b - a (section IV-A). See 2.4, item 1.
2. **First samples.** D1 = a + L0/2, D2 = a + L0/6, D3 = b - L0/6, in this order. D2 has the lowest duty and the highest voltage. D3 has the highest duty and the lowest voltage (Figs. 3 and 6).
3. **Shading test** (section IV-B):
   - Eq. (19): (I_D3 - I_D1) / I_D3 >= 0.1.
   - Eq. (20): (V_D2 - V_D1) / V_D2 >= 0.2.
   - Both true: partial shading. Go to step 4.
   - Both false: uniform irradiance. Go to step 6.
   - Only one true: extra samples. See 2.4, item 2.
4. **Globally biased stage** (section IV-C). Each cycle divides one interval: the potentially optimal interval with the largest length. Interval j is potentially optimal if a constant K > 0 exists with
   - Eq. (11): P_j + K d_j >= P_i + K d_i for each interval i, and
   - Eq. (12): P_j + K d_j >= P_max + eps P_max,

   where d is half of the length of an interval and eps = 0.03. The cycles continue until each of the three thirds is divided or removed by a skip rule. The skip rules use the first three samples:
   1. V_D3 < Vmin = Voc / 3: the sample D3,3 is not taken.
   2. I_D2 < Imin = Isc / 3, or V_D2 > Vmax = 0.9 Voc: the sample D2,2 is not taken.
   3. Eq. (19) is false: D3,2 and D3,3 are not taken.
   4. Eq. (20) is false: D2,2 and D2,3 are not taken.

   Dj,2 is the child of interval j at the lower duty. Dj,3 is the child at the higher duty.
5. **End of the global stage.** With no skip, the store now has nine samples. If the two samples with the highest powers are neighbours on the duty axis, the region of the GMPP is found. Go to step 6. If they are not neighbours, the search does two more global cycles and then goes to step 6.
6. **Locally biased stage** (section IV-D). Each cycle divides the interval of the sample with the highest power. Before each cycle, the search tests Eq. (21): if the length of that interval is `dir_dcr` or less, the search ends.
7. **Hand-over** at the duty of the best sample. The paper then holds the point with a P&O of step dcr. The code does this only with `mppt.paper_end = 1`.

On this converter and range, DIRECT takes 11 to 15 probes on the nine patterns of the project (static check, see `gmppt_review.md`, section 9).

### 2.3 Parameters

| Field of `mppt` | Value | Meaning | Source |
|---|---|---|---|
| `dir_range` | 0 | 0: range `Dlo` to `Dhi`. 1: range `dir_Dlo_abs` to `dir_Dhi_abs` | this project |
| `dir_Dlo_abs`, `dir_Dhi_abs` | 0.314, 0.785 | Absolute sampling interval | Eqs. (13) to (18), with input values of this project |
| `dir_c19` | 0.1 | Limit of Eq. (19) | paper, p. 3459 |
| `dir_c20` | 0.2 | Limit of Eq. (20) | paper, p. 3459 |
| `dir_eps_g` | 0.03 | eps of Eq. (12), global stage | paper, p. 3458 |
| `dir_eps_l` | 0 | eps, local stage. Not read by the code | paper, p. 3458 |
| `dir_Voc`, `dir_Isc` | 183.2 V, 36.44 A | Voc and Isc of the skip rules | this project, see 2.4, item 5 |
| `dir_kVmin`, `dir_kImin`, `dir_kVmax` | 1/3, 1/3, 0.9 | Factors of the skip rules | paper, p. 3461 |
| `dir_dcr` | 0.0025 | Critical duty change of Eq. (21) | value of this project, see 2.4, item 4 |

### 2.4 Points that the paper leaves open, and the reading of this code

1. **Duty range.** The paper calculates an "absolute sampling interval" from Eqs. (13) to (18). The inputs are the highest and lowest Voc and Isc, two scaling factors alpha and beta, the converter efficiency and the load range. The paper gives none of these values. It gives only its result for its own plant: (0.45, 0.85), for 20 W panels and a 10 Ohm load. Reading: the default range is the project range 0.30 to 0.78, as for every other search. With `dir_range = 1`, the code uses the interval that `pv4x4_config.m` calculates from Eqs. (13) to (18). The inputs are values of this project: Voc 183.2 V, Isc from 5.47 A (150 W/m²) to 36.44 A, alpha = 0.15, beta = 0.7, efficiency 1.0, load 10 Ohm. The result is (0.314, 0.785). To use the literal interval of the paper, set `dir_Dlo_abs = 0.45` and `dir_Dhi_abs = 0.85`. That interval does not contain the highest-voltage peak of pattern R1 on this plant (duty 0.36). The paper also describes a smaller "specific sampling interval" from an estimate of Voc or Isc. It gives no rule for the estimate, so the code does not have it.
2. **Only one of Eqs. (19) and (20) is true.** The paper says that DIRECT then takes "further samples" (section IV-B, Fig. 5a). For Eq. (19) false, it divides the better of D1 and D2 and uses the information of D1, the new sample and D2. It says that the case of Eq. (20) false is similar. It does not print the test for the new samples. Reading:
   - Eq. (19) false: divide the better of D1 and D2. One of the two new samples lies between D1 and D2 (D1,2 or D2,3).
   - Eq. (20) false: divide the better of D1 and D3. One of the two new samples lies between D3 and D1 (D1,3 or D3,2).
   - Make the test of Eqs. (19) and (20) again on the three samples around the new sample: the old sample at the higher duty takes the place of D3, the new sample takes the place of D1, and the old sample at the lower duty takes the place of D2.
   - Both true: partial shading. If not: uniform.

   Reason: the paper says "again", so the same two tests are used, and it names exactly these three samples. Both new samples are taken, as the text says. The skip rules do not apply to this division. If the test then finds shading, this division counts as the first global cycle, and skip rule 3 or 4 removes the third on the other side.
3. **Does a skip rule remove a whole third or one child?** Rules 1 and 2 name one sample each (D3,3 and D2,2). These are the outer children, which lie nearest to the ends of the range. Rules 3 and 4 name both children, so the third is not divided at all in the global stage. The code follows this wording. The locally biased stage can still divide such a third if its sample has the highest power.
4. **Value of dcr and its relation to the local step.** Eq. (21) ends the search when (D_max - D_min) / 3^n <= dcr. After n divisions, this quotient is the length of the interval of the best sample, which is also the distance of the last two samples from it. The paper gives no value. It says that dcr is smaller than the step of a normal P&O, and that the P&O after the search uses the step dcr. Reading: `dir_dcr` = 0.0025, which is half of the P&O step `dD` of this project. On a range of 0.48, each value from 0.0020 to 0.0059 gives the same result: the search ends at a length of 0.48 / 3^5 = 0.00198. With `paper_end = 1`, `dir_dcr` is also the step of the P&O after the search.
5. **Voc and Isc of the skip rules.** The paper says "Vmin = 1/3 Voc in our experiments" and does not say if Voc is a rated value or an estimate from the samples. Reading: the rated values of the array at standard test conditions, 183.2 V and 36.44 A, as config values. Reason: section IV-A lists the highest Voc and Isc as known values of the plant, and the controller cannot measure Voc during a search. Effect on this plant: at D2 = 0.38 the converter input resistance is 26.6 Ohm, so the current at D2 is always below Isc / 3 = 12.1 A. Skip rule 2 therefore always removes D2,2 (duty 0.327) on the default range.
6. **Ties.** If two samples have the same power, the sample that was taken first is the better one. The paper gives no rule. This rule needs no extra value and keeps the search repeatable.

### 2.5 Other notes

- **Eqs. (11) and (12) in the paper's own strategy.** The code tests Eqs. (11) and (12) for each interval and takes the potentially optimal interval with the largest length (`largestPoi` in `gmppt_direct.m`). The best interval of the largest length always passes both tests for each eps, because K can be as large as necessary. The value 0.03 therefore does not change a decision of the global stage. The local stage divides the best interval and needs no test.
- **Order of the two new samples.** The paper does not fix the order. The code takes the child at the lower duty first.
- **Thirds that a skip rule removed** are not in the comparison of Eq. (11).
- **Secondary sources.** No review that was opened repeats the shading test, the skip rules or the switch between the stages (`gmppt_review.md`, section 4.1). The reading above therefore comes from the paper alone.

## 3. The measured ceiling and the ceiling check

File: `gmppt_ceiling.m`. Ideas B and C use it.

### 3.1 The ceiling

Take two neighbour samples at the duties d1 < d2, with the measured points (V1, I1) and (V2, I2).

- Assumption A1: the array current does not rise when the voltage rises. This is true for a series-parallel array with bypass diodes.
- Assumption A2: a higher duty gives a lower voltage, so V1 >= V2.
- Lemma: each duty d in [d1, d2] gives P(d) <= U = V1 I2.
- Proof: V2 <= V(d) <= V1 by A2. Then I(d) <= I(V2) = I2 by A1. So P(d) = V(d) I(d) <= V1 I2.
- Conditions: each sample is in steady state, the irradiance and the temperature do not change during the search, and the sensors are exact.

Sources of the inequality: M. Boztepe et al., IEEE Trans. Ind. Electron. 61(7), pp. 3302-3312, 2014, and Y. Wang, Y. Li and X. Ruan, IEEE Trans. Ind. Electron. 63(1), pp. 235-245, 2016. Both papers use it to skip parts of a voltage scan.

### 3.2 The check

1. P_best is the highest sampled power.
2. A gap between two neighbours is open if U > (1 + eps_c) P_best and d2 - d1 > tau.
3. If no gap is open, the check ends. The hand-over duty is that of the best sample.
4. If not, the check splits the open gap with the highest U and samples the split duty. If two ceilings agree to a relative difference of 1e-9, the gap at the higher duty is split. Then it goes to step 1.
5. If the store is full, the check ends at the best sample.

The rule "split the gap with the highest bound first" is the rule of Piyavskii (1972) and Shubert (1972). LIPO uses the same rule for GMPPT with a Lipschitz bound (W. Li et al., IEEE Access 7, pp. 126323-126333, 2019).

Sensor error. With a bound `delta_s` for the relative error of each sensor, a gap is open if U (1 + delta_s)² > (1 + eps_c) P_best (1 - 2 delta_s). The default is `delta_s = 0`.

### 3.3 The certificate

At the end, the samples prove that the true maximum P* in the range of the samples obeys

P* <= max( (1 + eps_c) P_best, the ceilings of the gaps that are not wider than tau ).

The code writes two ratios into the search state at each step:

- `st.cert`: the largest U of the gaps that do not touch the best sample, divided by P_best.
- `st.certAll`: the largest U of all the gaps, divided by P_best.

Limit. The gaps cover the duties from the lowest sample to the highest sample only. Idea C samples both ends of the range. Idea B does not: the outer DIRECT samples lie L0/18 inside the range, or more after a skip rule. Without more, the check gives no bound for the two margins. Since 2026-11-21, Idea B bounds the margins (section 4, step 4). With `mg_on = 1`, the ratios `st.cert` and `st.certAll` include the margins.

### 3.4 Parameters

| Field of `mppt` | Value | Meaning | Source |
|---|---|---|---|
| `eps_c` | 0.02 | Relative margin of the open test | task definition of this project |
| `tau` | 0.01 | Smallest width of an open gap (duty) | task definition of this project |
| `delta_s` | 0 | Bound of the relative sensor error | task definition of this project |
| `theta` | 0.1 | Clamp of the corner split | task definition of this project |
| `c_corner` | 1 | Idea C: 1 = corner split, 0 = midpoint split | option. Changed from 0 to 1 on 2026-11-21 with the approval of the user (`gmppt_local_stage_2026-11-21.md`, section 2) |
| `mg_on` | 1 | Idea B: 1 = the margins are gaps (section 4, step 4), 0 = no margins | integrator, approved by the user on 2026-11-21 |
| `mg_Voc` | 183.2 V | Upper limit of the array Voc for the margin at `Dlo` | rated array Voc at 25 °C |
| `mg_Isc` | 36.44 A | Upper limit of the array Isc for the margin at `Dhi` | rated array Isc at 1000 W/m² |

## 4. Idea B refined (`mppt.alg = 4`)

File: `gmppt_ideab.m`. This method is an implementation of published parts. It is not a new method.

1. **DIRECT global stage.** The search runs the DIRECT of section 2 up to the end of its globally biased stage: the first samples, the shading test (with the extra samples if only one test is true) and, with shading, the global cycles with the skip rules. Source: Nguyen and Low 2010.
2. The two extra global cycles and the locally biased stage of DIRECT do not run.
3. **Ceiling check** of section 3 on all the DIRECT samples. Each open gap is split at its corner duty:
   - The corner of the gap is the point (V1, I2). It lies on the load line R* = V1 / I2.
   - For the ideal buck-boost, ln R = ln R_load + 2 x, with x = ln((1 - D) / D).
   - The code calculates the measured R = V / I and x at the two ends of the gap. It draws a straight line through the two points (x, ln R) and solves the line for ln R = ln R*. The result is the corner duty d*. This needs no converter value.
   - d* is clamped to [d1 + theta w, d2 - theta w], with w = d2 - d1 and theta = 0.1.
4. **Margins** (`mg_on = 1`, default). Added by the integrator on 2026-11-21, with the approval of the user (open question 8.3, item 5, of `gmppt_review.md`). The two parts of the range outside the samples are also gaps:
   - From `Dlo` to the lowest sample: each duty there has V <= `mg_Voc` and I <= I(lowest sample). The ceiling is U = `mg_Voc` x I(lowest sample).
   - From the highest sample to `Dhi`: each duty there has V <= V(highest sample) and I <= `mg_Isc`. The ceiling is U = V(highest sample) x `mg_Isc`.
   - The proof is that of section 3.1, with the limit in place of the missing end sample.
   - An open margin competes with the other gaps by its ceiling. If it has the highest ceiling, the next probe is at the end of the range (`Dlo` or `Dhi`). The margin then has zero width and closes.
   - Cost: 0 to 2 probes. On the nine patterns of the static check, no margin opened, so the probe counts did not change.
5. **Hand-over** at the duty of the best sample.

Source of the corner split: it is the projection step of the polyblock algorithm of monotonic optimization (H. Tuy, SIAM J. Optim. 11(2), pp. 464-494, 2000. Y. J. Zhang, L. Qian and J. Huang, Found. Trends Netw. 7(1), pp. 1-75, 2012, section 3.2). The two works were not read for this code. The step is implemented as the task definition of this project states it.

Why the corner. A sample on the load line of the corner replaces one ceiling V1 I2 by two ceilings V1 I* and V* I2. With V* <= V1 and I* <= I2, both are lower than the old one, whatever the curve does in the gap.

If the test of step 1 finds uniform irradiance, the ceiling check starts on the three samples (or five, after the extra samples).

## 5. Idea C: bisection that the ceiling guides (`mppt.alg = 5`)

File: `gmppt_ideac.m`. This method is an implementation of published parts. It is not a new method.

1. Sample the duties `Dlo`, (`Dlo` + `Dhi`) / 2 and `Dhi`, in this order.
2. Run the ceiling check of section 3. With `c_corner = 1` (default since 2026-11-21), each open gap is split at the corner duty of section 4. With `c_corner = 0`, each open gap is split at its midpoint, as in the first form of Idea C.
3. Hand-over at the duty of the best sample.

Sources of the parts:

- The ceiling: Boztepe et al. 2014 and Wang, Li and Ruan 2016 (section 3.1).
- Best-first search by a bound: Piyavskii 1972 and Shubert 1972, as in LIPO (Li et al. 2019).
- Halving with the end samples used again: L. Chiter, Appl. Math. Comput., 2005. BIRECT, J. Glob. Optim. 71(1), pp. 5-20, 2018. HALRECT, J. Glob. Optim. 88(1), pp. 139-169, 2024.
- Binary search in duty for partial shading: M. C. Tiong et al., IEEE CENCON 2017 (a conference paper).
- The same structure in one dimension: mixed monotonic programming, B. Matthiesen et al., IEEE Trans. Signal Process. 68, pp. 2529-2544, 2020.

## 6. Swarm searches

Both searches measure one particle with one probe. One iteration measures all the particles in turn and then moves them. Both need random numbers. `gmppt_rand.m` gives them: the "minimal standard" linear congruential generator s = 16807 s mod (2³¹ - 1) of S. K. Park and K. W. Miller (Commun. ACM 31(10), pp. 1192-1201, 1988). The start value is `mppt.rng_seed`, so each run repeats. Until 2026-11-22 each search of a run started again from `mppt.rng_seed`, so every restart repeated the random numbers of the first search. Since 2026-11-22 a restart continues the generator from the state at the end of the last search (`mppt_controller.m`). The first search of a run draws the same numbers as before.

### 6.1 PSO of Ishaque et al. (`mppt.alg = 6`)

Source: K. Ishaque, Z. Salam, M. Amjad and S. Mekhilef, "An improved particle swarm optimization (PSO)-based MPPT for PV with reduced steady-state oscillation," IEEE Trans. Power Electron., vol. 27, no. 8, pp. 3627-3638, 2012.

Steps:

1. **Start.** The particles start at the duties `pso_D0`, with zero velocity (Fig. 8 of the paper). The paper uses three particles. The code uses eight since 2026-11-21 (see the parameters).
2. **Best positions.** After each iteration, Pbest_i is the best position of particle i so far. Gbest is the best of the Pbest values. In the first iteration, the start duties are the Pbest values (section IV-B).
3. **Move**, Eqs. (12) and (13): v_i = w v_i + c1 r1 (Pbest_i - d_i) + c2 r2 (Gbest - d_i), then d_i = d_i + v_i. r1 and r2 are new random numbers in (0, 1) for each particle.
4. **Small perturbation** (section IV-B). In the second iteration, all three terms of Eq. (12) are zero for the Gbest particle. The paper gives it "a small perturbation". The code gives the velocity `pso_dpert` to a particle whose velocity is exactly zero.
5. **End.** See the choices below.

Parameters:

| Field of `mppt` | Value | Meaning | Source |
|---|---|---|---|
| number of particles | 8 | Entries of `pso_D0` | this project. The paper uses 3 (Fig. 8 and p. 3631). Changed from 3 to 8 on 2026-11-21 with the approval of the user (`gmppt_local_stage_2026-11-21.md`, section 3) |
| `pso_w` | 0.4 | Inertia weight | paper, p. 3633 |
| `pso_c1` | 1.2 | Coefficient of Pbest | paper, p. 3633 |
| `pso_c2` | 1.6 | Coefficient of Gbest | paper, p. 3633 |
| `pso_D0` | 0.33, 0.39, ..., 0.75 | Start duties: the centers of 8 equal parts of [`Dlo`, `Dhi`] | this project. Not in the paper. Was 0.38, 0.54, 0.70 (3 particles) |
| `pso_dpert` | 0.005 | Small perturbation | this project. Not in the paper |
| `pso_tol` | 0.005 | End test | this project. Not in the paper |
| `pso_itmax` | 8 | Most iterations. 8 x 8 probes fill the store of 64 samples | this project. Not in the paper. Was 20 (3 particles) |
| `pso_reinit` | 0 | 1: restart rule of the paper | option. Eq. (19) moves only the two outer particles. With more than 3 particles, the other particles then start at the same duty |
| `pso_K1` | 1.7e4 W | K1 of Eq. (16) | UNVERIFIED estimate, see below |
| `pso_K2` | 0.05 | Displacement of Eq. (19) | paper, p. 3632 and p. 3633 |

The paper states w, c1, c2 and the number of particles in its section V. They agree with the values of the older review table of this project (3 particles, 0.4, 1.2, 1.6).

Choices where the paper is not clear:

- **Start duties.** The paper says that the algorithm "transmits three duty cycles" and gives no values. The code uses the centers of equal parts of the range, one part for each particle. Every search starts from these duties (decision of the user, 2026-11-21).
- **Pbest.** The text defines Pbest as the personal best position. The flowchart (Fig. 8) compares only the power of this iteration with the power of the iteration before. The code keeps the best position so far, as the text says.
- **Size and sign of the small perturbation.** Not in the paper. The code uses +0.005, one P&O step.
- **Limits.** The paper has no limit for the duty or the velocity. The code keeps each position in [`Dlo`, `Dhi`].
- **End test.** The paper has none. It says that the velocities become almost zero at the peak and the duty then stays constant. The code ends the search when each particle has |v| <= `pso_tol` and is not more than `pso_tol` from Gbest. It also ends after `pso_itmax` iterations, or when the store has no space for one more iteration. The hand-over duty is Gbest.
- **Ending of the paper.** The paper holds the duty after the particles come together. With `paper_end = 1`, the controller holds the hand-over duty.
- **Restart of the paper.** The paper starts a new search when a test that its flowchart calls "(14)" is true, with P_thr = 1.5 %. Its Eq. (14) is not a test, and the paper prints no formula for it. The restart test of this controller replaces it (section 8). The paper then puts the particles near a new duty: d_new = d_old - (P_old - P) / K1 (Eq. (16)), with K1 or K1 / 2 by the direction of the change (Eq. (17)), and the start duties d_new - K2, d_new, d_new + K2 (Eq. (19)). The code has this rule as the option `pso_reinit = 1`, off by default. Eq. (18) and the sentence after it do not agree on the sign of the change. The code follows the values that the paper reports: the full K1 for a fall of the power, K1 / 2 for a rise.
- **K1.** The paper takes K1 from a plot of the peak power against the best duty for its own array (Fig. 7): 1350 W and 675 W per unit of duty. For this array, the same method with the ideal converter gives about 1.7e4 W per unit of duty (519 W at D = 0.32 for 100 W/m², 5194 W at D = 0.60 for 1000 W/m²). This value is UNVERIFIED: no simulated points were fitted.

### 6.2 GWO of Mohanty et al. (`mppt.alg = 7`)

Sources:

- [M16] S. Mohanty, B. Subudhi and P. K. Ray, "A new MPPT design using grey wolf optimization technique for photovoltaic system under partial shading conditions," IEEE Trans. Sustain. Energy, vol. 7, no. 1, pp. 181-188, 2016.
- [G14] S. Mirjalili, S. M. Mirjalili and A. Lewis, "Grey wolf optimizer," Adv. Eng. Softw., vol. 69, pp. 46-61, 2014, and the GWO.m code of its first author. The paper is not in `docs/references/`. The update rule below was checked against the published code on 2026-11-21.

What [M16] gives: the duty is the position of a wolf (section III-B), the encircling Eqs. (2) to (5), the duty update Eq. (6), the flowchart (Fig. 5), "a decreases linearly from 2 to 0" (section IV-A), and a fixed duty at the end. What [M16] does not give: the number of wolves, the start duties, the number of iterations, the end test and the restart test. Its Eqs. (2) and (6) use one leader, and Eq. (2) has the prey position in both terms. Decision of the user (2026-11-21): the code uses the update of [G14] with three leaders, which [M16] names as its source.

Steps:

1. **Start.** The wolves start at the duties `gwo_D0`.
2. **Leaders.** After each iteration, the three best points found so far are the alpha, beta and delta wolves, in rank order ([M16], section III-A).
3. **Parameter a.** a = 2 - 2 l / `gwo_itmax`, with l = 0 in the first iteration ([G14] code).
4. **Move.** For each wolf and each leader L, with two new random numbers r1 and r2: A = 2 a r1 - a, C = 2 r2, dist = |C D_L - D_wolf|, X_L = D_L - A dist. The new duty of the wolf is the mean of the three X_L. It stays in [`Dlo`, `Dhi`].
5. **End.** After `gwo_itmax` iterations, or when each wolf is not more than `gwo_tol` from the alpha wolf, or when the store has no space for one more iteration. The hand-over duty is that of the alpha wolf.

Parameters:

| Field of `mppt` | Value | Meaning | Source |
|---|---|---|---|
| `gwo_D0` | 0.34, 0.42, ..., 0.74 | Start duties: the centers of 6 equal parts of [`Dlo`, `Dhi`]. 6 entries = 6 wolves | this project. Changed from 3 to 6 wolves on 2026-11-21 with the approval of the user (`gmppt_local_stage_2026-11-21.md`, section 3) |
| `gwo_itmax` | 10 | Iterations in which a goes from 2 to 0 | this project. Not in [M16] |
| `gwo_tol` | 0.005 | End test | this project. Not in [M16] |
| a | 2 to 0 | Linear | [M16], p. 183 |

Choices and UNVERIFIED values:

- **Number of wolves and start duties.** [M16] gives neither. A later paper of the same authors (IEEE Trans. Energy Convers. 32(1), 2017) is reported to use 3 wolves at fixed duties with equal spacing. This report comes from a secondary check, and the 2017 paper is not in `docs/references/`. Until 2026-11-21 the code used 3 wolves. With 3 wolves, the GWO handed over on a wrong peak in 5.6 % of 450 static runs (50 seeds, 9 patterns). With 6 wolves it did not (`gmppt_local_stage_2026-11-21.md`, section 3). The code now uses 6 wolves at the centers of 6 equal parts of the range.
- **Leaders.** The code keeps the three best points in rank order. The published GWO.m does not move the old alpha to beta when a new alpha comes, so beta and delta can stay not set for some iterations. With 3 wolves this would put a leader at zero duty. The rank order follows the definition in the text of [M16] and [G14].
- **Number of iterations.** [M16] does not give it. Other authors use 30 or 100 iterations for 4 to 6 wolves. With 6 wolves and a store of 64 samples, 10 iterations are the most that fit. The value 10 is a choice of this project.
- **Ending of the paper.** [M16] holds the duty at the end. With `paper_end = 1`, the controller holds the hand-over duty.

## 7. Local stage after a search: variable-step INC

Source: F. Liu, S. Duan, F. Liu, B. Liu and Y. Kang, "A variable step size INC MPPT method for PV systems," IEEE Trans. Ind. Electron., vol. 55, no. 7, pp. 2622-2628, 2008. Code: `vsIncStep` in `mppt_controller.m`.

`mppt.local` selects the local stage after a search: 1 = the fixed-step P&O of `mppt.alg = 1`, 2 = the variable-step INC, 3 = the parabolic stage of section 7.5, 4 = the INC of `mppt.alg = 2` with its fixed step (added 2026-11-21 for the comparison of the local stages). It is one value for all searches, or a list with one entry for each `mppt.alg`. Default: 3 for DIRECT, Idea B and Idea C since 2026-11-21 (afternoon), and 3 for PSO and GWO too since 2026-11-21 (evening), so that the final tests compare the searches with the same local stage (`final_test_plan.md`, section 1). The INC of `mppt.alg = 2` stays a fixed-step baseline. On 2026-11-22 two faults of its hold were fixed: the current test now uses the change since the first period of the hold, and more current at the held duty now moves the duty up (before: down).

### 7.1 Rule

One decision per MPPT period of 20 ms, from the averages (V, I) of this period and (V_old, I_old) of the period before:

1. dV = V - V_old, dI = I - I_old, dP = V I - V_old I_old.
2. If the duty changed in the last period: e = dI/dV + I/V has the sign of dP/dV.
   - |e| <= `eps_inc` I / V: hold the duty (the hold band of the INC of this project).
   - If not: step = N |dP/dV| (Eq. (4) of the paper), kept between `vs_dDmin` and `vs_dDmax`. e > 0: the point is left of a peak, duty down by the step. e < 0: duty up by the step.
3. If the duty did not change (after a hold): dP/dV has no meaning. dI is then the change since the first period of the hold, not since the last period (changed on 2026-11-22, a choice of this project). If |dI| <= `eps_di` I, hold. If not, move by `vs_dDmin`: with `vs_hold_dir = 1`, more current gives duty up, and less current gives duty down.
4. The first local period after the hand-over makes one step of +`vs_dDmin` with no test, because the period before it was a search probe at a different duty.

### 7.2 Scaling factor N

The paper gives a design rule (its Eqs. (5) and (6)): choose a large fixed step ΔDmax, measure |dP/dV| in the steady state of the fixed-step tracker with this step, and take N < ΔDmax / |dP/dV|. ΔDmax is also the upper limit of the variable step.

For this project:

- ΔDmax = `vs_dDmax` = 0.02. The paper gives no rule for this value. It uses 0.05 against a small fixed step of 0.01, a factor of 5. Here the small fixed step is 0.005, and the factor is 4.
- |dP/dV| one step ΔDmax from the peak, on the static curves of `results/pv4x4_sweeps.mat` (input resistance (R (1 - D)² + R_L) / D²): for the uniform array (P0), 21.8 W/V on the low-voltage side and 27.5 W/V on the high-voltage side. Eq. (6) gives N < 0.02 / 27.5 = 7.3e-4.
- The same calculation for all nine patterns gives limits from 4.95e-4 (R1) to 1.50e-3 (P3).
- Chosen: N = 4e-4, below all nine limits.

This value comes from a calculation on static curves. It was not run in the Simulink model. Near a smooth peak of this array, |dP/dV| is about 1400 W/V per unit of duty, so one step moves the point about 0.56 of the way to the peak.

### 7.3 Parameters

| Field of `mppt` | Value | Meaning | Source |
|---|---|---|---|
| `local` | [3 3 3 3 3 3 3 3] | Local stage for each `mppt.alg`. Was 2 for all searches until 2026-11-21, then [2 2 3 3 3 2 2 2] until the evening of 2026-11-21 | this project |
| `vs_N` | 4e-4 | Scaling factor N | method of the paper, value of this project (7.2) |
| `vs_dDmax` | 0.02 | Largest step | method of the paper, value of this project |
| `vs_dDmin` | 0.001 | Smallest step | this project. Not in the paper |
| `vs_hold_dir` | 1 | Direction after a hold | 1: flowchart of the paper (Fig. 2), and since 2026-11-22 also the INC of `mppt.alg = 2`. -1: the opposite direction |
| `eps_inc` | 0.30 | Hold band | INC of this project |
| `eps_di` | 0.005 | Current band after a hold. Since 2026-11-22 the test uses the change since the first period of the hold | INC of this project |

### 7.4 Differences from the paper

- **Hold band.** The paper holds only if dI/dV = -I/V exactly. The code uses the hold band of the INC of this project.
- **Smallest step.** The paper has no lower limit. The code has `vs_dDmin`.
- **Duty not changed.** The flowchart of the paper calculates the step N |dP/dV| before it tests dV = 0, so the step is not defined in that branch. The code uses `vs_dDmin` there.
- **Direction after a hold.** In the branch dV = 0, the flowchart of the paper raises the duty when the current rose. On a resistive load, more irradiance at a fixed duty moves the peak to a lower input resistance, which needs a higher duty. The default follows the paper. Until 2026-11-22 the INC of `mppt.alg = 2` lowered the duty in this case (the rule of INC with a voltage reference). Since 2026-11-22 it raises the duty, as the paper does. `vs_hold_dir = -1` gives the old direction.
- **Start program.** The paper adds a constant-voltage start program for the start-up from open circuit. The local stage starts at a hand-over duty near a peak, so the code does not have this program.

### 7.5 Parabolic stage (`mppt.local = 3`)

Added on 2026-11-21 with the approval of the user. It is used and tested with DIRECT, Idea B and Idea C (`mppt.alg` = 3, 4, 5). It is an implementation of published parts. Code: `loc3Init`, `loc3Step` and `loc3Next` in `mppt_controller.m`. Reasons and results: `gmppt_local_stage_2026-11-21.md`.

Sources (all read in full):

- [P11] F.-S. Pai, R.-M. Chao, S. H. Ko and T.-S. Lee, "Performance evaluation of parabolic prediction to maximum power point tracking for PV array," IEEE Trans. Sustain. Energy, vol. 2, no. 1, pp. 60-68, 2011.
- [B73] R. P. Brent, "Algorithms for Minimization without Derivatives," Prentice-Hall, 1973, chapter 5, sections 4 and 5 (procedure localmin).
- [S08] D. Sera, R. Teodorescu, J. Hantschel and M. Knoll, "Optimized maximum power point tracker for fast-changing environmental conditions," IEEE Trans. Ind. Electron., vol. 55, no. 7, pp. 2629-2637, 2008. Read in the reprint in the PhD thesis of D. Sera (Aalborg University). The dP measurement first appeared in a conference paper: D. Sera, T. Kerekes, R. Teodorescu and F. Blaabjerg, Proc. IEEE ISIE 2006, pp. 1420-1425 (NOT A JOURNAL PAPER).
- [A18] V. Andrean, P. C. Chang and K. L. Lian, "A review and new problems discovery of four simple decentralized maximum power point tracking algorithms," Energies, vol. 11, no. 11, 2966, 2018. Source of the two risks below.

Steps:

1. **Fresh reading.** The first local period measures the hand-over duty (the best sample) again, with the probe timing (`Tsearch`, last quarter). If the power differs from the stored sample by more than `chk_eps`, the stored samples are old, and the stage goes to step 4 at once. Reason: [A18], section 3.3, shows that golden-section and quadratic-interpolation trackers fail when the curve changes and old points are not measured again.
2. **Refinement.** The bracket is the best sample and its nearest neighbours with a different duty in the store of the search. If one neighbour is missing, the stage probes `par_h` away on that side first. If that probe is better, the bracket shifts to it (the shifting procedure of [P11], section III-A). Then the steps of localmin of [B73] follow: a parabolic step through x, w and v ([B73] Eqs. (4.3) to (4.6), the same parabola as [P11] Eqs. (1) to (3)), or a golden-section step ([B73] Eq. (4.7)) if the parabolic step is not acceptable. No probe comes nearer than `par_tol` to a known point. The refinement ends when the bracket is 2 `par_tol` or less on each side of x, or after `par_kmax` probes. Each probe has the probe timing.
3. **Hold.** Since 2026-11-22 (`vh_on` = 1), the stage holds the voltage V0 of the first hold period: in each period it moves D0 so that V goes back to V0 (section 8.1). With `vh_on` = 0, the duty stays at D0, as before. The level test of section 8.1 runs in each hold period.
4. **Check.** After each `chk_T` of hold: five periods at D0, D0 + d, D0, D0 - d, D0, with d = `chk_d`. Each side power is corrected by the mean of the two centre powers around it, which removes a change of irradiance at a constant rate. This is the extra measurement of [S08], Eq. (1), applied on each side. A parabola through the three corrected points gives the move of D0, at most 2 d. D0 moves only if the predicted gain is more than `chk_db` times the power. If the corrected points are not concave, D0 moves by d to the better side, if that side is better by more than `chk_db`. If the centre power changed by more than `chk_ramp` during the check and the voltage hold is off, the next check follows at once ([S08] uses the sign of the irradiance change in the same way to select its strategy). With the voltage hold on, the hold follows the drift instead. Since 2026-11-22 the next check also follows at once if the move was at its limit (the vertex is more than 2 d away, or the points are not concave and D0 moved by d). This is a choice of this project. Far from the peak, D0 then moves up to 2 d in each check of 0.1 s, not in each `chk_T`.

Differences from the sources:

- **Start of Brent.** localmin starts with e = 0, so its first step is a golden-section step. Here three points are known, so e starts at the width of the bracket and the first step may be parabolic, as in [P11].
- **Point that is dropped.** [P11] drops the lowest of four points at each step. [A18] shows that this rule can stop at a wrong point (the "NQI trap"). The stage keeps the points of localmin instead, with its tolerance rule.
- **End test.** [P11] ends when two predicted powers are nearly equal. The stage uses the end test of [B73] and a limit of probes.
- **Check.** [S08] measures in the middle of one P&O period. The stage measures the centre duty before and after each side duty. The parabola through the corrected points is the parabola of [P11].

Parameters (start values from the static analysis, not tuned):

| Field of `mppt` | Value | Meaning |
|---|---|---|
| `par_kmax` | 3 | Most probes of the refinement |
| `par_tol` | 0.001 | tol of [B73] (duty) |
| `par_h` | 0.01 | Distance of an end probe (duty) |
| `chk_eps` | 0.01 | Limit of the fresh reading: old samples |
| `chk_T` | 1 s | Hold time between two checks |
| `chk_d` | 0.002 | Duty step of the check |
| `chk_db` | 1e-4 | Dead band of the check (fraction of the power) |
| `chk_ramp` | 1e-3 | Drift of the centre power that starts the next check at once |

Timer. Since 2026-11-21, the timer of the restart (`T_rescan`) counts the local time in control samples, so the probe periods of the parabolic stage count with their true length. For the local stages 1 and 2, all periods are 20 ms, and the count gives the same result as before.

## 8. Restart of the global search

Code: `mppt_controller.m`, in the branch of the local stage.

### 8.1 Power-change trigger

The form that published GMPPT controllers use most often is the relative power change against a threshold: |P - P_ref| / P_ref > threshold. A check of 17 sources on 2026-11-21 found this form, with an explicit formula, in five of them:

- Y.-H. Liu et al., IEEE Trans. Energy Convers. 27(4), 2012, Eq. (8): against the last power.
- Wang, Li and Ruan, IEEE Trans. Ind. Electron. 63(1), 2016, Eq. (7): against the stored power of the GMPP, threshold 0.1.
- Kermadi et al., IEEE Trans. Ind. Electron. 66(9), 2019, section II-D: threshold 0.1.
- Li et al., IEEE Access 7, 2019, Eq. (3): against the tracked maximum, threshold 0.02.
- Eltamaly and Farh, Sustainability 12(3), 2020, Eq. (2): threshold 0.05.

Four sources use an absolute power change (for example Furtado et al., IEEE Trans. Ind. Electron. 65(4), 2018: 5 % of the rated power). Ishaque et al. 2012 give a threshold of 1.5 % with no formula. Nguyen and Low 2010 start a new search when the power changes while the duty does not (section IV-B and Fig. 8).

Rule of this controller (since 2026-11-22, with the approval of the user, after a review of the restart rules of 20 papers):

| Part | Rule | Source |
|---|---|---|
| Level test | \|P - P_ref\| > `dP_restart` P_ref, with `dP_restart` = 0.05 and P_ref the power at the first steady state after the hand-over, when the local stage has settled | Wang et al. 2016, Eq. (7); Furtado et al. 2018, Eq. (5); Li et al. 2019; Ahmed et al., IEEE Trans. Power Electron. 38, 2023, Eq. (11) |
| Steady state | The test is made only when the power changes by at most `st_band` P (0.02 %) per period of 20 ms. The rate of change is the slope of a least-squares line through the powers of the last `st_win` = 10 periods (0.2 s). A change faster than about 1 % per second is thus not tested until it ends. | Boztepe et al. 2014: the test is blocked until the local tracker is in steady state |
| Voltage hold | Parabolic stage: between two checks, the duty moves so that the voltage stays at the voltage V0 of the first hold period (`vh_on` = 1) | The voltage loop of Boztepe et al. 2014, Furtado et al. 2018 and Kermadi et al. 2019. Kermadi et al. 2019 note that a change of irradiance then does not move the operating point off the peak. |
| Power floor | The level test is off while P is below `P_floor` = 260 W (5 % of the rated power). It is on again above `P_floor_hys` P_floor = 286 W. P_ref does not change below the floor. | A choice of this project (2026-11-24). At low power it has the same effect as the absolute threshold of Furtado et al. 2018 (5 % of the rated power). |
| Timer | `T_rescan` = 900 s (section 8.2) | Wang et al. 2016; Kermadi et al. 2021; Sun et al. 2023 |

The step of the voltage hold. For the ideal buck-boost, ln R_in = ln R_load + 2x with x = ln((1 - D)/D), the relation of the corner split (section 3). If the current stays the same, the voltage V0 needs ln R_in to change by ln(V0/V), so x changes by ln(V0/V)/2. Near the peak the current also changes, so this step is smaller than the full step, and the hold does not overshoot. The step needs no value of the converter. A choice of this project: the gain `vh_k` = 1, at most `vh_max` = 0.01 of duty in one period.

How the parts work together:

1. After a search and the refinement, the parabolic stage holds the voltage V0. P_ref is the power at the first steady state (the slope over the last `st_win` hold periods is in the band). A first version took P_ref at the first period after the hand-over. Below about 60 W/m2 the peak lies at a duty below `Dlo`, so each search hands over at `Dlo`, the local stage climbs further, the power rises by more than 5 %, and a new search started about every second (7816 searches in one day with P&O after DIRECT, static bench, 2026-11-22). The steady condition of Boztepe et al. 2014 applied to P_ref removes this.
2. While the light changes on all panels, the voltage hold keeps the operating point near the peak. The power changes faster than the steady limit, so no test is made.
3. When the light is steady again (slope over 10 periods in the band), the level test runs. If the power differs from P_ref by more than 5 %, a new search starts, with all five searches the same.
4. The check every `chk_T` (1 s) moves D0 to the peak of a fitted parabola. After each check, V0 is the voltage of the new D0.

For the local stages 1, 2 and 4, the level test is made only at the end of a local period whose duty is the same as the duty of one of the four local periods before it (the P&O visits each of its three duties again in four periods). The rate of change is the mean of (P - P of the matched period) / jm over the last `st_win` matched periods. A first version compared only one pair of periods: on a slow ramp with the sensors on, the noise let single pairs pass, and DIRECT with the INC stage searched every 5 s (static bench, 2026-11-22). `restart_ref = 1` keeps the old test of the rate of change (P_ref is the power of the matched period).

A test that was rejected. Nguyen and Low 2010 (Eqs. (19) and (20)) and Ghasemi et al., IEEE Trans. Power Electron. 31(9), 2016 decide first whether a change is uniform, and search only if it is not. On the 1824 curves of phase 1b, the test of Nguyen and Low gave the verdict "uniform" for none of the 27 curves with one peak (the current at D3 is always more than 10 % above the current at D1 on this array and duty range), and for 5 of the 1797 curves with more than one peak. The test thus does not separate the two cases here, and the controller does not use it. The test of Ghasemi et al. needs a temperature sensor and one module voltage.

History. Until 2026-11-22 the default was `restart_ref = 1`: P_ref was the power of the matched period, which tests a rate of change. In phase 3 of the first run of the final tests (event 40, a cloud edge over about 3 s), the power rose by a factor of 4.6, the largest change between two 20 ms points was 2.8 %, no search started, and the parabolic stage stayed near 72 % of the GMPP. A level test with no steady condition started about one search for each 5 % of power on an irradiance ramp (96.7 % on the 30 W/m2/s row of EN 50530 for DIRECT, in place of 99.97 %). The rule above gives 99.72 % on that row and 97.84 % on event 40 for DIRECT (static bench).

Change of 2026-11-23 (with the approval of the user). Until this date the steady condition was: the power changes by at most `st_band` P in each of `st_N` = 5 periods in a row. Phase p3n of the second run showed that sensor noise breaks this test. The noise of the power of one period is larger than the band at 1 x the sensor noise below about 300 W/m2 and at 10 x the noise in full sun. A static check with the sensor model gave these shares of 0.1 s windows that passed the old test: 1 x noise: 100 % at full sun, 99.5 % at 300 W/m2, 27 % at 100 W/m2. 10 x noise: 11 %, 0.2 %, 0 %. 30 x noise: 0 % at all levels. With no test, a pattern step that needs a search starts none (phase p3n, set B, Idea C: 86.9 % and 77 wrong ends of 100 at 30 x noise). A slope fitted over 10 periods has about one ninth of the noise of one period, and passed in 91 % to 100 % of the windows up to 10 x noise (43 % to 100 % at 30 x). The test with no steady condition at all (`st_N` = 0) removed the noise problem but started searches during each change: on the cloud events of phase 3, 176 searches in place of 40 (96.35 % in place of 98.99 %), and on the EN 50530 ramps 2928 searches in place of 383 (97.53 % in place of 99.74 %, Idea C, static bench). The steady condition is thus kept, and only its measurement changed.

Power floor (2026-11-24, with the approval of the user). On full days (static bench, four days of phase 4, Idea C), the rule above started 8413 searches in four days, with 99.779 % of the GMPP energy. Most searches came between 5 h and 7 h and between 17 h and 19 h. At sunrise the power rises by about 0.5 % per second. This is slower than the steady limit (1 % per second), so the level test runs, and each rise of 5 % starts a search. Most of the loss came in the 30 s after each search, not in the search itself. Four other changes were tested on the static bench and not used:

- A fixed hold-off after each hand-over (no level test for 30 s to 360 s). 60 s gave 99.954 % with 974 searches, but after a pattern step that needs a search, the mean recovery took 45 s in place of 1.8 s.
- A hold-off that doubles when the search finds the same peak. The voltage often moved by more than 5 % on the same peak, so the hold-off stayed at its first value.
- A threshold of 10 % in place of 5 %. It missed needed searches (18 of 100 pattern steps not recovered).
- A shorter timer (300 s) and a light check at the timer (the held point and three probes, with the ceiling test of section 3 in place of a full search). Each one was tested only together with a hold-off, and each of these settings failed the step test.

The floor was tested at 2 %, 5 % and 10 % of the rated power. The pass conditions (agreed with the user before the test): at least 99.9 % on the open-sky days, a mean recovery of at most 30 s after a needed pattern step with no more steps left unrecovered than with no floor, and the EN 50530 rows of phase 2 not worse on P0 and R1. Results, Idea C with the parabolic stage:

| Floor | Days, open sky | Searches, 4 days | Needed steps (1 x noise): mean recovery, not recovered of 100 | EN 50530, R1, 10 % to 50 % |
|---|---|---|---|---|
| None | 99.779 % | 8413 | 1.8 s, 7 | 99.288 % |
| 2 % | 99.897 % | 3683 | 1.8 s, 7 | 99.288 % |
| 5 % | 99.968 % | 521 | 1.8 s, 7 | 99.431 % |
| 10 % | 99.968 % | 418 | 1.8 s, 7 | 99.453 % |

The lowest floor that passes is 5 %. The P0 rows and the R1 row of 30 % to 100 % did not change. With DIRECT as in its paper, the floor of 5 % gave 99.921 % with 527 searches in place of 99.911 % with 1728, with the same results on the pattern steps. 521 searches in four days is about 130 searches in each day, the same order as a scan each 6 min (the usual value of SMA ShadeFix, section 8.2) over 13 h of daylight. A change that leaves the power at the held point the same is still found only by the timer (section 8.2).

A uniformity check before each search (the ratio of the current near short circuit to the current at the held voltage, after Ahmed and Salam, IEEE Trans. Ind. Informat. 13(5), 2017) was tested offline on 2026-11-23 and not used: it skipped 38 of 40 unneeded searches on the cloud events, but it also skipped needed searches after some pattern steps, with a loss of up to 40 %.

### 8.2 Fixed periodic rescan

A new search starts after `T_rescan` seconds of the local stage, whatever the power does. It covers a change that leaves the power at the held point the same, for example when another peak grows above the held peak. Xu et al. (IEEE Trans. Ind. Electron. 68(1), 2021) give this reason for a timer.

Default: `T_rescan` = 900 s (15 min). Sources:

- E. Koutroulis and F. Blaabjerg, IEEE J. Photovolt. 2(2), pp. 184-190, 2012: a scan each 15 min costs less than 0.06 % of the energy on an array with no shade. The paper takes this number from a talk on the PHOTON inverter tests (M. Trova, its reference [27]), not from a measurement of its own.
- Wang, Li and Ruan 2016 use 15 min.
- Commercial inverters: SMA ShadeFix gives 6 min as the usual value (range 180 s to 3600 s, SMA operating manual). Huawei gives a range of 5 to 30 min, and Solis a default of 30 min (range 10 to 180 min), both in the manufacturer documents.

A simulation run lasts a few seconds, so the run script must set its own value. `T_rescan = 0` turns the timer off.

## 9. What is not done

- No run in the Simulink model. The checks used the static curves of `results/pv4x4_sweeps.mat` and a static plant. `gmppt_review.md`, section 9, lists them.
- No value was tuned.
- The certificate of section 3.3 holds only under its conditions. The settling error of a probe (0.21 % in the worst case, `docs/notes/pv4x4_shading_and_po.md`, section 5.1) is a sensor error in the sense of `delta_s`.
