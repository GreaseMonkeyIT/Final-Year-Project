---
title: Handoff, build and evaluate Ideas B and C on the MATLAB laptop
written: 2026-10-22, on the laptop without MATLAB
for: the user, and Claude Code on the laptop with MATLAB (R2025b)
---

# Handoff: build and evaluate Ideas B and C

## 0. How to use this file

**User instruction (2026-10-22).** The user copies the folder `Final_Year_Project` to the laptop that has MATLAB. The session there works through the task list in section 5 **without interruption**. Treat the tasks in section 5 as approved. Do them in order, and record results as you go.

**Ask the user first only for these items:**

- Any change to `MPPT.slx` or `MPPT_2.slx`. Never overwrite these two files.
- A rebuild of an existing `.slx` file while the user may have it open. A rebuild deletes and recreates the file, so the user must close the model without saving first.
- Deleting any file in `results/`, `Literature/` or `Notes/`.
- Any work outside Ideas B and C, except the baselines that section 5 names.
- Any wording in the thesis that claims something is new (rule R3 in section 2).

**Read in this order:**

1. This file.
2. `Notes/novelty_check_ideas_B_C.md`: what B and C borrow, what they add, the wording for the thesis.
3. `Notes/gmppt_m1_m4_comparative_study.md`: the static cross-check, its method and its numbers.
4. `Notes/pv4x4_shading_and_po.md`: the 4 x 4 array model, the P&O and INC runs, the timing of the controller.
5. `crosscheck/algos.py`: the reference code of DIRECT, Idea B and Idea C.
6. Added 2026-10-22: `Notes/gmppt_B_C_simulink.md`, the Simulink results, and section 10 of this file.

## 1. The project in one page

- **Course.** EE449 Major Project-A, NIT Andhra Pradesh, IV B.Tech I Sem, A.Y. 2026-27.
- **Title.** Implementation of MPPT for PV Arrays under Partial Shading Conditions.
- **Array.** 4 x 4 series-parallel array of Emmvee E325P72 panels (325 W, 72 cells, 3 bypass diodes each). Array: 5.2 kW, Voc 183.2 V, Isc 36.44 A. Bypass diodes: 15SQ045 Schottky (Vf 0.37 V, Ron 0.012 Ohm).
- **Simulink models.** `PV4x4_sweep.slx` (voltage-ramp testbench for the P-V curves) and `MPPT_4x4.slx` (averaged buck-boost into 10 Ohm, direct duty control, no voltage loop). The build scripts are in `scripts/`. All values are in `pv4x4_config.m`.
- **Controller.** `mppt_controller.m`. The MATLAB Function block "MPPT" in `MPPT_4x4.slx` calls it every 50 us with (Vpv, Ipv, mppt). One MPPT period is 20 ms. The controller averages V and I over the second half of each period, then makes one decision. Today it has `mppt.alg = 1` (P&O) and `mppt.alg = 2` (INC) only.
- **Done so far.**
  - P&O and INC on 9 shading patterns in Simulink. They stop on local peaks: 46.6 % (P1), 35 % (R1), 96 % (P3) of the global peak.
  - Comparative study of M1 to M4 from `test.docx`, plus Ideas A, B and C, on static P-V curves in Python (`crosscheck/`). 1800 random cases.
  - Literature: 37 PDFs in `Literature/`, two bib files, a novelty check.
- **Decision (2026-10-22).** From now on, the work covers **Idea B and Idea C only**. The user will build both. Idea C is the user's own idea.
- **Not done.** No search algorithm (DIRECT, B, C) runs in Simulink yet. The static results have no converter dynamics.
- **Status.** This section gives the state before the tasks of section 5. Section 10 gives the state after them. Today `mppt.alg` = 1 to 5 and 9 exist, and DIRECT, B and C run in Simulink.

## 2. Rules carried over

The other laptop kept these rules in Claude's memory. That memory does not copy with the folder, so they are written here.

