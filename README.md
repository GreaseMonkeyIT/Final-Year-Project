# MPPT for PV arrays under partial shading

EE449 Major Project-A, NIT Andhra Pradesh, A.Y. 2026-27.

This project builds and compares maximum power point trackers (MPPT) for a 4 x 4 PV array under partial shading. The array has 16 Emmvee E325P72 panels (325 W, 72 cells, 3 bypass diodes each). An averaged buck-boost converter feeds a resistive load, and the tracker sets the duty cycle directly. All models are in MATLAB and Simulink with Simscape Electrical.

## Status on 2026-11-21

- The simulation pipeline is complete: array models, converter model, shading patterns, P-V sweeps, run scripts, plots, and a static plant for fast checks.
- The tracker has P&O (`mppt.alg = 1`) and INC (`mppt.alg = 2`). Their results are the mid-review results of 2026-09-29.
- The global-search slot (`mppt.alg = 3` to `8`) holds a placeholder. New global searches go into `src/controller/gmppt_search.m` and `src/controller/gmppt_init.m`.
- The global searches of the preliminary study (DIRECT, Ideas A, B and C, PSO) and their results are archived. See `archive/2026-11-21_post_midreview/README.md`.
- Planned: after any global search, a variable-step INC (Liu et al. 2008, IEEE Trans. Ind. Electron. 55(7)) replaces P&O as the local stage. Today the local stage after a search is P&O.

## Layout

| Folder | Content |
|---|---|
| `src/controller/` | `mppt_controller.m`, the tracker that the Simulink model calls every 50 µs. `gmppt_search.m` and `gmppt_init.m`: the global-search slot |
| `src/config/` | `pv4x4_config.m` (every value of the panel, array, diodes, converter and tracker), `shading_patterns.m`, `shading_patterns_grp.m` |
| `src/plant/` | `pv_static_point.m` (operating point on a static curve), `gmppt_static_run.m` (one search on a static curve) |
| `models/` | Simulink models. `MPPT_4x4.slx`: array, converter and tracker. `PV4x4_sweep.slx`: P-V sweep testbench. `_grp` forms: one irradiance for each bypass group. `MPPT_avg.slx`: averaged converter test |
| `models/legacy/` | `MPPT.slx` and `MPPT_2.slx`, the first team models. Do not overwrite them |
| `build/` | Scripts that make the models in `models/` |
| `experiments/` | `run_pv4x4_sweeps.m` (P-V curves of every pattern), `run_po_demo.m` (P&O and INC runs) |
| `experiments/templates/` | Run and check scripts of the preliminary study. They are the harness for new global searches. See "Templates" below |
| `plots/` | Figure functions, `plot_style.m`, and `graph_menu.m` (a menu of all figures) |
| `results/` | Saved results: P-V sweeps, P&O and INC runs, the settling check, the group-level sweeps |
| `python/` | Static cross-check: `pvarray.py` (numpy model of the array), `patterns.py`, `shading_gen.py` (random shading), `simulink_curves/` (P-V curves from Simulink), `validate_model.py` |
| `docs/notes/` | Notes on the array model, P&O and INC, and the settling of the converter |
| `docs/research/` | Literature map, prior-art reading notes, and the novelty check |
| `docs/explainer/` | The DIRECT explainer (two HTML pages) and its log |
| `docs/references/` | Bib files of the literature. The PDFs stay on the local disk only (copyright) |
| `docs/source_docs/`, `docs/notebook/` | Brainstorm documents and the first-principles notebook |
| `reports/` | The EE420 mini project report (P&O and INC) |
| `archive/` | Earlier work, kept and not used: the preliminary global searches, old files, and zip snapshots |

## Requirements

- MATLAB R2025b with Simulink, Simscape and Simscape Electrical.
- MATLAB Coder and Simulink Coder, to check that the controller can make C code (`coder.screener`).
- Python 3 with numpy, for the static cross-check in `python/`.

The models in `models/` are saved in R2025b. MATLAB R2024b cannot open them. On R2024b, make the models again with the build scripts.

## Quick start

1. Start MATLAB in the project folder. MATLAB runs `startup.m`, which puts the project folders on the path. If you start elsewhere, run `startup` from the project folder.
2. Optional: make the models again: `build_mppt_4x4`, `build_pv4x4_sweep`, and `build_mppt_4x4(true)` or `build_pv4x4_sweep(true)` for the `_grp` forms. Close a model before you make it again, because the script deletes and recreates the file.
3. Run `run_pv4x4_sweeps` to get the P-V curves and the global peak of every pattern (`results/pv4x4_sweeps.mat`).
4. Run `run_po_demo` to run P&O and INC on every case (`results/mppt_results.*` and the figures).
5. Run `graph_menu` to show or save any figure.

For the Python check, run `python validate_model.py` in `python/`.

## The controller

`mppt_controller(V, I, mppt)` runs once per control sample (50 µs). It averages V and I over the last part of each MPPT period and then makes one decision.

- One P&O or INC period is 20 ms. One search probe is 40 ms, averaged over its last 10 ms. A shorter probe does not settle after a large duty jump (`docs/notes/pv4x4_shading_and_po.md`, section 5).
- `mppt.alg`: 1 P&O, 2 INC, 3 to 8 global search then P&O, 9 replay of a duty list.
- After a global search, P&O starts at the hand-over duty. A new search starts when the power changes by more than `mppt.dP_restart` (5 %) from the power at the hand-over, or after `mppt.T_rescan` seconds (0 = off).
- The code uses only fixed-size persistent data, so Simulink Coder can make C code for a real-time target.

## Templates

The scripts in `experiments/templates/` ran the archived searches. They still have the old algorithm numbers and names, so they do not give useful results with the placeholder. To evaluate a new search, copy a template to `experiments/`, set `algs` and `algName`, and run it. `run_settling_check.m` and `gmppt_static_check.m` read a duty-sequence file from the archive.

## Rules for this project

See `CLAUDE.md`. In short: Simplified Technical English in all documents, no claims of novelty for published methods, model changes only through the build scripts, and code kept ready for Simulink Coder.
