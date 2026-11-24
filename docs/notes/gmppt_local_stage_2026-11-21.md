---
title: Local stage, corner split of Idea C, and the sizes of PSO and GWO
date: 2026-11-21
status: sections 2 and 3 are applied (approved by the user). Section 4 is a measurement. The stage of section 5 was built on 2026-11-21 after the approval of the user (mppt.local = 3, for DIRECT, Idea B and Idea C only). Section 6 gives its results. Since 2026-11-21 (approval of the user), it is the default local stage for DIRECT, Idea B and Idea C. PSO and GWO keep the variable-step INC.
---

# Local stage, corner split of Idea C, and the sizes of PSO and GWO

## 1. Scope

The Simulink baseline (`gmppt_baseline_2026-11-21.md`) showed that DIRECT ends at a higher power than Ideas B and C. This note finds the cause, records three value changes that the user approved, measures the hold band of the variable-step INC (VS-INC) in Simulink, and proposes a new local stage.

The static results come from `gmppt_static_run.m` on the static curves of `results/pv4x4_sweeps.mat`. In the baseline, Simulink gave the same probe counts and hand-over duties as the static plant in all 45 search runs. A search time is therefore the number of probes times `Tsearch` (40 ms). The scratch scripts of the static analysis are not in the repository.

## 2. Why Ideas B and C end below DIRECT

### 2.1 Cause

The search is not the cause. All three methods find the global peak on all nine patterns. The difference comes from the last 0.002 of duty, and it has two parts.

1. **Ideas B and C hand over further from the peak.** The ceiling check ends when no gap is open. Near a smooth peak, the ceiling of each gap next to the best sample stays above (1 + `eps_c`) times the best power. These gaps close only when they become narrower than `tau` (0.01). DIRECT divides the best interval until it is 0.0025 wide or less. With `eps_c` = 0.005 in place of 0.02, no hand-over duty of Idea B changed. Only `tau` changed them. This early end is the intent of Ideas B and C: they leave the final approach to the local stage.
2. **The VS-INC does not climb the rest of the way.** The first local period always steps +0.001 in duty, on either side of the peak. The next period tests the slope over this small step. With `eps_inc` = 0.30, the hold band reaches 2.0 V to 2.7 V on each side of a smooth peak, and the loss at its edge is up to 0.33 %. (The comment in `pv4x4_config.m` gives ±1.5 V, which is too small.) If the point is in the band, the tracker holds. After a hold, it tests only the current, so it does not climb again.

The static plant gives the same final power as Simulink, within 0.01 points, in all 27 runs of DIRECT, Idea B and Idea C. The final power is the power at the hand-over duty plus 0.001. Example: Idea B on P0 hands over at 0.6057, where the peak is at 0.6036. The power is 99.93 % of the GMPP. One step to 0.6067 gives 99.84 %, and the tracker holds there.

Probe cost: on the nine patterns, Idea B used 105 probes and DIRECT 114, about one probe (40 ms) fewer for each search. On P3 and R3, Idea B used one probe more.

### 2.2 Idea C: midpoint split or corner split

Record of the first decision. The task definition of the code (section 4.5, step 2, a working file that is not in the repository) gave Idea C the midpoint split, with the corner split as an option that is off. `gmppt_review.md`, section 2, records this. The reasons in the project records are:

1. Idea C started as a midpoint bisection in the preliminary study (`docs/research/novelty_check_ideas_B_C.md`, section 2). The corner split came later, with Idea B refined (2026-11-08).
2. The rectangle ceiling V1 · I2 has no maximum inside the gap, so the midpoint is the neutral split (`docs/research/prior_art_reading_notes_B_C.md`).
3. The midpoint does not depend on the measurements. The corner split uses the measured V and I, so a measurement error moves the probes. In the Simulink runs of the preliminary study, this changed the order of two probes on R2 and R4, with the same probe count and hand-over (`docs/explainer/ideas.html`).
4. With the midpoint split, Idea C is the mixed monotonic programming algorithm of Matthiesen et al. (IEEE Trans. Signal Process. 68, 2020) in one dimension.