- **R1. Plan means plan.** When the user writes "plan", return a plan with the open decisions and wait. The tasks in section 5 are already approved.
- **R2. Writing style.** Use Simplified Technical English for every document, comment and commit text. No em dashes. No semicolons. No marketing adjectives ("robust", "seamless", "powerful"). No hedge openers. Active voice. One idea per sentence, about 20 words at most. In chat, the user still wants a natural voice, but with the same bans.
- **R3. No false claims.** B and C are implementations of published parts. The thesis calls them implementations and cites the source of every part. Never write "novel", "first" or "proposed method" for a borrowed structure. A B.Tech project does not need an original method. See `Notes/novelty_check_ideas_B_C.md`, section 7.
- **R4. Model files.** The team uses MATLAB R2024b. A model saved in R2025b does not open in R2024b, and Simscape Electrical blocks cannot be exported to an older release. Make model changes through a build script, so each teammate can run it. Never overwrite `MPPT.slx` or `MPPT_2.slx`.
- **R5. Rebuilds.** Run build scripts as `run scripts/build_mppt_4x4` from the project root. They save the models to the project root.
- **R6. Sources.** Prefer journal papers, IEEE when possible. A conference paper may be cited, but mark it as one.
- **R7. Documentation.** When a task changes behaviour, a config value or an interface, update the affected notes in the same pass, and list them.
- **R8. Code style.** Match the style of `mppt_controller.m` and `pv4x4_config.m`: a header comment that explains the behaviour, short comments, the `mppt` struct for every parameter, fixed-size code that Simulink Coder accepts.

## 3. File map

| Path | Content |
|---|---|
| `pv4x4_config.m` | All values: panel, array, diodes, converter, MPPT struct `mppt` |
| `mppt_controller.m` | The tracker. Add the new algorithms here |
| `shading_patterns.m` | The 9 patterns P0, P1, P2, P3, R1 to R5 |
| `run_pv4x4_sweeps.m` | Sweeps every pattern, writes `results/pv4x4_sweeps.mat` (curves and GMPP) |
| `run_po_demo.m` | Runs P&O and INC on the cases, writes `results/mppt_results.*` and the figures. Template for the new run script |
| `graph_menu.m`, `plots/` | One function for each figure. `plot_style.m` sets the colours |
| `scripts/` | Build scripts for the models |
| `crosscheck/` | Python static cross-check. `python run_all.py` (about 1 min, needs Python 3 and numpy) |
| `crosscheck/simulink_curves/*.csv` | V, I, P of each pattern from `results/pv4x4_sweeps.mat` |
| `Notes/` | All write-ups. See section 0 for the reading order |
| `Literature/` | PDFs named by BibTeX key, `gmppt_global_search.bib`, `direct_algorithm.bib` |
| `MPPT_Notebook/` | First-principles notebook (HTML), older project framing |
| `old/` | Superseded files. Do not use. Moved here on 2026-10-31: `KISHAN.zip` (a code snapshot of 2026-09-29) and `GMPPT_landscape_and_viva_prep.md` (viva notes of 2026-08-29 for the golden-section tracker, which the project no longer uses) |
| `gmppt_search.m`, `run_gmppt_*.m` and the other files of tasks T1 to T6 | See `Notes/gmppt_B_C_simulink.md`, section 2, for the list and the order of the runs |
| `Notes/idea_B_theory_and_baselines.md` | Added 2026-11-08: theory of Idea B, Idea B refined (`mppt.alg = 8`), the baselines DIRECT as in the paper (`6`) and PSO (`7`). `run_gmppt_compare.m` and `crosscheck/run_ideab_refined.py` make its results |

## 4. The algorithms, exactly as tested

The Simulink port must do the same as `crosscheck/algos.py`. Duty D runs from 0.30 to 0.78 (`D_LO`, `D_HI`). In the buck-boost, a higher duty gives a lower PV voltage: R_pv = R_load (1 - D)^2 / D^2.

### 4.1 DIRECT (Nguyen and Low 2010), `direct()`

1. Sample the centre of [0.30, 0.78].
2. Trisect it. Sample the centres of the left and right thirds. Sort the three samples by duty: s2 (lowest duty, highest V), s1 (middle), s3 (highest duty, lowest V).
3. Partial-shading test: PSC = ((I3 - I1) / I3 >= 0.1) and ((V2 - V1) / V2 >= 0.2). If PSC is false, go to step 6.
4. Globally biased stage, 3 times: among the live intervals with the largest width, take the one with the highest centre power. Apply the skip rules of the paper:
   - If it is s3 and V < Voc_array / 3, mark it dead and do not sample it.
   - If it is s2 and (I < Isc_array / 3 or V > 0.9 Voc_array), mark it dead.
   - Otherwise trisect it (2 new samples).
