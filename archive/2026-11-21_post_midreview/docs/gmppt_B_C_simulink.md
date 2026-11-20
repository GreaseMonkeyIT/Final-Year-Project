---
title: DIRECT, Idea B and Idea C in the Simulink model of the 4 x 4 array
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-10-22
status: results (Simulink, averaged converter)
---

# DIRECT, Idea B and Idea C in the Simulink model

## 1. Summary

- Update of 2026-11-08: the controller also runs DIRECT as written in Nguyen and Low (`mppt.alg = 6`), PSO after Ishaque et al. 2012 (`7`) and Idea B refined (`8`). `run_gmppt_compare.m` runs them in this model. The results and the theory are in `Notes/idea_B_theory_and_baselines.md`, section 6.3. The DIRECT of `mppt.alg = 3` is a simplified form of the paper (same note, section 5.1).
- The controller `mppt_controller.m` now runs three global searches: DIRECT (`mppt.alg = 3`, a simplified form of Nguyen and Low 2010), Idea B (`4`, DIRECT with the ceiling check) and Idea C (`5`, halving search with the ceiling). After the search, the P&O of `mppt.alg = 1` takes over. The search code is in `gmppt_search.m`. It uses only fixed-size arrays, so Simulink Coder accepts it. Check of 2026-10-23: `coder.screener` reports no issue, and all modes build with dynamic memory allocation off (`Notes/pv4x4_shading_and_po.md`, section 9).
- A search probe lasts 40 ms, and the controller averages its last 10 ms. With the 20 ms timing of P&O, a large duty jump gives an error of up to 4.4 % in the probe power. With 40 ms, the worst error is 0.21 % (`Notes/pv4x4_shading_and_po.md`, section 5.1).
- The MATLAB port gives the same duty at every probe as `crosscheck/algos.py` on all 27 runs (3 methods, 9 patterns).
- In Simulink, all 27 runs apply the same duty sequence as the static check with the converter of the model. The measured power of every probe is within 0.24 % of the static value.
- From start-up, Ideas B and C reach the global peak on all nine patterns (99.4 to 99.8 %). DIRECT stops on the lower of the two close peaks of R1 (97.5 %). P&O stops on a local peak in P1, P3 and R1 (34.9 to 95.9 %). The searches hand over after 0.42 to 0.78 s (section 6).
- The probe counts are within 2 of the static cross-check, and the final powers within 0.3 %. The mean power in the first second is 81 to 89 %, not 93 to 97 %. The 40 ms probe and the 60 ms start-up wait explain all of this difference.
- A restart on a power change of 5 % starts one new search after each change of the shading, and never in a static run (largest change 1.55 %). It helps in one of four changes tested, by 1.8 to 1.9 % of the GMPP. Each restart costs about 0.06 to 0.12 s of energy at the GMPP, which a better peak repays in 2.5 to 5 s (section 7).
- With shading of single bypass groups, B and C reach the global peak on all three test patterns. DIRECT misses on two of them (95.5 and 91.6 %), and P&O on all three (section 8).

## 2. Files and how to run