Against these reasons, the preliminary static study with 0.5 % sensor noise found the GMPP in 99.9 % of 900 cases with the corner split, against 99.7 % with the midpoint split (`docs/explainer/ideas.html`).

New data on the nine patterns (static):

| Split | Probes | Mean hand-over power | Lowest hand-over power |
|---|---|---|---|
| Midpoint (`c_corner` = 0) | 10 to 18, total 118 | 99.851 % | 99.443 % |
| Corner (`c_corner` = 1) | 8 to 15, total 93 | 99.911 % | 99.703 % |

The user approved `c_corner` = 1 on 2026-11-21. The novelty record must say that Idea C with the corner split uses the projection step of the polyblock algorithm (Tuy 2000), as Idea B refined does.

## 3. Sizes of PSO and GWO, by the worst case

The baseline used one seed of the random generator. With 3 particles, PSO reached the global peak on all nine patterns with that seed. Over 50 seeds, it did not. The test below runs 50 seeds on the nine patterns (450 searches for each setting). A wrong peak is a hand-over more than 10 V from the voltage of the GMPP.

| Search | Size x iterations | Store | Wrong peak | Lowest hand-over | Mean probes | Worst search time |
|---|---|---|---|---|---|---|
| PSO | 3 x 20 (paper size) | 64 | 10.67 % | 96.09 % | 38.0 | 2.40 s |
| PSO | 4 x 16 | 64 | 7.56 % | 95.89 % | 53.0 | 2.56 s |
| PSO | 5 x 12 | 64 | 1.33 % | 96.09 % | 59.0 | 2.40 s |
| PSO | 6 x 10 | 64 | 0.22 % | 95.88 % | 60.0 | 2.40 s |
| PSO | 7 x 9 | 64 | 7.33 % | 96.10 % | 63.0 | 2.52 s |
| **PSO** | **8 x 8** | 64 | **0 %** | 99.89 % | 64.0 | **2.56 s** |
| GWO | 3 x 10 | 64 | 5.56 % | 90.62 % | 30.0 | 1.20 s |
| GWO | 4 x 10 | 64 | 4.44 % | 89.68 % | 40.0 | 1.60 s |
| GWO | 5 x 10 | 64 | 1.33 % | 96.02 % | 50.0 | 2.00 s |
| **GWO** | **6 x 10** | 64 | **0 %** | 97.98 % | 60.0 | **2.40 s** |

Most misses of the 3-particle PSO occur on R1 (22 of 30 seeds in a first check) and P3 (8 of 30). The miss rate does not fall steadily with the size, because the start duties also change with the size.

The user approved "more wolves or particles as required" on 2026-11-21. The config now has PSO with 8 particles and 8 iterations, and GWO with 6 wolves and 10 iterations: the smallest sizes with no wrong peak in the 450 searches. Both fill the store of 64 samples. A larger store (128) did not remove a miss that the 64 store had.

Worst search time (the time that an industry test measures): DIRECT 15 probes (0.60 s), Idea B 16 (0.64 s), Idea C with the corner split 15 (0.60 s), PSO 64 (2.56 s), GWO 60 (2.40 s). DIRECT, Idea B and Idea C are deterministic, so one run gives their worst case on a pattern. PSO and GWO need many seeds. Each evaluation must give their miss rate and their worst case.

Limit: the test covers the nine patterns only. The 1800 random cases can need larger sizes.

## 4. Hold band of the VS-INC in Simulink

`experiments/run_gmppt_holdband.m` ran the five searches on the nine patterns with `eps_inc` = 0.30, 0.10, 0.05 and 0.02 (180 runs, 616 s on 16 workers). It used the values of sections 2 and 3. The times are from the start of the run (t = 0) and include the wait of 0.06 s.

- `tHand`: time of the hand-over.
- `t999`: time after which the power stays at 99.9 % of the GMPP or more.
- `tConv`: time after which the power stays within 0.02 points below its final value. If the tracker moves back and forth until the end of the run, `tConv` is near 4 s.
- "d" columns: difference from `eps_inc` = 0.30.