5. Sort the live samples by duty. If the two highest powers are not neighbours, trisect the best interval, then trisect the best of the largest live intervals (2 more cycles).
6. Locally biased stage: trisect the interval with the highest centre power, while its width / 3 >= 0.005.
7. Hand over to P&O (step 0.005) from the centre of the best interval.

Voc_array = 183.2 V and Isc_array = 36.44 A (STC values). This is the method only. Use the values of `pv4x4_config.m`.

### 4.2 Idea B, `direct_certified(eps=0.02, tol=0.01)`

1. Run DIRECT, steps 1 to 6, without the hand-over.
2. Put all its samples (duty, V, I, P) in one list.
3. Repeat:
   1. Sort the list by duty.
   2. For each pair of neighbours (d1 < d2), compute the ceiling U = V1 x I2.
   3. Keep the gaps with U > (1 + eps) x P_best and d2 - d1 > tol.
   4. If no gap is left, stop.
   5. Sample the midpoint of the gap with the highest U. Add it to the list.
4. Hand over to P&O from the duty of the best sample.

### 4.3 Idea C, `bsp_bound(eps=0.02, tol=0.01, n_init=3)`

1. Sample D = 0.30, 0.54 and 0.78.
2. Do step 3 of Idea B on these samples.
3. Hand over to P&O from the duty of the best sample.

### 4.4 Why the ceiling holds (text for the thesis, section 5 task T9)

**Lemma.** Suppose the array current I(V) does not increase with V, and the converter maps duty to voltage monotonically, so d1 < d2 gives V(d1) >= V(d2). Take steady-state samples (V1, I1) at d1 and (V2, I2) at d2. Then every duty d in [d1, d2] gives P(d) <= V1 x I2.

**Proof.** Monotonicity gives V2 <= V(d) <= V1. Because I(V) does not increase, V(d) >= V2 gives I(d) <= I(V2) = I2. Thus P(d) = V(d) I(d) <= V1 I2.

**Conditions.**

- Every string of cells with bypass diodes has a current that does not increase with V, and parallel strings add their currents. So the property holds for any series-parallel array with bypass diodes.
- Each sample is taken in steady state.
- Irradiance and temperature do not change during the search.
- The sensors are exact. With bounded sensor error, use the robust ceiling of task T8.

**Certificate at the end of B or C.** Every gap wider than tol has a ceiling of at most (1 + eps) x P_best. A gap narrower than tol has no guarantee.

**Attribution.** The inequality is in Boztepe et al. 2014 and Wang et al. 2016. See `Notes/novelty_check_ideas_B_C.md`.

## 5. Task list

Do the tasks in order. T7 to T9 need only Python or text, so they can also run while a Simulink batch runs.

### T1. Check settling for large duty jumps (MATLAB)

**Why.** The settling check in `Notes/pv4x4_shading_and_po.md` (0.34 V worst case) covers P&O steps of 0.005. DIRECT and C jump up to 0.48 in duty. The ceiling holds only if each sample is in steady state.

**Steps.**

1. Write a short script that drives `MPPT_4x4.slx` with a duty schedule instead of a tracker. Use a new `mppt.alg` value (for example 9, "replay") that reads a duty list from the `mppt` struct and applies one entry for each period.
2. Replay the DIRECT duty sequence of pattern P1 and of R1 (get the sequence from the Python log, `Plant.log`, or from T2).
3. For each period, compare the second-half average of V and I with the static curve value at that duty (from `results/pv4x4_sweeps.mat`).

**Done when.** The power error of every probe is below 0.5 %. If not, lengthen `mppt.Tmppt` for the search stage only, or average over the last quarter of the period. Record the result in `Notes/pv4x4_shading_and_po.md`, section 5.

### T2. Port DIRECT, B and C to MATLAB and check them on static curves (MATLAB, no Simulink)

**Why.** This finds porting errors before the slower Simulink runs.

**Steps.**

