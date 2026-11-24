# fable_controller: global searches, local stage and restart rule

Date: 2026-11-21. Status: first version. Checked on the static plant only, not in the Simulink model.

This folder holds a new version of the tracker code for the 4 x 4 array project. Each global search is an implementation of a published method or of published parts. The files were written from the source papers. No code comes from `archive/`.

Nothing outside this folder was changed. The integrator copies the files into the project (see "How to integrate").

## Files

| File | Content |
|---|---|
| `controller/mppt_controller.m` | New full version of `src/controller/mppt_controller.m`. Adds the local stage after a search, the endings of the papers and the new restart rule |
| `controller/gmppt_init.m` | State of the global search (replaces the placeholder) |
| `controller/gmppt_search.m` | Selects the method of `mppt.alg` (replaces the placeholder) |
| `controller/gmppt_direct.m` | DIRECT search of Nguyen and Low (2010) |
| `controller/gmppt_ideab.m` | Idea B refined: DIRECT global stage, then the ceiling check with the corner split |
| `controller/gmppt_ideac.m` | Idea C: bisection that the ceiling guides |
| `controller/gmppt_ceiling.m` | The ceiling check of Ideas B and C, with the midpoint split and the corner split |
| `controller/gmppt_pso.m` | PSO of Ishaque et al. (2012) |
| `controller/gmppt_gwo.m` | GWO of Mohanty et al. (2016), with the update of Mirjalili et al. (2014) |
| `controller/gmppt_store_add.m` | Helper: adds one sample to the store and keeps the order by duty |
| `controller/gmppt_rand.m` | Helper: random numbers from a linear congruential generator |
| `config/pv4x4_config.m` | New full version of `src/config/pv4x4_config.m` |
| `docs/methods.md` | The methods note for the thesis: steps, parameters, sources, choices |
| `docs/review.md` | The review record: trace tables, second reading, cross-check, hand traces, checklists, open questions, scratch checks |

## Algorithm numbers

| `mppt.alg` | Rule |
|---|---|
| 1 | P&O (not changed) |
| 2 | INC with a fixed step (not changed) |
| 3 | DIRECT of Nguyen and Low, then the local stage |
| 4 | Idea B refined, then the local stage |
| 5 | Idea C, then the local stage |
| 6 | PSO of Ishaque et al., then the local stage |
| 7 | GWO of Mohanty et al., then the local stage |
| 8 | Not used. One probe at `Dstart`, then the local stage |
| 9 | Replay of a duty list (not changed) |

`mppt.local` selects the local stage after a search: 1 = P&O with the step `dD`, 2 = variable-step INC of Liu et al. (2008). The default is 2.

## How to integrate

1. Close `MPPT_4x4.slx` and `MPPT_4x4_grp.slx` in MATLAB.
2. Copy the eleven files of `controller/` into `src/controller/`. Three of them replace files: `mppt_controller.m`, `gmppt_search.m` and `gmppt_init.m`.
3. Copy `config/pv4x4_config.m` over `src/config/pv4x4_config.m`.
4. Make the models again with `build_mppt_4x4` (and `build_mppt_4x4(true)` for the `_grp` form). The MATLAB Function block reads the struct `mppt` from the model workspace, and the struct has new fields.
5. In each run script, set `mppt.T_rescan` for the run time. The default is now 900 s. A value of 0 turns the timer off.
6. The scripts in `experiments/templates/` have the algorithm numbers of the preliminary study. Set `algs` and `algName` to the numbers of the table above.
7. Update `README.md` and `docs/notes/` of the project (project rule 7): the status, the list of `mppt.alg`, the local stage and the restart rule. `docs/methods.md` of this folder can become a note in `docs/notes/`.

`src/plant/gmppt_static_run.m` works with the new files with no change. It runs its own P&O after the search and does not use `mppt.local`.

## Changes to the two existing files

### `mppt_controller.m`

The behaviour of `mppt.alg` = 1, 2 and 9 is not changed. A scratch run gave the same log as the old file for these three modes (`docs/review.md`, section 9.2).