| Search | `eps_inc` | `tHand` mean / max [s] | `t999` mean / max [s] | `tConv` mean / max [s] | Final power mean / lowest | Runs below 99.9 % | Mean power over 4 s | d `tConv` mean [s] | d mean power over 4 s [points] |
|---|---|---|---|---|---|---|---|---|---|
| DIRECT | 0.30 | 0.57 / 0.66 | 0.550 / 0.662 | 0.56 / 0.68 | 99.985 / 99.934 | 0 | 96.42 | 0 | 0 |
| DIRECT | 0.10 | 0.57 / 0.66 | 0.550 / 0.662 | 0.57 / 0.68 | 99.992 / 99.974 | 0 | 96.43 | +0.004 | +0.006 |
| DIRECT | 0.05 | 0.57 / 0.66 | 0.574 / 0.882 | 0.93 / 3.98 | 99.993 / 99.979 | 0 | 96.43 | +0.371 | +0.006 |
| DIRECT | 0.02 | 0.57 / 0.66 | 0.574 / 0.882 | 1.30 / 3.98 | 99.994 / 99.979 | 0 | 96.43 | +0.742 | +0.007 |
| Idea B | 0.30 | 0.53 / 0.70 | 0.562 / 0.722 | 0.54 / 0.70 | 99.942 / 99.840 | 2 | 96.40 | 0 | 0 |
| Idea B | 0.10 | 0.53 / 0.70 | 0.553 / 0.762 | 0.92 / 3.98 | 99.989 / 99.962 | 0 | 96.44 | +0.386 | +0.040 |
| Idea B | 0.05 | 0.53 / 0.70 | 0.553 / 0.762 | 0.92 / 3.98 | 99.994 / 99.979 | 0 | 96.44 | +0.389 | +0.044 |
| Idea B | 0.02 | 0.53 / 0.70 | 0.553 / 0.762 | 1.69 / 3.98 | 99.993 / 99.979 | 0 | 96.44 | +1.157 | +0.043 |
| Idea C | 0.30 | 0.48 / 0.66 | 0.503 / 0.661 | 0.50 / 0.66 | 99.942 / 99.708 | 1 | 96.59 | 0 | 0 |
| Idea C | 0.10 | 0.48 / 0.66 | 0.498 / 0.661 | 0.52 / 0.70 | 99.989 / 99.972 | 0 | 96.63 | +0.015 | +0.041 |
| Idea C | 0.05 | 0.48 / 0.66 | 0.513 / 0.722 | 0.89 / 3.98 | 99.990 / 99.974 | 0 | 96.63 | +0.391 | +0.042 |
| Idea C | 0.02 | 0.48 / 0.66 | 0.513 / 0.722 | 1.28 / 3.98 | 99.991 / 99.974 | 0 | 96.63 | +0.775 | +0.043 |
| PSO | 0.30 | 2.62 / 2.62 | 2.624 / 2.627 | 2.63 / 2.64 | 99.973 / 99.933 | 0 | 87.85 | 0 | 0 |
| PSO | 0.10 | 2.62 / 2.62 | 2.631 / 2.682 | 2.78 / 3.98 | 99.984 / 99.967 | 0 | 87.85 | +0.153 | +0.004 |
| PSO | 0.05 | 2.62 / 2.62 | 2.631 / 2.682 | 2.79 / 3.98 | 99.989 / 99.979 | 0 | 87.85 | +0.158 | +0.005 |
| PSO | 0.02 | 2.62 / 2.62 | 2.631 / 2.682 | 2.94 / 3.98 | 99.994 / 99.979 | 0 | 87.86 | +0.309 | +0.007 |
| GWO | 0.30 | 2.46 / 2.46 | 2.488 / 2.579 | 2.50 / 2.58 | 99.750 / 99.034 | 3 | 76.74 | 0 | 0 |
| GWO | 0.10 | 2.46 / 2.46 | 2.510 / 2.579 | 2.53 / 2.60 | 99.945 / 99.578 | 1 | 76.81 | +0.031 | +0.071 |
| GWO | 0.05 | 2.46 / 2.46 | 2.510 / 2.579 | 2.53 / 2.62 | 99.945 / 99.578 | 1 | 76.81 | +0.035 | +0.071 |
| GWO | 0.02 | 2.46 / 2.46 | 2.598 / 3.301 | 3.01 / 4.00 | 99.991 / 99.976 | 0 | 76.83 | +0.511 | +0.086 |