1. Write `gmppt_static_check.m` (project root). It loads `results/pv4x4_sweeps.mat` and makes a static plant: for a duty D, find the point where I = V / R_pv(D) on the curve. Do the same as `Plant.at_duty` in `crosscheck/algos.py`.
2. Write the search logic as plain functions that take the plant as an argument, with the same steps as section 4.
3. Run DIRECT, B and C on the 9 patterns. Print the search probes and the final percentage of the GMPP.
4. Run `crosscheck/algos.py` on the same curves (the CSV files in `crosscheck/simulink_curves/`). Compare.

**Done when.** The probe counts and the selected duties are the same as Python on all 9 patterns. Small differences are acceptable only if they come from the curve interpolation. Explain any difference.

### T3. Add DIRECT, B and C to the controller (MATLAB)

**Steps.**

1. Add `mppt.alg = 3` (DIRECT), `4` (Idea B) and `5` (Idea C) to `mppt_controller.m`.
2. Add the new fields to `cfg.mppt` in `pv4x4_config.m`: `Dlo = 0.30`, `Dhi = 0.78`, `eps_b = 0.02`, `tol_b = 0.01`, `dcr = 0.005`, `Nmax = 64` (the size of the sample arrays).
3. Keep the code ready for Simulink Coder: persistent fixed-size arrays of length `Nmax`, no dynamic memory, no cell arrays, no `sort` on variable-size data. Write a small insertion sort if needed.
4. Suggested structure:
   - A sample store: arrays `sd`, `sv`, `si` and a count.
   - A probe queue of duties.
   - A phase variable: wait, seed, global, local, check, P&O.
   - At the end of each period, the controller stores (D, Vm, Im) for the duty that was applied, takes the next duty from the queue, and, when the queue is empty, runs the next planning step of the active phase.
   - After the hand-over, use the existing P&O code.
5. Do the DIRECT interval bookkeeping (lo, hi, centre, dead) in fixed-size arrays too.
6. Log the phase and the probe count as outputs, or as extra signals in a To Workspace block. Add the logging through `scripts/build_mppt_4x4.m`, not by hand (rule R4).
7. Update the header comment of `mppt_controller.m` and the comments in `pv4x4_config.m` (rule R7).

**Done when.** On a static-like run (one pattern, no changes), alg 3, 4 and 5 apply the same duty sequence as T2.

### T4. Run B and C in Simulink and compare (MATLAB)

**Steps.**

1. Copy `run_po_demo.m` to `run_gmppt_demo.m`. Set `algs = [1 3 4 5]` (P&O for reference, DIRECT, B, C). Keep sets A and C. Set B (start point) matters less for a global search, but keep it to show that.
2. Add these values to the result struct and the CSV:
   - Search probes before the hand-over.
   - Time to reach 98 % of the final power.
   - Final power as a percentage of the GMPP (mean of the last 0.3 s, as now).
   - Mean power over the first 1 s, as a percentage of the GMPP.
3. Make figures with the functions in `plots/`. Use one colour per algorithm from `plot_style.m`.
4. Compare with the static numbers in section 6. Write the results in a new note, `Notes/gmppt_B_C_simulink.md`.

**Done when.** Every case runs, and the note explains every difference from the static results larger than 1 % or 2 probes.

### T5. Restart trigger (MATLAB)

**Why.** Set C (winter morning) changes the shading during the run. A global tracker must search again after a change.

**Steps.**

1. Add a restart when |P - P_ref| / P_ref > `mppt.dP_restart` (start with 0.05) during the P&O stage. P_ref is the power at the hand-over.
2. Add an optional timer restart, `mppt.T_rescan` (0 = off).
3. Run set C with alg 3, 4 and 5.

**Done when.** Each tracker searches again after each shading change and reaches the new global peak. Attribution: power-change and timer restarts are common (Wang 2016, Xu 2021, Boztepe 2014).

### T6. Optional: shading of single bypass groups in Simulink (MATLAB)

**Why.** In `MPPT_4x4.slx`, each panel has one irradiance, so its three bypass groups switch together. The static check showed that the 0.8 Voc methods fail on group-level shading. B and C must also be shown there.