| File | Purpose |
|---|---|
| `gmppt_search.m` | One step of DIRECT, Idea B or Idea C: takes the averages of the last probe, gives the next probe duty or the hand-over duty |
| `gmppt_init.m` | Empty state of the search (fixed-size arrays) |
| `mppt_controller.m` | Calls `gmppt_search` for `mppt.alg = 3, 4, 5`, then runs P&O. Outputs the phase `ph` and the probe count `np` for logging |
| `pv4x4_config.m` | New fields: `Tsearch`, `Nper_s`, `Navg_s`, `Dlo`, `Dhi`, `dcr`, `psc_i`, `psc_v`, `skip_lo`, `skip_hi`, `Voc_arr`, `Isc_arr`, `eps_b`, `tol_b`, the restart fields `dP_restart`, `T_rescan`, and the replay fields `Nmax`, `Drep`, `Nrep`, `Nhold` |
| `scripts/build_mppt_4x4.m` | The block "MPPT" has two more outputs (`ph`, `np`), logged every `Tlog`. Now a function: with the argument true it makes `MPPT_4x4_grp.slx` (section 8) |
| `scripts/build_pv4x4_sweep.m`, `scripts/add_pv_array.m` | Now with a group mode: one irradiance for each bypass group (section 8). The panel mode makes the same blocks as before |
| `pv_static_point.m` | Static operating point for an input resistance (same method as `Plant.at_duty` in `crosscheck/algos.py`) |
| `run_settling_check.m` | Task T1: settling of the search probes |
| `gmppt_static_check.m` | Task T2: the search on the static curves, against Python |
| `check_gmppt_controller.m` | Task T3: the search in Simulink, against the static check |
| `run_gmppt_demo.m` | Task T4: P&O, DIRECT, B and C in Simulink, sets A, B and C |
| `run_gmppt_restart.m` | Task T5: false-restart margin, sets C and E with the restart on and off, timer test |
| `gmppt_static_run.m` | One search on a static plant, then P&O. `gmppt_static_check.m` and `run_gmppt_group.m` use it |
| `shading_patterns_grp.m` | Task T6: three patterns of single bypass groups (12 x 4) |
| `run_gmppt_group.m` | Task T6: sweeps, static prediction and Simulink runs with the `_grp` models |
| `plots/plot_settling.m`, `plot_gmppt_summary.m`, `plot_gmppt_time.m`, `plot_gmppt_schedule.m`, `plot_grp_curves.m` | Figures of the scripts above |
| `crosscheck/run_simulink_curves.py` | DIRECT, B and C of `algos.py` on the Simulink curves, with the log of every probe |

Order of the runs:

1. In `crosscheck/`, run `python run_simulink_curves.py`.
2. In MATLAB, in the project folder, run `run scripts/build_mppt_4x4`. Close `MPPT_4x4.slx` without saving first.
3. Run `run_settling_check`, `gmppt_static_check`, `check_gmppt_controller`, `run_gmppt_demo` and `run_gmppt_restart`, in this order.
4. For section 8: run `addpath scripts`, then `build_pv4x4_sweep(true)` and `build_mppt_4x4(true)`, then `run_gmppt_group`.

## 3. Timing of a search probe

| Item | Value | Reason |
|---|---|---|
| Search probe | `mppt.Tsearch` = 40 ms | A large duty jump starts a ringing of L and C_in at about 670 Hz. It decays with a time constant of about 6 ms. |
| Averaging window | last 10 ms of the probe (`mppt.Navg_s` = 200 samples) | Worst probe error 0.21 % against the settled value, over 62 search probes |
| P&O period after the hand-over | 20 ms, average over the last 10 ms | Steps of 0.005 settle to 0.08 % |
| Start of the search | end of the wait (`mppt.Nwait` = 3 periods, 60 ms) | The first probe starts at 60 ms |

The hand-over period uses the P&O timing. Its jump from the last probe to the hand-over duty can be large. The first P&O decision is a perturbation only, so this period does not change a P&O decision. Its average also sets P_ref of the restart rule (section 7). In the static runs, no restart starts, so an error in P_ref has not caused a false restart.

## 4. MATLAB port against Python (task T2)

`gmppt_static_check.m` runs `gmppt_search.m` on a static plant. The plant takes the curves of `results/pv4x4_sweeps.mat` and the ideal converter map of `algos.py`. After the hand-over, 60 steps of P&O follow, as in `algos.po_local`. The script compares each run with the log of `algos.py` on the same curves (`crosscheck/simulink_curves_runs.json`).

Result: 27 of 27 runs are the same. The duty of every probe is the same (largest difference 0). The probe counts, the hand-over duties and the final powers are the same.

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| DIRECT | 9 / 99.7 | 11 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.5 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 |
| Idea B | 11 / 99.7 | 13 / 99.7 | 11 / 99.8 | 17 / 99.8 | 16 / 99.5 | 12 / 99.8 | 13 / 99.8 | 12 / 99.8 | 12 / 99.7 |
| Idea C | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 18 / 99.8 | 16 / 99.3 | 14 / 99.7 | 16 / 99.8 | 11 / 99.8 | 12 / 99.7 |