`t999` for Ideas B and C on the runs with a lower final power counts only the runs that reach 99.9 %.

Findings:

1. A narrower band removes the shortfall of the final power. With 0.10, Ideas B and C end at 99.989 % mean, against 99.992 % for DIRECT. With 0.05 they end at 99.994 % and 99.990 %.
2. The time to 99.9 % does not become longer on the mean. The largest increase of its worst case is 0.22 s (DIRECT at 0.05).
3. The cost is that the tracker does not come to rest on the sharp peak of R1. With 0.05 or less, the VS-INC moves back and forth there until the end of the run (`tConv` near 4 s). The other patterns stop within about 0.1 s.
4. The energy gain over 4 s is small: 0.04 points for Ideas B and C, 0.07 to 0.09 points for GWO.
5. With 8 particles and 6 wolves, PSO and GWO give 87.9 % and 76.8 % of the GMPP energy over 4 s, against 94.1 % and 86.6 % with 3 in the baseline. This is the price of no wrong peak.
6. With 3 runs below 99.9 % at 0.30, GWO still shows the settling fault of the first local period after a large jump (`plans_after_baseline.md`, plan 2, item 3).

## 5. Proposal: a local stage that uses the samples of the search

### 5.1 Faults of the present local stages

| Fault | P&O | VS-INC |
|---|---|---|
| Moves around the peak at all times | yes, 4 V to 8 V | no |
| Holds away from the peak (hold band) | no | yes, up to 0.33 % |
| The first move does not know the side of the peak | yes | yes |
| The slope over a step across the peak looks flat (false hold) | no | yes (Idea C on R1) |
| A slow change of irradiance between two periods gives a wrong direction | yes | yes |
| Uses the samples that the search already has | no | no |
| Sensitive to a reading before the converter settles | yes | yes |

### 5.2 Proposed stage: bracketed parabolic step, then hold with a check

This stage is an implementation of published parts. It is not a new method.

1. **Bracket.** At the hand-over, the store of the search holds the best sample and its two neighbours on the duty axis. On a curve that does not change, the peak lies between the two neighbours.
2. **Parabolic step.** Fit a parabola through the three samples and probe its vertex, with the probe timing of the search (40 ms, last quarter). Keep the bracket. Repeat if the step is larger than 0.001 in duty, up to three probes. If the parabola is not concave or its vertex is outside the bracket, use a golden-section point in the larger part. This is the safeguarded parabolic interpolation of R. P. Brent, "Algorithms for Minimization without Derivatives," Prentice-Hall, 1973. Parabolic prediction of the peak for MPPT: W. Pai, R. Chao, S. H. Ko and T. Lee, IEEE Trans. Sustain. Energy, vol. 2, no. 1, pp. 60-68, 2011 (not read, abstract only).
3. **Hold.** Hold the duty. The restart test of `mppt_controller.m` continues at each period, because the duty does not change.
4. **Check (for slow changes).** At an interval, measure D0, D0 + d, D0, D0 - d, D0. Correct the two side powers by the mean of the centre powers before and after them, which removes a linear change of irradiance. Fit a parabola and move D0 to its vertex. The drift correction with an extra measurement is the idea of the dP-P&O of D. Sera, R. Teodorescu, J. Hantschel and M. Knoll, IEEE Trans. Ind. Electron., vol. 55, no. 7, pp. 2629-2637, 2008 (not read, abstract only).

Golden-section and quadratic-interpolation trackers are compared in E. Andrean, Y.-C. Chang and K.-L. Lian, Energies, 2018 (not read).

### 5.3 Static prototype

The prototype of steps 1 and 2 ran on the static plant from the hand-over of each search (`c_corner` = 1, 3 particles and 3 wolves). For the noise cases, each averaged power reading has a relative Gaussian error. The prototype ran 20 times for each pattern, and the VS-INC comparison uses `eps_inc` = 0.05.