**Steps.** Give each of the 48 bypass groups its own irradiance input (a 4 x 12 matrix). Change `scripts/add_pv_array.m` and the build scripts, not the models by hand. Ask the user before you rebuild a model that may be open.

### T7. Baselines in the static cross-check (Python)

**Why.** A reviewer will ask for the closest prior art on the same harness. See `Notes/novelty_check_ideas_B_C.md`, sections 4 and 8.

**Steps.** Add to `crosscheck/algos.py`, and to `METHODS` in `run_all.py`:

1. **LIPO (Li et al. 2019).** Piyavskii-Shubert on duty with a constant k. Sample `D_LO` and `D_HI`, then always the argmax of the upper envelope min_j (P_j + k |D - D_j|). Stop when the envelope maximum is below (1 + eps) x P_best, or after 40 probes. Tune k as 1.2 x the largest |dP/dD| over the 9 patterns. Also run with k halved, to show what a wrong constant does.
2. **Lipschitz stop for DIRECT (Khong et al. 2013).** Run DIRECT, then stop when every interval has P(centre) + L x width / 2 <= (1 + eps) x P_best. Use the same constant as LIPO.
3. **Measured skip sweep (Boztepe et al. 2014).** Voltage grid with step VGSTEP = 0.5 to 1.0 x VocP (VocP = 15.3 V, one bypass group). Skip grid points below Vmin = P_store / I_last. Upper limit 0.9 Voc_array. Then P&O. Use `Plant.at_volt`.

**Done when.** `run_all.py` prints these methods in all tables, and `crosscheck/results_all.md` is regenerated.

### T8. Ceiling robust to sensor error, and a tolerance sweep (Python)

**Steps.**

1. Robust ceiling: with relative sensor errors dV and dI, compare V1 (1 + dV) x I2 (1 + dI) with P_best (1 - dV - dI). Add a parameter `delta` to `_bound_refine` and `bsp_bound`.
2. Run the random sets with noise 0, 0.5 %, 1 % and 2 %, with delta = 0 and with delta equal to 3 times the noise level.
3. Sweep eps in {0, 0.01, 0.02, 0.05} and tol in {0.005, 0.01, 0.02}. Report search probes against the miss rate.

**Done when.** A table in `Notes/gmppt_m1_m4_comparative_study.md` (new section) shows the trade-off. Cite Khong et al. 2013 (Assumption 7) for the notion of robustness to bounded measurement error.

### T9. Thesis text (writing)

**Steps.**

1. Write the methods section for B and C with the wording of `Notes/novelty_check_ideas_B_C.md`, section 7.1. Name the source of every part.
2. Put the lemma of section 4.4 in the methods section, with its conditions.
3. State the project's own results as results of this work: the implementation on the 4 x 4 Emmvee array model, the comparison on 1800 cases, the Simulink results of T4, and the finding that the ceiling helps as a final check but not as a pruning rule inside DIRECT.

### T10. Keep the notes current

After each task, update the affected notes (rule R7). At the end, update `Notes/novelty_check_ideas_B_C.md`, sections 1 and 8, with the Simulink status.

## 6. Reference numbers from the static cross-check

From `Notes/gmppt_m1_m4_comparative_study.md`, section 5. One probe = one 20 ms period.

### 6.1 Nine patterns, no noise (search probes / final % of the GMPP)

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| DIRECT | 9 / 99.7 | 11 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 |
| Idea B | 11 / 99.7 | 12 / 99.7 | 11 / 99.8 | 17 / 99.8 | 16 / 99.5 | 12 / 99.8 | 13 / 99.8 | 12 / 99.8 | 12 / 99.7 |
| Idea C | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 18 / 99.8 | 16 / 99.3 | 14 / 99.7 | 16 / 99.8 | 11 / 99.8 | 12 / 99.7 |

R1 has two peaks within 2.2 % of each other (2499 W and 2562 W). DIRECT stops on the lower one. B and C find the higher one.

Note: these numbers use the numpy model of `crosscheck/pvarray.py`, which differs from the Simulink curves by less than 1.75 % of the GMPP. On the Simulink curves (task T2), a probe count can differ by one or two.

### 6.2 Random patterns, 1800 cases (3 shading types, with and without 0.5 % noise)