Cells: search probes / final % of the GMPP, on the Simulink curves. These numbers differ from section 6.1 of `HANDOFF_ideas_B_C.md` in two cells: Idea B on P1 needs 13 probes (12 on the numpy curves of `crosscheck/pvarray.py`), and DIRECT on R1 reaches 97.5 % (97.2 %). Python gives the same two values on the Simulink curves. The difference comes from the curves (less than 1.75 % of the GMPP apart), not from the port.

### 4.1 The converter map of the Simulink model

The settled points of `MPPT_4x4.slx` follow R_in = (R (1 - D)^2 + RL) / D^2, with the inductor resistance RL = 10 mOhm. The ideal map of `algos.py` leaves out RL. The power at a given duty then differs by -0.55 % to +2.07 % (`Notes/pv4x4_shading_and_po.md`, section 5.1). `gmppt_static_check.m` therefore also runs the static plant with the RL map. With this map, 13 of the 27 searches use a different order of probes, because the ceilings of close gaps change. The probe counts change by at most 2:

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| DIRECT | 9 / 99.8 | 11 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.6 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 | 9 / 99.7 |
| Idea B | 11 / 99.8 | 14 / 99.7 | 11 / 99.8 | 17 / 99.8 | 14 / 99.5 | 12 / 99.8 | 13 / 99.8 | 13 / 99.7 | 11 / 99.7 |
| Idea C | 11 / 99.8 | 10 / 99.7 | 10 / 99.7 | 18 / 99.8 | 17 / 99.4 | 14 / 99.7 | 16 / 99.8 | 11 / 99.7 | 11 / 99.7 |

## 5. The controller in Simulink against the static check (task T3)

`check_gmppt_controller.m` runs `mppt.alg = 3, 4, 5` in `MPPT_4x4.slx` on each pattern, from start-up, with no change of the shading. It reads the duty of each search probe from the logs `ph` and `np`.

| Check | Result |
|---|---|
| Same duty sequence as the static plant with the RL map | 27 of 27 runs |
| Same duty sequence as the static plant of `algos.py` (ideal map) | 14 of 27 runs. The other 13 differ from probe 7 or later, when two samples are close in power. |
| Largest error of a measured probe power against the static point | 0.24 % |

So the controller does in Simulink what the static check predicts. Each difference from Python comes from the converter loss RL, not from the code.

## 6. Simulink results (task T4)

`run_gmppt_demo.m` runs P&O (`mppt.alg = 1`), DIRECT (3), Idea B (4) and Idea C (5) on the sets of `run_po_demo.m`: A (start-up, 9 patterns, 2.5 s), B (P1 and P3 from another start duty) and C (winter morning). The runs use the restart rule of section 7 (`mppt.dP_restart` = 0.05). In sets A and B the restart never starts (section 7.2), so these results are the same as with no restart. The final run of 2026-10-23 gave the same values for sets A and B as the first run of 2026-10-22, which had no restart. The results are in `results/gmppt_results.csv` and `.mat`. Run time: 20 min for 48 runs.

### 6.1 Set A: from start-up

Cells: search probes / final power (% of the GMPP) / time to 98 % of the final power.