| Noise | Search | Hand-over mean / lowest | Parabolic stage: end mean / lowest | Probes mean / max | VS-INC 0.05: end mean / lowest |
|---|---|---|---|---|---|
| 0 | DIRECT | 99.994 / 99.984 | 99.994 / 99.984 | 0 / 0 | 99.993 / 99.977 |
| 0 | Idea B | 99.963 / 99.893 | 99.997 / 99.988 | 0.56 / 1 | 99.993 / 99.977 |
| 0 | Idea C | 99.911 / 99.703 | 99.998 / 99.990 | 0.67 / 1 | 99.990 / 99.975 |
| 0 | GWO (3 wolves) | 98.681 / 95.325 | 99.747 / 97.822 | 1.56 / 3 | 99.741 / 97.747 |
| 0.05 % | Idea B | | 99.993 / 99.947 | 0.58 / 2 | 99.953 / 99.489 |
| 0.05 % | Idea C | | 99.994 / 99.837 | 0.64 / 2 | 99.960 / 99.779 |
| 0.2 % | DIRECT | | 99.977 / 99.722 | 0.63 / 3 | 99.825 / 98.730 |
| 0.2 % | Idea B | | 99.969 / 99.533 | 0.83 / 3 | 99.822 / 99.088 |
| 0.2 % | Idea C | | 99.968 / 99.703 | 0.90 / 3 | 99.820 / 98.884 |

With no noise, Ideas B and C end above the DIRECT hand-over after at most one probe (40 ms). With noise, the parabolic stage keeps more of the power than the VS-INC. A local stage cannot correct a wrong peak (GWO on R1).

Static times: the parabolic stage needs 0 to 3 probes of 40 ms. The VS-INC with 0.05 needs 15.6 periods of 20 ms on the mean (0.31 s) to stay within 0.01 points of its end value. With 0.30 it needs 1.6 periods, but it holds at a lower power.

### 5.4 What was built

The user approved the stage on 2026-11-21, for DIRECT, Idea B and Idea C only. PSO and GWO are not part of it: with 8 particles and 6 wolves their hand-over is already at the peak, and their search time dominates. Before the code was written, all five sources were read in full: Pai et al. 2011 (IEEE Xplore, NIT access), Brent 1973 (chapter 5, the scan of the author), Sera et al. 2008 (reprint in the thesis of D. Sera), Andrean et al. 2018 and Liu et al. 2008. `gmppt_methods.md`, section 7.5, gives the final description, the sources of each step and the differences from the sources. Two points came from the reading:

1. Andrean et al. show that interpolation trackers fail when the curve changes and old points are not measured again. The stage therefore measures the best duty again before it uses the stored samples (fresh reading), and the check measures three new points each time.
2. Andrean et al. show the "NQI trap" of the rule "drop the lowest point" of Pai et al. The stage keeps the points of the procedure localmin of Brent instead.

## 6. Results of the parabolic stage

### 6.1 Static closed loop

The controller ran on the static plant (one operating point for each duty, no converter dynamics), 4 s from start-up, nine patterns. Scratch script, not in the repository.

| Search | Local stage | Final power mean / lowest, no noise | Final power mean / lowest, noise 3 % on each control sample of V |
|---|---|---|---|
| DIRECT | VS-INC 0.30 | 99.985 / 99.934 | 99.785 / 99.099 |
| DIRECT | VS-INC 0.10 | 99.992 / 99.974 | 99.756 / 98.427 |
| DIRECT | Parabolic | 99.986 / 99.973 | 99.942 / 99.660 |
| Idea B | VS-INC 0.30 | 99.942 / 99.840 | 99.794 / 99.230 |
| Idea B | VS-INC 0.10 | 99.989 / 99.962 | 99.821 / 99.230 |
| Idea B | Parabolic | 99.989 / 99.972 | 99.958 / 99.854 |
| Idea C | VS-INC 0.30 | 99.942 / 99.711 | 99.811 / 99.407 |
| Idea C | VS-INC 0.10 | 99.989 / 99.971 | 99.823 / 99.083 |
| Idea C | Parabolic | 99.988 / 99.974 | 99.940 / 99.739 |

