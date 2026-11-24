# MPPT for PV arrays under partial shading

EE449 Major Project-A, NIT Andhra Pradesh, A.Y. 2026-27.

This project builds and compares maximum power point trackers (MPPT) for a 4 x 4 PV array under partial shading. The array has 16 Emmvee E325P72 panels (325 W, 72 cells, 3 bypass diodes each). An averaged buck-boost converter feeds a resistive load, and the tracker sets the duty cycle directly. All models are in MATLAB and Simulink with Simscape Electrical.

## Status on 2026-11-21

- The simulation pipeline is complete: array models, converter model, shading patterns, P-V sweeps, run scripts, plots, and a static plant for fast checks.
- The tracker has P&O (`mppt.alg = 1`) and INC (`mppt.alg = 2`). Their results are the mid-review results of 2026-09-29.
- The tracker has five global searches. Each is an implementation of a published method or of published parts: 3 DIRECT (Nguyen and Low 2010), 4 Idea B refined, 5 Idea C, 6 PSO (Ishaque et al. 2012), 7 GWO (Mohanty et al. 2016). The code was written from the source papers on 2026-11-21 and integrated the same day. `docs/notes/gmppt_methods.md` describes each method and `docs/notes/gmppt_review.md` is the review record.
- After each search, a local stage tracks the peak. Default since 2026-11-21 (evening): the parabolic stage (`mppt.local = 3`) after all five searches. Other stages: 1 P&O, 2 the variable-step INC of Liu et al. (2008, IEEE Trans. Ind. Electron. 55(7)), 4 the INC of the mid-review.
- The Simulink baseline of the five searches is in `results/gmppt_baseline.*` and `results/gmppt_restart_tests.*`. No value was tuned. `docs/notes/gmppt_baseline_2026-11-21.md` gives the results.
- After the baseline, the user approved three value changes: Idea C splits at the corner duty (`c_corner` = 1), PSO uses 8 particles and GWO uses 6 wolves. The baseline files keep the old values. `docs/notes/gmppt_local_stage_2026-11-21.md` gives the reasons, the hold-band test (`experiments/run_gmppt_holdband.m`) and the parabolic local stage (`mppt.local = 3`, tests in `experiments/run_gmppt_local3.m` and `experiments/run_gmppt_ramp.m`). On an irradiance ramp, the VS-INC and the INC did not move after their hold. The parabolic stage follows the ramp. On 2026-11-22 the current test after a hold was changed to use the change since the first period of the hold, and the INC stages then follow the ramp too.
- The global searches of the preliminary study and their results are archived. See `archive/2026-11-21_post_midreview/README.md`.
- Plans after the baseline: `docs/notes/plans_after_baseline.md`.
- Final test plan (approved 2026-11-21, started on the evening of 2026-11-21): `docs/notes/final_test_plan.md`. On 2026-11-22 an audit fixed faults of the controller (INC hold, PSO and GWO random numbers, start step of P&O and INC, restart rule), and all phases run again (`final_test_plan.md`, section 14). Test bench and pass gates: `docs/notes/final_bench_2026-11-21.md`. The models now have the cell temperature (`pv_T`) and a sensor and ADC block (`sens`, off by default). `experiments/run_final_all.sh` runs the phases. It checks that MATLAB starts before each phase, and it stops between two phases if `results/STOP` exists.

## Layout