| Pattern | P&O | DIRECT | Idea B | Idea C |
|---|---|---|---|---|
| P0 | 0 / 99.8 / 1.24 s | 9 / 99.7 / 0.42 s | 11 / 99.7 / 0.50 s | 11 / 99.8 / 0.46 s |
| P1 | 0 / **46.6** / local | 11 / 99.7 / 0.50 s | 14 / 99.7 / 0.62 s | 10 / 99.7 / 0.46 s |
| P2 | 0 / 99.8 / 1.14 s | 9 / 99.8 / 0.34 s | 11 / 99.8 / 0.47 s | 10 / 99.8 / 0.46 s |
| P3 | 0 / **95.9** / local | 11 / 99.8 / 0.42 s | 17 / 99.8 / 0.74 s | 18 / 99.8 / 0.78 s |
| R1 | 0 / **34.9** / local | 9 / **97.5** / local | 14 / 99.4 / 0.56 s | 17 / 99.4 / 0.75 s |
| R2 | 0 / 99.8 / 0.96 s | 9 / 99.8 / 0.39 s | 12 / 99.8 / 0.54 s | 14 / 99.7 / 0.62 s |
| R3 | 0 / 99.8 / 0.98 s | 9 / 99.8 / 0.34 s | 13 / 99.8 / 0.59 s | 16 / 99.8 / 0.71 s |
| R4 | 0 / 99.8 / 1.18 s | 9 / 99.7 / 0.38 s | 13 / 99.7 / 0.58 s | 11 / 99.8 / 0.46 s |
| R5 | 0 / 99.8 / 1.06 s | 9 / 99.7 / 0.30 s | 11 / 99.7 / 0.47 s | 11 / 99.7 / 0.46 s |
| Mean power in the first 1 s | 33 to 58 % | 83 to 89 % | 82 to 88 % | 81 to 85 % |

"local": the tracker stops on a local peak. The time to 98 % is then not useful, so the table does not give it.

What the table shows:

1. P&O stops on a local peak in P1, P3 and R1, as before. DIRECT stops on the lower of the two close peaks of R1 (2499 W at 72 V, against 2563 W at 119 V). Ideas B and C reach the global peak in all nine patterns.
2. The global searches also reach the peak sooner on the single-peak patterns. P&O from the start duty 0.30 needs 0.96 to 1.24 s, because it climbs from near Voc with steps of 0.005. The searches hand over after 0.42 to 0.78 s.
3. A search probe costs 40 ms. Idea B costs 2 to 6 probes (80 to 240 ms) more than DIRECT. Idea C costs 1 probe less to 8 probes more than DIRECT.
4. After the hand-over, the P&O swing is 4 to 8 V, as for plain P&O.

Set B gives the same probes and the same results as set A for DIRECT, B and C. Before the search starts, the start duty only sets the operating point during the 60 ms wait. For P&O the start duty decides the peak (P1 from 0.66: 99.7 %, P3 from 0.75: 48.2 %).

### 6.2 Set C: winter morning

Power at the end of each phase, % of the GMPP of the phase. Restart on (`run_gmppt_demo.m`) / restart off (`run_gmppt_restart.m`):

| Phase | P&O | DIRECT | Idea B | Idea C |
|---|---|---|---|---|
| 0 to 1.2 s, R1 | 34.9 % | 97.5 / 97.5 % | 99.5 / 99.5 % | 99.3 / 99.3 % |
| 1.2 to 2.4 s, P1 | 46.6 % | 99.7 / 99.8 % | 99.7 / 99.8 % | 99.8 / 99.8 % |
| 2.4 to 3.6 s, P0 | 99.7 % | 99.7 / 99.8 % | 99.8 / 99.8 % | 99.7 / 99.7 % |

With no restart, the global trackers search only once, at start-up. They still reach the global peak in the P1 and P0 phases. In this set, each new global peak lies on the hill where the tracker already is, so P&O climbs to it. DIRECT climbs from 72 V (R1) to 111 V (P1). So set C cannot show that a restart is necessary. Section 7 adds a set where it is necessary. With the restart on, each change starts a new search, and the end power differs by at most 0.1 %.

### 6.3 Comparison with the static results

The handoff asks for an explanation of each difference larger than 1 % or 2 probes.

