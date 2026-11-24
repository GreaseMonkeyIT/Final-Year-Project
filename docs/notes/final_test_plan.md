---
title: Final test plan
date: 2026-11-21
status: approved by the user on 2026-11-21. Started on 2026-11-21 at about 20:00 at the request of the user. Phase 0: final_bench_2026-11-21.md. First full run on 2026-11-22 (results archived), controller faults fixed on 2026-11-22 (section 14), second full run started on 2026-11-22.
---

# Final test plan

The findings of the project come from these runs. The plan has a test bench (phase 0) and five test phases. Phase 6 (real-time) comes later.

## 1. Principle: equal ground

- **Global comparison.** All five searches (DIRECT, Idea B refined, Idea C with the corner split, PSO with 8 particles, GWO with 6 wolves) hand over to the same local stage: the parabolic stage (`mppt.local = 3`). A difference between two searches then comes from the search. PSO and GWO run with many seeds. The report gives their rate of wrong peaks and their worst case.
- **Local comparison.** Four local stages start from the same hand-over: P&O, INC (the INC of the mid-review), the variable-step INC of Liu et al. (2008) and the parabolic stage.
- **Single-peak references.** P&O and INC from start-up, with no global search, as in the mid-review.

## 2. Decisions of the user (2026-11-21)

| Item | Decision |
|---|---|
| Controller board | TI F28379D (in the lab) |
| Sensors | Typical parts, recorded as assumptions |
| Temperature | Add the cell temperature to the models |
| Local stage of the global comparison | The parabolic stage for all five searches |
| Local comparison | The local stages against one another, from the same hand-over |
| Mid-review tests | Part of phase 1 (sets A, B and C of `run_po_demo.m`) |
| Simulink subset of phase 1 | About 100 cases |
| Run time | Overnight. The user gives the start |

## 3. Phase 0: test bench

Each step has a pass gate. If a gate fails, the run stops at that step and the report says so.

| Step | Work | Pass gate |
|---|---|---|
| 0.1 | Temperature. The temperature parameters of the Simscape cell are fitted to the datasheet coefficients of the Emmvee E325P72 (Voc -0.34 %/K, Isc +0.05 %/K, Pmax -0.40 %/K). The cell temperature is a model variable for each run. The build scripts make the change. | Sweeps at 25, 45 and 65 °C agree with the datasheet coefficients within about 10 % of each coefficient |
| 0.2 | Sensor and ADC block, with an on/off switch. ADC of the F28379D from its datasheet (SPRS880, 12-bit single-ended mode). Sensors: gain error, offset, noise and bandwidth. 12-bit quantization over the real input ranges. One sample each 50 µs. | The output statistics agree with the datasheet values |
| 0.3 | Fast static array model for any irradiance on each bypass group and any temperature, with the cell equation of Simscape. It gives the reference GMPP at each time and runs the static tests. | GMPP within 0.2 % of the Simscape sweeps on the nine patterns at 3 temperatures and 3 irradiance levels |
| 0.4 | Irradiance sources: the nine patterns, the 1800 random cases, the EN 50530 ramps, cloud edges from the Oahu fit on the group model (`MPPT_4x4_grp.slx`), and an EPW day with cloud events | Each profile is plotted and checked |
| 0.5 | Metrics: dynamic efficiency (Andrean et al. 2018, Eq. (10)), worst search time, rate of wrong peaks, number of searches, energy loss split into search, tracking and wrong-peak loss | Unit test on known traces |
| 0.6 | Regression: with noise off and 25 °C, the bench gives the results of today | Same final power as `results/gmppt_local3.mat` and `results/mppt_results.mat` |

### 3.1 Oahu data