A static ramp (the current of P0 scaled from 0.3 to 1.0 at 3 % per s, 30 s) showed a fault of the VS-INC: after its hold, it moves only if the current changes by more than `eps_di` (0.5 %) in one period of 20 ms. The ramp changes the current by about 0.06 % in one period, so the VS-INC did not move, and its ramp efficiency was 54 %. The parabolic stage gave 99.97 % and the P&O 99.75 %. The restart test with `restart_ref` = 1 compares periods at most four periods apart, so it does not see a slow ramp either. Section 6.3 gives the Simulink ramp test.

### 6.2 Simulink: nine patterns and the restart sets

`experiments/run_gmppt_local3.m`, 93 runs, 655 s on 4 workers (peak RAM 10.1 GiB working set, page file 2.2 GB).

| Search | Local stage | Final power mean / lowest [%] | Mean power over 4 s [%] | Duty moves after the first 0.5 s of the local stage | V swing in the last 0.3 s [V] |
|---|---|---|---|---|---|
| DIRECT | VS-INC 0.30 | 99.985 / 99.934 | 96.420 | 0 | 0 |
| DIRECT | VS-INC 0.10 | 99.992 / 99.974 | 96.425 | 0 | 0 |
| DIRECT | Parabolic | 99.986 / 99.974 | 96.426 | 12.1 | 3.27 |
| Idea B | VS-INC 0.30 | 99.942 / 99.840 | 96.397 | 0 | 0 |
| Idea B | VS-INC 0.10 | 99.989 / 99.962 | 96.437 | 16.0 | 1.28 |
| Idea B | Parabolic | 99.989 / 99.973 | 96.442 | 11.6 | 3.27 |
| Idea C | VS-INC 0.30 | 99.942 / 99.708 | 96.588 | 0 | 0 |
| Idea C | VS-INC 0.10 | 99.989 / 99.972 | 96.629 | 0 | 0 |
| Idea C | Parabolic | 99.988 / 99.974 | 96.634 | 12.0 | 3.28 |

Findings:

1. With the parabolic stage, Ideas B and C end at the level of DIRECT: lowest final power 99.973 % and 99.974 %, against 99.840 % and 99.708 % with the VS-INC at 0.30. The mean power over 4 s is the highest of the three stages for each search.
2. With no noise, the VS-INC at 0.10 gives almost the same final power. The difference appears with noise (section 6.1) and on ramps (sections 6.1 and 6.3).
3. The duty moves and the V swing of the parabolic stage come from the check: each 1 s, two periods of 20 ms at D0 ± 0.002. On the sharp peak of R1 this costs about 0.2 % for 40 ms, about 0.007 % of the energy. For the same reason, the time after which the power stays at 99.9 % is not a useful measure for this stage: a check can dip below 99.9 % on R1.
4. Restart sets E, F and C: each change started exactly one search, 20 ms after the change. No other search started. The final power of each phase was 99.973 % to 100.000 %.
5. Set T (`T_rescan` = 1 s): the intervals between the searches were 1.56 s (DIRECT), 1.44 s (Idea B) and 1.36 s (Idea C): the search time plus 1 s, as in the baseline. The final values of set T are not valid, because the last search overlaps the last 0.3 s (as in the baseline).

### 6.3 Simulink: irradiance ramp

`experiments/run_gmppt_ramp.m`: the ramp of EN 50530:2010, Table B.2, row 4, as Andrean et al. (2018, section 3.4) describe it. 30 % to 100 % and back at 30 W/m² per s, 10 s at 100 %, 62.7 s in total. The whole pattern is scaled. Dynamic efficiency: the energy over the GMPP energy from t = 2 s (Andrean et al., Eq. (10)). The GMPP at each level comes from 30 sweeps of `PV4x4_sweep.slx`. 24 runs, 1876 s on 4 workers (peak RAM 9.5 GiB working set, 11.6 GiB committed).