| Quantity | Static (`algos.py`, numpy curves) | Simulink | Difference and cause |
|---|---|---|---|
| Search probes | Section 6.1 of `HANDOFF_ideas_B_C.md` | Section 6.1 above | At most 2 probes (Idea B: P1 +2, R1 -2, R4 +1, R5 -1. Idea C: P2 -1, R1 +1, R5 -1). The Simulink sequences are the same as the static plant with the RL map (section 5). The causes are the converter loss RL and the curve model. |
| Final power | Section 6.1 of the handoff | Section 6.1 above | At most 0.3 % (DIRECT R1: 97.2 % against 97.5 %). |
| Mean power in the first 1 s | 93.7 to 97.0 % (DIRECT), 93.5 to 96.3 % (B), 92.6 to 95.2 % (C), on the Simulink curves | 82.8 to 89.2 % (DIRECT), 82.3 to 87.9 % (B), 80.8 to 85.5 % (C) | 8 to 12 %. The static harness counts 20 ms for each probe and no wait. The Simulink controller waits 60 ms at duty 0.30 and gives each search probe 40 ms. With this timing, the static probe log gives 82.6 to 89.3 % (DIRECT), 82.2 to 88.1 % (B) and 80.5 to 85.5 % (C). This is within 0.5 % of Simulink, so the timing explains the difference. |

The 40 ms probe is the price of a valid ceiling. A converter with more damping on C_in, or a probe that ends when the voltage has settled, would make the search cheaper. This project does not test either.

Figures (section 6): `results/fig_gmppt_summary.png` (final power, search probes and time to 98 %, set A), `results/fig_gmppt_time.png` (power against time for P1, P3 and R1. DIRECT and Idea B share their first 9 probes, so the DIRECT line is under the Idea B line until DIRECT hands over), `results/fig_direct_morning.png`, `fig_ideab_morning.png`, `fig_ideac_morning.png` (set C, restart on).

## 7. Restart after a change of the shading (task T5)

### 7.1 Rule

During P&O, the controller starts a new search when one of these is true:

1. |P - P_ref| > `mppt.dP_restart` P_ref, with `mppt.dP_restart` = 0.05. P_ref is the power of the first P&O period, at the hand-over duty.
2. P&O has run for `mppt.T_rescan` seconds. The default is 0 (off).

Power-change and timer restarts are common practice (Boztepe et al. 2014, Wang et al. 2016, Xu et al. 2021). This project uses them as published.

`run_gmppt_restart.m` runs the checks below. The results are in `results/gmppt_restart.csv` and `.mat`. Run time: 9 min for 15 runs.

### 7.2 False restarts

The start-up runs of section 6 (set A, no change of the shading, so no restart starts) give the largest |P - P_ref| / P_ref of the P&O stage. The test uses the averages Vm and Im of the controller, so it is exact.

| Method | Largest change | Worst pattern |
|---|---|---|
| DIRECT | 0.87 % | R1 |
| Idea B | 1.04 % | R1 |
| Idea C | 1.55 % | R1 |

The margin to the limit of 5 % is 3.45 %. A P&O swing on a sharp peak does not start a search.

### 7.3 Searches after each change

Sets: C, the winter morning (R1, then P1 at 1.2 s, then P0 at 2.4 s), and E, a winter evening (P0, then P1 at 1.2 s, then R1 at 2.4 s). Cells: power at the end of the phase (% of the GMPP of the phase) / searches that start in the phase.

| Run | Set C: R1 | P1 | P0 | Set E: P0 | P1 | R1 |
|---|---|---|---|---|---|---|
| P&O | 34.9 / 0 | 46.6 / 0 | 99.7 / 0 | 77.6 / 0 | 99.7 / 0 | 97.5 / 0 |
| DIRECT, restart on | 97.5 / 1 | 99.7 / 1 | 99.7 / 1 | 99.7 / 1 | 99.7 / 1 | 97.6 / 1 |
| Idea B, restart on | 99.5 / 1 | 99.7 / 1 | 99.8 / 1 | 99.7 / 1 | 99.7 / 1 | **99.5** / 1 |
| Idea C, restart on | 99.3 / 1 | 99.8 / 1 | 99.7 / 1 | 99.7 / 1 | 99.8 / 1 | **99.3** / 1 |
| DIRECT, restart off | 97.5 / 1 | 99.8 / 0 | 99.8 / 0 | 99.7 / 1 | 99.7 / 0 | 97.6 / 0 |
| Idea B, restart off | 99.5 / 1 | 99.8 / 0 | 99.8 / 0 | 99.7 / 1 | 99.7 / 0 | **97.6** / 0 |
| Idea C, restart off | 99.3 / 1 | 99.8 / 0 | 99.7 / 0 | 99.7 / 1 | 99.8 / 0 | **97.5** / 0 |