- Source: Oahu Solar Measurement Grid, now at https://midcdmz.nlr.gov/apps/sitehome.pl?site=OAHUGRID (NREL was renamed National Laboratory of the Rockies in December 2025, and the old nrel.gov addresses do not resolve). 17 LI-200 GHI sensors with known positions, 1 s samples, March 2010 to October 2011, 20 monthly zip files of about 65 MB. A download was tested on 2026-11-21.
- Plan: download 3 to 4 months of different cloud seasons (about 250 MB, not in git). Read the published studies that use this grid for cloud motion. Fit the distributions of cloud speed and direction, shade depth (clear-sky index), ramp rate and cloud enhancement.
- The sensors are about 100 m apart and the array is about 8 m x 4 m. The data therefore gives statistics, not the irradiance of each panel. A moving-edge model (speed, direction, edge width, depth) gives the irradiance of each bypass group.

### 3.2 Sensors (assumptions)

- Voltage: resistive divider and isolation amplifier of the AMC1311 type.
- Current: closed-loop Hall sensor of the LEM LA 55-P type.
- The values come from the datasheets of these parts. The report marks them as assumptions.

## 4. Phase 1: static shading

| Block | Method | Size |
|---|---|---|
| 1a | Mid-review reference: P&O and INC from start-up, sets A, B and C, in Simulink on the new bench | About 24 runs, noise on |
| 1b | Global, broad: the 1800 random cases and the nine patterns on the static array model. Five searches, PSO and GWO with 30 seeds. Noise off and on. 25 °C and 55 °C | Static model only. It gives the probes and the hand-over exactly |
| 1c | Global in Simulink: a stratified subset of about 100 cases, five searches with the parabolic stage, noise on | About 500 runs of 4 s |
| 1d | Local: the nine patterns and 20 cases of the subset, four local stages after one search, noise off and on | Simulink |

## 5. Phase 2: standard dynamic tests

- EN 50530 ramps with several slopes, on P0 and R1.
- Global comparison (five searches, parabolic stage) and local comparison (four stages).
- Noise on. 25 °C, and one repeat at 45 °C.
- Only row 4 of Table B.2 is known now (from Andrean et al. 2018). The other rows need the standard (NIT library) or secondary sources, which the report marks.

## 6. Phase 3: cloud events

- About 40 cloud-edge events from the Oahu fit, windows of about 10 s, on the group model, noise on.
- Global and local comparisons.
- Values: energy loss for each event, searches, missed and false restarts.

## 7. Phase 4: full days (quasi-static)

- EPW days for the area of NIT Andhra Pradesh, cell temperature from the NOCT model, cloud events from the Oahu fit.
- The static array model with one controller decision for each MPPT period.
- Values: energy of each day, number of searches, study of `T_rescan`.

## 8. Phase 5: sensitivity

- Noise level, ADC resolution, sensor gain error, temperature.
- Parameters of the parabolic stage (`chk_*`, `par_*`) and of the ceiling check (`eps_c`, `tau`).
- The report gives the worst cases.

## 9. Phase 6 (later)

Real-time run on the OPAL-RT OP5707, then controller hardware-in-the-loop with the F28379D (`plans_after_baseline.md`, plan 4).

## 10. Budget and order

4 workers (`experiments/sim_pool.m`, RAM about 10 to 12 GiB), 1.25 s to 1.56 s of wall time for each simulated second (measured on 2026-11-21).

| Item | Simulated time |
|---|---|
| Phase 0: sweeps and regression | about 300 s |
| Phase 1: 1a, 1c, 1d | about 2500 s |
| Phase 2 | about 4000 s |
| Phase 3 | about 3600 s |
| Phases 1b, 4, 5 | static model, CPU time only |
| Total | about 10000 to 11000 s, 4 to 5 h of runs |

The work of phase 0 comes before the runs. Order: phase 0, 1, 2, 3, 4, 5. If the night is too short, the report says what ran and what did not. Each phase reports its run time and its peak RAM.

## 11. Changes when the work starts