| Folder | Content |
|---|---|
| `run.sh`, `requirements.txt` (project folder) | The one entry point for the final tests, the figures, the report and the slides (section "How to run the final tests and make the outputs"). `requirements.txt` lists the Python packages of the slides. |
| `src/controller/` | `mppt_controller.m`, the tracker that the Simulink model calls every 50 µs. `gmppt_search.m` selects the global search, `gmppt_init.m` makes its state. One file for each search (`gmppt_direct.m`, `gmppt_ideab.m`, `gmppt_ideac.m`, `gmppt_pso.m`, `gmppt_gwo.m`), the ceiling check (`gmppt_ceiling.m`) and two helpers (`gmppt_store_add.m`, `gmppt_rand.m`) |
| `src/config/` | `pv4x4_config.m` (every value of the panel, array, diodes, converter and tracker), `shading_patterns.m`, `shading_patterns_grp.m` |
| `src/plant/` | `pv_array_curve.m` (static array model, any irradiance and temperature), `static_run.m` (closed loop on the static model, compiled by `build/build_static_mex.m`), `sensor_adc.m` (sensors and ADC), `pv_static_point.m`, `gmppt_static_run.m` |
| `models/` | Simulink models. `MPPT_4x4.slx`: array, converter and tracker. `PV4x4_sweep.slx`: P-V sweep testbench. `_grp` forms: one irradiance for each bypass group. `MPPT_avg.slx`: averaged converter test |
| `models/legacy/` | `MPPT.slx` and `MPPT_2.slx`, the first team models. Do not overwrite them |
| `build/` | Scripts that make the models in `models/` |
| `experiments/` | `run_final_*.m` and `run_final_all.sh` (the final tests, `run_final_compute.m` with `ctrl_loop.m` for the execution time), `run_pv4x4_sweeps.m` (P-V curves of every pattern), `run_po_demo.m` (P&O and INC runs), `run_gmppt_baseline.m` (the five searches on every pattern), `run_gmppt_restart_tests.m` (restart rule and timer), `gmppt_metrics.m` (values of one run) |
| `experiments/templates/` | Run and check scripts of the preliminary study. They are the harness for new global searches. See "Templates" below |
| `plots/` | Figure functions, `plot_style.m`, and `graph_menu.m` (a menu of all figures) |
| `results/` | Saved results: P-V sweeps, P&O and INC runs, the settling check, the group-level sweeps, the baseline of the global searches |
| `python/` | Static cross-check: `pvarray.py` (numpy model of the array), `patterns.py`, `shading_gen.py` (random shading), `simulink_curves/` (P-V curves from Simulink), `validate_model.py` |
| `docs/notes/` | Notes on the array model, P&O and INC, the settling of the converter, the global searches (methods, review, baseline) and the plans |
| `docs/research/` | Literature map, prior-art reading notes, and the novelty check |
| `docs/explainer/` | The DIRECT explainer (two HTML pages) and its log |
| `docs/references/` | Bib files of the literature. The PDFs stay on the local disk only (copyright) |
| `docs/source_docs/`, `docs/notebook/` | Brainstorm documents and the first-principles notebook |
| `reports/` | The EE420 mini project report (P&O and INC), with the code and the Simulink models of its runs |
| `archive/` | Earlier work, kept and not used: the preliminary global searches, old files, and zip snapshots |

## Requirements

- MATLAB R2025b with Simulink, Simscape and Simscape Electrical.
- MATLAB Coder and Simulink Coder, to check that the controller can make C code (`coder.screener`).
- Parallel Computing Toolbox, for `parsim` in the run scripts. Without it, the runs are serial and take longer. The run scripts use 4 workers (`experiments/sim_pool.m`), so that the RAM use stays at about 10 to 12 GiB.
- Python 3 with numpy, for the static cross-check in `python/`.
- MATLAB Coder and a C compiler, for the compiled static closed loop of the final tests (`build/build_static_mex.m`).
- Data that stays out of git: the Oahu Solar Measurement Grid (`data/oahu`, see `experiments/oahu_fit.m`) and a TMYx weather file (`data/epw`, see `experiments/run_final_p4.m`). Cite both in each report: M. Sengupta and A. Andreas, "Oahu Solar Measurement Grid (1-Year Archive): 1-Second Solar Irradiance; Oahu, Hawaii (Data)," NREL, DA-5500-56506, doi:10.5439/1052451 (Creative Commons Attribution 4.0 on OpenEI). L. K. Lawrie and D. B. Crawley, "Development of Global Typical Meteorological Years (TMYx)," https://climate.onebuilding.org, 2026 (file IND_AP_Gannavaram-Vijayawada.AP.431810_TMYx.2011-2025).

The models in `models/` are saved in R2025b. MATLAB R2024b cannot open them. On R2024b, make the models again with the build scripts.

## Quick start