P&O does not use the restart, so it runs once in each set. P&O reaches only 77.6 % in the P0 phase of set E, because it climbs from near Voc for the full 1.2 s.

Timer test: Idea C on P1 with `mppt.T_rescan` = 1 s and no change. The searches start at 0.06 s and 1.46 s. The first hand-over is at 0.46 s, so the second search starts after 1 s of P&O, as specified.

### 7.4 What the restart gives, and what it costs

1. Each global tracker starts one new search after each change of the shading, in both sets. Ideas B and C then reach the new global peak each time (99.3 to 99.8 %). DIRECT reaches 97.5 to 97.6 % in each R1 phase. This is the same lower peak that its search finds at start-up, so it is a limit of DIRECT, not of the restart.
2. The restart is necessary in one of the four changes: P1 to R1 in set E. With no restart, B and C stay on the lower peak of R1 (97.5 to 97.6 %). With the restart, they reach the global peak (99.3 to 99.5 %).
3. In the other three changes, P&O alone reaches the new global peak. At a fixed duty, a change of the shading moves the operating point along the load line of the converter. In these patterns, the point lands on the hill of the new global peak. The expectation for set E was that the change from P0 to P1 would leave the point near the local peak of P1 at 167 V. The simulation shows that this does not happen. The operating point lands on the global hill near 115 V.
4. A search costs energy. The mean power over a whole phase of 1.2 s:

| Run | Set C: R1 | P1 | P0 | Set E: P0 | P1 | R1 |
|---|---|---|---|---|---|---|
| DIRECT, restart on | 88.5 % | 89.2 % | 91.0 % | 88.2 % | 89.4 % | 92.0 % |
| DIRECT, restart off | 88.5 % | 98.0 % | 97.8 % | 88.2 % | 98.9 % | 95.8 % |
| Idea B, restart on | 88.4 % | 88.9 % | 92.1 % | 88.0 % | 89.0 % | 91.9 % |
| Idea B, restart off | 88.4 % | 97.6 % | 98.2 % | 88.0 % | 98.9 % | 95.8 % |
| Idea C, restart on | 85.0 % | 91.5 % | 90.9 % | 86.9 % | 91.7 % | 88.5 % |
| Idea C, restart off | 85.0 % | 96.4 % | 97.5 % | 86.9 % | 99.2 % | 96.1 % |

   A search takes 0.36 to 0.72 s (9 to 18 probes of 40 ms) at a lower mean power. Where P&O alone would reach the peak, a restart loses the energy of 0.06 to 0.12 s at the GMPP. In the P1 to R1 change of set E, the restart gains 1.8 to 1.9 % of the GMPP after the search. The loss of the phase is then repaid after about 2.5 s more at the higher power (Idea B), or 5 s (Idea C). A real shadow stays for minutes, so the restart repays its cost when it finds a better peak. The phases of 1.2 s in these sets are too short to show this.
5. A shadow that changes slowly (a cloud edge) can start many searches. A rule that limits the rate of restarts was not tested.
6. The rule sees only the power at the present operating point. Most searches start in the first P&O period after a change (at 1.22 s and 2.42 s). In set C at 2.4 s, the power of DIRECT rose by only 4.5 % at its operating point, below the limit of 5 %. Its search started at 2.48 s, after P&O had climbed past +5 %. A change that moves the global peak but changes the power at the operating point by less than 5 % does not start a search.

Figures: `results/fig_gmppt_evening.png` (set E, restart on and off), `results/fig_gmppt_morning.png` (set C, restart on and off). A triangle marks the start of each search.

## 8. Shading of single bypass groups (task T6)