| Method | GMPP found | Worst case | Mean search probes | Max probes | Power in first 1 s |
|---|---|---|---|---|---|
| DIRECT | 88 to 94 % | 85.9 % | 9.5 to 10.3 | 13 | 95 to 96 % |
| Idea A: pruning inside DIRECT | 88 to 93 % | 87.7 % | 9.4 to 10.1 | 13 | 95 to 96 % |
| Idea B | 99.7 to 100 % | 97.5 % | 13.6 to 15.5 | 23 | 95 to 96 % |
| Idea C | 99.7 to 100 % | 97.9 % | 12.8 to 14.3 | 24 | 94 % |

## 7. Open decisions (the user's)

| Decision | Default if the user does not answer |
|---|---|
| Keep M3 (Kouchaki 2023, a conference paper) as a comparison baseline, or replace it with Bi et al. 2020 (IEEE TIA) | Decided 2026-10-23: keep M3 and mark it as a conference paper |
| Boost or buck-boost for hardware | Keep the buck-boost of the models |
| Hardware tests (dSPACE MicroLabBox in the lab). Simulink Coder is not on the laptop | Simulation only, code kept ready for code generation |
| Task T6 (group-level shading in Simulink) | Do it after T5 if time allows |

## 8. Environment notes

- **MATLAB.** R2025b with Simscape Electrical on the MATLAB laptop. The team uses R2024b (rule R4). Stateflow is not installed, so trackers are MATLAB code in a MATLAB Function block.
- **New laptop (2026-10-31).** The old laptop was reset, so this laptop holds the working copy. It has MATLAB R2025b Update 7 with Simulink, Simscape and Simscape Electrical, the release of the saved models. The license also covers MATLAB Coder and Simulink Coder, but they are not installed. To add a product, use the MathWorks installer or `mpm install --release=R2025b --destination="C:\Program Files\MATLAB\R2025b" --products <names>` in an administrator shell. Python 3.11.9 with numpy 2.4.6 gives byte-identical cross-check files. On this laptop, `gmppt_static_check.m` gives the same values as `results/gmppt_static_check.csv`. `check_gmppt_controller.m` gives the same duty sequences and hand-overs (27 of 27). Its probe power errors differ from the stored values by at most 0.0002 percentage points, from the solver arithmetic.
- **Python.** The cross-check needs Python 3 and numpy only. Run it from `crosscheck/`.
- **Run time.** The P&O and INC demo (24 runs) takes about 5 min. `run_gmppt_demo.m` (4 algorithms, 48 runs) took 20 min on the old laptop.
- **IEEE access.** Institute access works from Microsoft Edge on the institute wifi. Turn off Cloudflare 1.1.1.1 (WARP) first, or the traffic leaves from a Cloudflare address. IEEE Xplore blocks scripted downloads (curl). On 2026-10-22, the PDFs came through the Claude extension in Edge. Springer and SIAM had no institute access. ScienceDirect showed a CAPTCHA.
- **Claude memory.** Claude's memory on the other laptop does not copy with this folder. This file and `CLAUDE.md` carry the rules instead.

## 9. History

| Date | Event |
|---|---|
| 2026-09-27 to 09-29 | Models built. 4 x 4 Emmvee array, averaged buck-boost, P&O and INC shown to stop on local peaks |
| 2026-10-01 | Study of M1 to M4 (test.docx). DIRECT chosen for the final output. Ideas A, B, C tested in the static cross-check |
| 2026-10-22 | DIRECT literature map (`Notes/direct_literature_and_ideas.md`). IEEE Xplore search, journals and conferences. Prior art read in full. Novelty check (`Notes/novelty_check_ideas_B_C.md`). Decision: build B and C only, and describe them as implementations |
| 2026-10-22 | MATLAB laptop: tasks T1 to T10 done. See section 10 |

## 10. Status on the MATLAB laptop (2026-10-22)