1. Start MATLAB in the project folder. MATLAB runs `startup.m`, which puts the project folders on the path. If you start elsewhere, run `startup` from the project folder.
2. Optional: make the models again: `build_mppt_4x4`, `build_pv4x4_sweep`, and `build_mppt_4x4(true)` or `build_pv4x4_sweep(true)` for the `_grp` forms. Close a model before you make it again, because the script deletes and recreates the file.
3. Run `run_pv4x4_sweeps` to get the P-V curves and the global peak of every pattern (`results/pv4x4_sweeps.mat`).
4. Run `run_po_demo` to run P&O and INC on every case (`results/mppt_results.*` and the figures).
5. Run `run_gmppt_baseline` and `run_gmppt_restart_tests` for the global searches (`results/gmppt_baseline.*`, `results/gmppt_restart_tests.*`).
6. Run `graph_menu` to show or save any figure.

For the Python check, run `python validate_model.py` in `python/`.

## How to run the final tests and make the outputs

`run.sh` is the one entry point. Run it in Git Bash in the project folder. The settings (number of workers, path of the slide template) are at the top of the file.

1. Once on a new PC: `bash run.sh setup`. This makes the Python environment `.venv` from `requirements.txt`.
2. Before a long run: `bash run.sh check`. This tests that MATLAB and the pool of workers start.
3. Start the run: `bash run.sh all` for all the phases (about 9 h), or `bash run.sh rerun` for only the phases that the restart rule changes (about 5.25 h on 3 workers, measured on 2026-11-24. Phase 3 takes about 2.2 h of it). Keep the window open.
4. In a second window: `bash run.sh status` shows the progress. `bash run.sh stop` stops the run after the current phase. `bash run.sh resume` removes the stop request before the next run.
5. After the run: `bash run.sh outputs` draws the figures and writes the report and the slides in `reports/final_review/`.

`bash run.sh` without a command shows a numbered menu. `bash run.sh quick` is a smoke test of all the phases with few cases (about 20 min, results in `results/quick`). `bash run.sh phases p2 p3` runs only the phases that you name. `docs/notes/final_test_plan.md` describes each phase.

## The controller

`mppt_controller(V, I, mppt)` runs once per control sample (50 µs). It averages V and I over the last part of each MPPT period and then makes one decision.

- One P&O or INC period is 20 ms. One search probe is 40 ms, averaged over its last 10 ms. A shorter probe does not settle after a large duty jump (`docs/notes/pv4x4_shading_and_po.md`, section 5).
- `mppt.alg`: 1 P&O, 2 INC, 3 DIRECT, 4 Idea B refined, 5 Idea C, 6 PSO, 7 GWO, 8 not used, 9 replay of a duty list.
- After a global search, the local stage of `mppt.local` starts at the hand-over duty: 1 P&O, 2 variable-step INC, 3 parabolic stage (default for all five searches since 2026-11-21: refinement from the samples of the search, then a hold with a periodic 3-point check, `docs/notes/gmppt_methods.md`, section 7.5), 4 the INC of the mid-review.
- A new search starts in two cases (since 2026-11-22, `docs/notes/gmppt_methods.md`, section 8). a) The power differs by more than `mppt.dP_restart` (5 %) from the power at the first steady state after the hand-over, tested only when the power is steady (a slope of at most `mppt.st_band` per period, fitted over the last `mppt.st_win` periods, since 2026-11-23). The level test is off while the power is below `mppt.P_floor` (260 W, 5 % of the rated power, since 2026-11-24), because at dawn and dusk each slow rise of 5 % started a search. b) After `mppt.T_rescan` seconds of the local stage (default 900 s, 0 = off). Each run script sets its own value. Between two checks, the parabolic stage holds the voltage of the peak (`mppt.vh_on = 1`), so a change of light on all panels does not move the operating point off the peak.
- The code uses only fixed-size persistent data, so Simulink Coder can make C code for a real-time target.

## Templates

The scripts in `experiments/templates/` ran the archived searches of the preliminary study. They are kept as a record. Their algorithm numbers and result files are those of the preliminary study, and some read files from the archive. Each template has a note at the top. The current run scripts for the global searches are `experiments/run_gmppt_baseline.m` and `experiments/run_gmppt_restart_tests.m`.

## Rules for this project

See `CLAUDE.md`. In short: Simplified Technical English in all documents, no claims of novelty for published methods, model changes only through the build scripts, and code kept ready for Simulink Coder.