### 8.1 Models and patterns

In `MPPT_4x4.slx` each panel has one irradiance, so its three bypass groups switch together. A real shadow does not follow the panel edges. The static cross-check showed that the 0.8 Voc methods and DIRECT miss more often when single groups are shaded.

- `scripts/add_pv_array.m` has a group mode. Each of the 48 groups then gets its own irradiance input. G is a 12 x 4 matrix. Row (r-1)*3 + g is group g of the panel in row r, and row 1 is the top group of the top panel.
- `build_pv4x4_sweep(true)` and `build_mppt_4x4(true)` make `PV4x4_sweep_grp.slx` and `MPPT_4x4_grp.slx`. The existing models do not change. `run scripts/build_mppt_4x4` still makes `MPPT_4x4.slx` as before. The rebuilt `MPPT_4x4.slx` gives the same probes as in section 5 (checked on Idea B, P1: 14 probes, hand-over 0.6407).
- `shading_patterns_grp.m` has three patterns. G1 and G2 come from the random sets of `crosscheck/runrand.py`, rounded to 50 W/m^2. In the static cross-check, DIRECT and M1 miss the global peak on both. G3 is a diagonal shadow edge.

| Pattern | Cause | Peaks | GMPP |
|---|---|---|---|
| G1 Spots on single groups | Leaves, droppings and dust on 18 of the 48 groups, 100 to 800 W/m^2 | 6 | 3003 W at 87.0 V |
| G2 Shadow edge with a soft border | A parapet shades the lower groups of each string by a different amount | 6 | 3183 W at 92.8 V |
| G3 Diagonal shadow edge | 9, 6 and 3 groups of strings 1 to 3 at 200 W/m^2, one edge group at 600 W/m^2 | 6 | 2243 W at 124.1 V |

The GMPP of the Simscape sweep and of the numpy model of `crosscheck/pvarray.py` agree to 0.3 %.

### 8.2 Results from start-up

`run_gmppt_group.m` runs the sweeps, the static prediction (`gmppt_static_run.m`, with the RL map) and the Simulink runs. Results: `results/gmppt_group.csv` and `.mat`. Run time: 8 min for 12 runs. Cells: search probes / final power (% of the GMPP) / hand-over time.

| Pattern | P&O | DIRECT | Idea B | Idea C |
|---|---|---|---|---|
| G1 | 0 / **35.3** (local, 169 V) | 9 / **95.5** (local, 112 V) / 0.42 s | 16 / 99.8 / 0.70 s | 16 / 99.7 / 0.70 s |
| G2 | 0 / **85.3** (local, 165 V) | 9 / **91.6** (local, 144 V) / 0.42 s | 18 / 99.8 / 0.78 s | 19 / 99.8 / 0.82 s |
| G3 | 0 / **94.2** (local, 153 V) | 9 / 99.2 / 0.42 s | 15 / 99.2 / 0.66 s | 15 / 99.1 / 0.66 s |
| Mean power in the first 1 s | 32 to 63 % | 84 to 91 % | 87 to 88 % | 81 to 85 % |

What the table shows:

1. Ideas B and C reach the global peak on all three patterns. DIRECT stops on a local peak in G1 and G2, 4.5 and 8.4 % below the global peak. P&O stops on a local peak in all three.
2. The search probes in Simulink are the same as the static prediction in all nine searches. The static cross-check on the numpy curves gives the same results, except that Idea C needs 20 probes on G2 there, against 19 here.
3. With group-level shading, B and C need 15 to 19 probes. On the nine panel-level patterns they need 10 to 18. The group-level curves have more peaks close in power, which is a likely cause. Three patterns are too few to show a trend.
4. M1 and M3 need a voltage loop, which the model does not have, so they do not run in Simulink. In the static cross-check, M1 reaches 95.7 % (G1), 92.5 % (G2) and 94.3 % (G3).

Figures: `results/fig_grp_patterns.png` (irradiance of each group and the P-V curve), `results/fig_grp_time.png` (power against time).