| Task | Result | Where |
|---|---|---|
| T1 Settling | 20 ms probes fail (worst 4.4 %). A search probe now lasts 40 ms and averages its last 10 ms (worst 0.21 %). New fields `Tsearch`, `Nper_s`, `Navg_s`. Also: the settled points follow R_in = (R (1 - D)^2 + RL) / D^2, not the ideal map of `algos.py` | `Notes/pv4x4_shading_and_po.md` 5.1 |
| T2 Port | `gmppt_search.m` gives the same duty at every probe as `algos.py`, 27 of 27 runs | `Notes/gmppt_B_C_simulink.md` 4 |
| T3 Controller | `mppt.alg` = 3, 4, 5 in `mppt_controller.m`. Simulink applies the same sequence as the static plant with the RL map, 27 of 27. Outputs `ph`, `np` added through `scripts/build_mppt_4x4.m` | same note, 5 |
| T4 Simulink | B and C reach the GMPP on all 9 patterns. DIRECT misses R1 (97.5 %). Probe counts within 2 of section 6.1, final power within 0.3 %. Power in the first 1 s is 81 to 89 % (40 ms probes and the 60 ms wait) | same note, 6 |
| T5 Restart | `dP_restart` = 0.05, `T_rescan` (0 = off). One search after each change, no false restart (largest P&O change 1.55 %). Needed in 1 of 4 changes tested | same note, 7 |
| T6 Group shading | `_grp` models from the build scripts with the argument true. B and C reach the GMPP on 3 group-level patterns, DIRECT misses 2 | same note, 8 |
| T7 Baselines | LIPO (k and k / 2), DIRECT with the Khong stop, Boztepe skip sweep in `crosscheck/` | `Notes/gmppt_m1_m4_comparative_study.md` 11 |
| T8 Noise, tolerances | Robust ceiling gives no consistent gain. Most misses at 1 to 2 % noise come from P&O | same note, 12 |
| T9 Thesis text | Draft of the methods and results chapters | `Notes/thesis_text_B_C.md` |
| T10 Notes | All notes above, and `Notes/novelty_check_ideas_B_C.md` sections 1 and 8 | |

Final check (2026-10-23):

- All scripts ran once more in the order of `Notes/gmppt_B_C_simulink.md`, section 2, with the final code. The results of T1, T2, T3 and T6 are byte-identical to the first runs. In T4, only set C changed (by at most 0.1 %), because the restart is now on by default. `run_gmppt_restart.m` now also runs set C with the restart off.
- P&O and INC with the final controller give the same power as `results/mppt_results.mat` (0.000 % difference on P1, P3 and R1), so `run_po_demo.m` and its results stay valid.
- Code generation: `coder.screener` reports no issue for `mppt_controller.m`, `gmppt_search.m` and `gmppt_init.m`. All modes build and run with dynamic memory allocation off.
- `crosscheck/simulink_curves_runs.json` made again with the final `algos.py` is byte-identical.

Decisions of the user (2026-10-23):

- Keep M3 (Kouchaki 2023) as a comparison baseline, and mark it as a conference paper.
- The thesis names the two methods "the DIRECT tracker with a ceiling check" (Idea B) and "the ceiling-guided bisection" (Idea C). These names are accepted for now.

Open items for the user:

- The other open decisions of section 7.
- `MPPT_4x4.slx` was rebuilt in R2025b. Teammates on R2024b must run `run scripts/build_mppt_4x4` themselves.

## 11. Status on 2026-11-08

The user asked for a theory analysis of Idea B, two baselines (DIRECT as written in Nguyen and Low 2010, and a widely used method), and an honest improvement of Idea B. `Notes/idea_B_theory_and_baselines.md` has all of it.

- `mppt.alg = 6`: DIRECT as written in the paper. Two independent readings agree. The DIRECT of `mppt.alg = 3` is a simplified form, and the notes now say so.
- `mppt.alg = 7`: PSO after Ishaque et al. (2012). The original paper was not available. Its values come from a review table. **The user must check them against the paper.**
- `mppt.alg = 8`: Idea B refined. No extra DIRECT cycles, no local DIRECT stage, and a split at the corner duty. 1.7 fewer probes for the same certificate. The corner split is the projection step of the polyblock algorithm of monotonic optimization (Tuy 2000), so it is not new. The certificate of Ideas B and C is also standard in that theory (`Notes/novelty_check_ideas_B_C.md`, section 11).
- The MATLAB port matches Python probe for probe on all 54 static runs. The Simulink runs agree with the static results.