| What changed | Where | Why |
|---|---|---|
| Header: text for `p.alg` = 3 to 8, the local stage and the restart | Lines 39-78 | The header describes the new behaviour |
| New persistent variables `loc`, `dDloc`, `heldL`, `armed`, `Dh`, `Ph` | Lines 95, 107-112 | State of the local stage and of the restart test |
| New variable `dDv`, added to the duty in the update line | Lines 130, 247 | The variable-step INC needs a duty step that is not a multiple of `p.dD`. For `p.alg` = 1, 2 and 9, `dDv` is 0 |
| At the hand-over: select the local stage from `p.local`, or the ending of the paper with `p.paper_end = 1` | Lines 142-157 | Task: all the searches hand over to the same local stage. The ending of each paper is an option |
| Restart test: power change only between local periods of the same duty, with a look-back of four periods | Lines 164-190 | The old test took P_ref at the hand-over duty. The climb of the local stage then started a new search again and again (fault of 2026-11-21 on pattern P1) |
| Restart reference `p.restart_ref` | Lines 176-186 | Both forms are in the literature: the last power, and the stored power of the tracked peak |
| Before the first call of a restart: `st.re`, `st.Dprev`, `st.Pprev`, `st.Pnow` | Lines 203-208 | The PSO restart of Ishaque et al. needs the old duty and the two powers (`p.pso_reinit = 1`) |
| Local stage: P&O with the step `dDloc`, variable-step INC, or hold | Lines 212-224 | Task: variable-step INC as the local stage. The P&O branch is the old code with `dDloc` in place of `p.dD` |
| New local function `vsIncStep` | Lines 292-322 | Variable-step INC of Liu et al. (2008) |
| Comment of `Pref` and `kt` | Lines 103-104 | The meaning changed |

Not changed: the averaging, the timing of the probes, the branches of `p.alg` = 1, 2 and 9, the function `incStep`, and the outputs.

### `pv4x4_config.m`

Each existing field is kept. One existing value changed.

| What changed | Where | Why |
|---|---|---|
| Comment of `p.alg` | Lines 98-102 | New algorithm numbers |
| Comment block of the global search and of the restart | Lines 129-165 | New local stage and new restart rule, with sources |
| `p.T_rescan`: 0 changed to 900 | Line 157 | Task: the periodic rescan is on by default. 15 min is a typical interval for a real system (Koutroulis and Blaabjerg 2012, Wang et al. 2016). Used only for `p.alg` = 3 to 8 |
| New field `p.restart_ref` | Line 148 | Reference power of the restart test |
| New fields `p.local`, `p.paper_end`, `p.vs_dDmax`, `p.vs_N`, `p.vs_dDmin`, `p.vs_hold_dir` | Section "Local stage after a global search" | Local stage |
| New fields `p.dir_*` | Section "DIRECT" | DIRECT search and its sampling interval |
| New fields `p.eps_c`, `p.tau`, `p.delta_s`, `p.theta`, `p.c_corner` | Section "Ceiling check" | Ideas B and C |
| New fields `p.pso_*` | Section "PSO" | PSO |
| New fields `p.gwo_*` | Section "GWO" | GWO |
| New field `p.rng_seed` | Section "Random numbers" | Start value of the random numbers |

The size of the sample arrays still comes from `p.Drep` (1 x `p.Nmax`). The number of particles comes from the size of `p.pso_D0`, and the number of wolves from the size of `p.gwo_D0` (at least 3). A change of one of these sizes needs a new build.

## What was checked, and what was not

- The code was reviewed against each source (`docs/review.md`, sections 2 to 7).
- With the permission of the user, the files ran in MATLAB R2025b in a scratch copy outside the project, on a static plant: each search on the nine stored curves, the controller in a closed loop, `checkcode`, `coder.screener` and `codegen` with dynamic memory off (`docs/review.md`, section 9). No value was tuned after a result.
- Not checked: the Simulink model with the converter dynamics, the group-level patterns, random shading, and the real-time target.

## Values that are not verified

`docs/review.md`, section 8.2, has the full list. The two values in the code that are marked UNVERIFIED:

- `p.pso_K1` = 1.7e4: an estimate for this array. Used only with `p.pso_reinit = 1`.
- `p.gwo_D0`: 3 wolves at fixed duties with equal spacing. The paper of the method gives no number. The value comes from a report on a later paper of the same authors, which is not on the disk.

## Open questions

`docs/review.md`, section 8.3, lists twelve questions for the integrator. The most important ones:

1. The reading of the DIRECT paper for the case that only one of its two shading tests is true. On this plant, seven of the nine patterns take this path.
2. Skip rule 2 of DIRECT always fires on the default range with the rated Voc and Isc.
3. The PSO takes 36 to 60 probes, and GWO stops on a local peak for pattern R1 (95.3 % of the global peak). The end tests and the number of iterations of both are choices of this project, because the papers give none.
4. The direction of the first move after a hold: the variable-step INC follows the paper of Liu et al., and the INC of `mppt.alg = 2` uses the other direction.