| Pattern | Search | P&O | VS-INC, `restart_ref` 1 | VS-INC, `restart_ref` 2 (searches) | Parabolic |
|---|---|---|---|---|---|
| P0 | DIRECT | 99.768 | 56.245 | 96.152 (32) | **99.966** |
| P0 | Idea B | 99.771 | 56.118 | 96.269 (33) | **99.966** |
| P0 | Idea C | 99.775 | 57.195 | 96.051 (34) | **99.968** |
| R1 | DIRECT | 98.275 | 89.662 | 95.652 (31) | 98.488 |
| R1 | Idea B | 99.413 | 51.991 | 96.190 (31) | **99.916** |
| R1 | Idea C | 99.405 | 51.422 | 95.103 (28) | **99.918** |

Values in %. Each run with P&O, VS-INC `restart_ref` 1 and the parabolic stage made one search (at the start).

Findings:

1. **The VS-INC with the default restart test does not follow a ramp.** After its hold, it moves only if the current changes by more than `eps_di` (0.5 %) in one period of 20 ms. The ramp changes the current by less than this in each period, so the duty stays at the start value: 51 % to 57 % (90 % for DIRECT on R1). This is a fault of the baseline local stage (default `local` = 2, `restart_ref` = 1). It is not visible in the tests with constant patterns. Fixed on 2026-11-22: after a hold, the INC and the VS-INC now compare the current with the current of the first period of the hold. On the 30 W/m^2/s row of P0 (static bench), the efficiency is then 99.77 % for the VS-INC after DIRECT, 99.82 % for the INC after DIRECT and 99.77 % for the INC alone (before: 58.0 %, 59.4 % and 57.7 %).
2. With `restart_ref` = 2, the restart test compares with the power after the hand-over. The ramp then starts a new global search at each 5 % change: 28 to 34 searches, 95 % to 96 %.
3. The P&O follows the ramp (98.3 % to 99.8 %). Its swing around the peak costs about 0.2 % on P0 and more on R1.
4. The parabolic stage follows the ramp with one search: 99.966 % to 99.968 % on P0 and 99.916 % to 99.918 % after Ideas B and C on R1. During the ramps, the check runs at once after each check (the centre power drifts by more than `chk_ramp`).
5. DIRECT on R1 gives 98.5 % with the parabolic stage and 98.3 % with the P&O. In the dwell at 100 %, both are at 97.6 % to 97.8 %. At the end (30 %), both are at 99.7 % to 99.9 %. The reading of the data: at 30 %, DIRECT handed over on a peak that is within 0.2 % of the GMPP. At 100 %, another peak is the global peak, and a local stage does not change peaks. Ideas B and C handed over on the other peak. This reading is not yet checked with the peak voltages. In a real system, the timer restart (`T_rescan`) covers a change of the global peak at a constant shade.

### 6.4 Checks after the change of the controller

- `p.alg` = 1 and 2 against `results/mppt_results.mat` (24 runs of the mid-review): largest difference of the final power 0.000001 %.
- `p.alg` = 3 to 5 with `p.local` = 2 and `eps_inc` = 0.30 against `results/gmppt_holdband.mat` (27 runs, made before the change): no difference of the final power.
- `coder.screener`: no message and no unsupported call for `mppt_controller.m`, `gmppt_search.m`, `gmppt_direct.m`, `gmppt_ideab.m`, `gmppt_ideac.m` and `gmppt_ceiling.m`. `checkcode` gives no message for `mppt_controller.m`.

### 6.5 Open points

1. Done on 2026-11-21: the user made the parabolic stage the default for DIRECT, Idea B and Idea C (`local` = [2 2 3 3 3 2 2 2]). The results of `gmppt_baseline_2026-11-21.md` used the variable-step INC and stay a record of that setting.
2. The values `chk_T`, `chk_d`, `chk_db`, `chk_ramp`, `par_*` are start values, not tuned.
3. The fault of finding 1 of section 6.3 also affects the baseline of `gmppt_baseline_2026-11-21.md` for slow changes. The 1800 random cases are constant patterns and do not show it.
4. PSO and GWO were not run with the parabolic stage (decision of the user).