1. `local` becomes 3 for all five searches (now 2 for PSO and GWO). The config comment and the notes record the old value, the new value and the reason.
2. A new local stage `local = 4`: the INC of the mid-review, from the code of `p.alg = 2`.
3. Temperature parameters in the config and in the build scripts. `MPPT_4x4.slx` and `MPPT_4x4_grp.slx` are made again with the build scripts.
4. The sensor and ADC block in the build script, off by default.
5. New run scripts and notes. README and the notes are updated in the same pass. Nothing is committed.

## 12. Open items (closed on 2026-11-21)

1. EN 50530: the rows of both ramp sequences come from a TÜV Rheinland test report that lists them (report CN21VE2D 001, EN 50530:2010+A1:2013). The standard itself is still not at hand. The report marks the source.
2. Oahu months: 2010-07, 2010-10, 2011-01 and 2011-04 (default of the plan: four seasons).
3. Start: the evening of 2026-11-21, at the request of the user.

## 13. Changes to the plan during the work (2026-11-21)

- Phases 1b, 4 and 5 and part A of phase 2 run on a compiled static closed loop (`src/plant/static_run.m`), which gives the Simulink results within 0.001 points on the nine patterns. Phase 2 can thus run the full EN 50530 sequences (about 23,000 s each), and Simulink runs a short part of the 30 % to 100 % sequence.
- Phase 3: each cloud event has its own window of 10 s to 40 s, because the median edge (36 m at 12 m/s) needs about 7 s to cross the array.
- Phase 4: the days come from the TMYx file of Gannavaram (Vijayawada airport, about 75 km from the institute).
- Order of the night: the static phases first (Oahu fit, 1b, 5, 4), then the Simulink phases (1a, 1c, 1d, 2, 3). `experiments/run_final_all.sh` runs them.

## 14. Changes after the first full run (2026-11-22)

The first full run (2026-11-22, 01:40 to 07:34) and an audit of the controller found faults. The user approved each fix. The results of the first run are in `results/archive_2026-11-22_first_run/`. All phases run again with the fixed code.

Fixes of the controller (`mppt_controller.m`, `gmppt_init.m`, `gmppt_pso.m`, `gmppt_gwo.m`):

1. INC and VS-INC after a hold compare the current with the current of the first hold period, not of the last period. Before, a slow ramp never ended the hold, and the duty stayed fixed (57 % to 59 % on the 30 W/m2/s row of EN 50530; 99.8 % after the fix).
2. INC after a hold: more current moves the duty up (before: down). At a fixed duty, more light moves the operating point above the peak voltage.
3. PSO and GWO: the random generator starts from `rng_seed` once in each run. Before, each restart started it again, so each restart used the same numbers.
4. P&O and INC from start-up take their first step at the end of period `Nwait`, as the searches take their first probe (before: one period later).
5. Restart rule: level test in steady state, voltage hold of the parabolic stage, timer (`gmppt_methods.md`, section 8.1).
6. Comments that did not agree with the code (`gmppt_ideac.m`, `gmppt_pso.m`, the header of `mppt_controller.m`).
7. Found in the quick runs and in section 1 of the second run: the steady condition must hold for `st_N` periods in a row for all local stages (one pair of periods let noise through), and P_ref is taken at the first steady state after the hand-over (below about 60 W/m2 the local stage climbs below `Dlo` after each search, and a P_ref taken at once started a search about every second). The results of section 1 before this fix are in `results/archive_2026-11-22_before_pref_fix/`.
8. `run_final_compute.m`: the first version subtracted a pass with `p.alg = 0`, which runs other code, and gave negative times. It now times each decision call and subtracts the cost of the timer.

Changes of the tests:

- Phase 1d runs all five searches with each of the four local stages (before: DIRECT only), with the sensors on only (the first run gave the same values with the sensors off and on, within 0.03 points).
- Phase 3: the recovery time (from the end of the change of light to 99 % of the GMPP) replaces the values "moved", "missed" and "false". The first run found no moved global peak in the 40 events, so those values gave no information.
- New phase "p3n" (`experiments/run_final_p3n.m`, static bench, added at the request of the user): the restart rule under sensor noise of 1, 3, 10 and 30 times the values of `pv4x4_config.m`, on the 40 cloud events and on 100 pattern steps that move the global peak. Phase 5 showed that heavy noise breaks the steady condition, so no search starts. On uniform ramps this looks like a gain. The pattern steps measure the cost.
- 2026-11-23, after the second run (approved by the user): the steady condition is now a slope fitted over the last `st_win` = 10 periods in place of `st_N` = 5 periods in a row, because sensor noise blocked the old test (phase p3n, `gmppt_methods.md`, section 8.1). The phases with restarts (p2, p3, p3n, p4, p5) must run again with this rule. The final comparison is Idea C + parabolic against DIRECT, PSO and GWO (choice of the user, 2026-11-23).
- New phase "compute" (`experiments/run_final_compute.m`): the execution time of the controller in compiled code and an estimate of its compute energy on this PC.
- Order: p1b, p5, p4, compute, then p1a, p1c, p1d, p2, p3 on 3 workers (the Oahu fit did not change). The user asked for sections: section 1 (p1b, p5, compute, p1a) on 2026-11-22 at midday, the night section (p4, p3n, p1c, p1d, p2, p3) when the user starts it.

- 2026-11-24 (approved by the user): a power floor for the level test (`P_floor` = 260 W, 5 % of the rated power). On the four days of phase 4, the slope fit started 8413 searches, most of them at dawn and dusk, with 99.779 % for Idea C. With the floor: 521 searches and 99.968 %, with no change on the needed pattern steps (`gmppt_methods.md`, section 8.1). The phases with restarts run again (`bash run.sh rerun`).
- 2026-11-24: the Simscape solver stopped in 4 of 320 runs of phase 3 in the second run (all GWO + parabolic, "Transient initialization ... failed to converge", a few ms after a large duty jump of the search). A first-order filter on the duty input did not remove the fault. The solver daessc, or a maximum step of 2e-5 s, removed it in all three runs that were checked, but each makes a run 1.4 to 2.5 times slower. `experiments/bench_sim.m` now runs a failed run once more with daessc. On five runs that do not fail, daessc and ode23t gave the same efficiency within 0.002 points, except one run of event 17 (Idea C, 0.22 points).
- 2026-11-24, diagnosis of the difference between Simulink and the static bench for the parabolic stage (phase 3, second run: 98.7 % against 99.0 %). The difference comes from 4 of the 40 events (17, 27, 10, 38), all slow and deep cloud edges. The median difference is 0.02 points. On these edges, a check of the parabolic stage can end with its move at the limit, and the next check follows at once. The hold between two checks then has only one period, so the voltage hold does not act, and the duty follows the moving peak only by the steps of the checks. In Simulink, the power of a check period has an error of about 0.2 % that depends on the direction of the last duty step (the plant has not settled at the end of a 20 ms period). The power differences of a check near the peak are 0.01 % to 0.2 %, so the fit often has no maximum, and the check moves one step d in place of 2 d. Two changes were tested and not used: a voltage hold set at the end of a check at its limit (Simulink +0.5 to +1.3 points on the four events, static bench -0.15 points on the mean of Idea C), and the probe timing for the check periods (Simulink -3 to -7.5 points on three of the four events).
- 2026-11-23, evening: the MathWorks service host used 14 cores from 15:30 to 18:24, and MATLAB stopped at the start or at "Job Queued" of the pool. After the user stopped the service host, MATLAB started in 13 s and a pool of 3 workers in 11 s. Two changes make the night run safe against a repeat. `experiments/sim_pool.m` deletes the old jobs of the 'Processes' profile and tries the pool start three times. All the phase scripts now open their pool through `sim_pool`. `experiments/run_final_all.sh` starts MATLAB once with a limit of 300 s before each phase (three tries), writes the CPU use of the service host to `results/final_runs.txt`, and stops the chain between two phases if `results/STOP` exists.
