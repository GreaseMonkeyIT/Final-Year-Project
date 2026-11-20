# Archive: global searches of the preliminary study (2026-10-01 to 2026-11-08)

Archived on 2026-11-21. No file was deleted.

## Why

The user decided to start the global-search work again from the mid-review state. New algorithms for the tracker, and the methods that they are measured against, will be written again from a clean specification. The preliminary work stays here as reference data.

## What was archived

Only the work that belongs to the global-search algorithms. The pipeline that any global search needs stays in the active project.

| Archived here | Content |
|---|---|
| `src/controller/gmppt_search.m`, `gmppt_init.m` | The searches `mppt.alg = 3` to `8`: DIRECT (simplified form of Nguyen and Low 2010), Idea B (DIRECT with the ceiling check), Idea C (halving search with the ceiling), DIRECT as written in the paper, PSO after Ishaque et al. (2012), Idea B refined |
| `python/` | `algos.py` (all methods of the static study: M1 to M4, Ideas A, B and C, LIPO, the Khong stop, the Boztepe skip sweep, PSO), the run scripts, `runrand.py` (1800 random cases), all results files, `simulink_curves_runs.json` (duty sequences of the searches on the Simulink curves) |
| `results/` | The Simulink and static results of the searches, and their figures |
| `docs/` | `HANDOFF_ideas_B_C.md` (task list T1 to T10 and status), `gmppt_B_C_simulink.md`, `idea_B_theory_and_baselines.md`, `gmppt_m1_m4_comparative_study.md`, `thesis_text_B_C.md` |
| `restructure_manifest.csv` | Every file that the restructure of 2026-11-21 moved: old path and new path |

## What stays active

- `src/controller/mppt_controller.m`. Only its comments changed. P&O and INC give the same final power as the stored mid-review results (0.0000 % difference on P1 and R1 with P&O, and on P3 with INC, checked in MATLAB on 2026-11-21).
- The global-search slot: `src/controller/gmppt_search.m` and `gmppt_init.m` are now placeholders with the same interface.
- The pipeline added after the mid-review: the 40 ms search probe (`Tsearch`, `Nper_s`, `Navg_s`), the logging outputs `ph` and `np`, the restart rule (`dP_restart`, `T_rescan`), the replay mode (`mppt.alg = 9`), the models with one irradiance for each bypass group (`_grp`), the static plant, the settling check results, and the run scripts (as templates in `experiments/templates/`).
- `python/`: the array model, the patterns, the Simulink curves, and `shading_gen.py` (the random shading generator `gen()`, copied unchanged from `runrand.py`).
- `docs/research/`: the literature map, the prior-art reading notes and the novelty check.

## Values removed from `pv4x4_config.m`

These fields belonged to the archived searches only.

| Field | Value | Use |
|---|---|---|
| `dcr` | 0.005 | DIRECT stops its local trisection when width / 3 < dcr |
| `psc_i`, `psc_v` | 0.1, 0.2 | DIRECT shading test (Nguyen and Low 2010): (I3 − I1) / I3 ≥ psc_i and (V2 − V1) / V2 ≥ psc_v |
| `skip_lo`, `skip_hi` | 1/3, 0.9 | DIRECT skip rules: fractions of Voc and Isc |
| `Voc_arr`, `Isc_arr` | 183.2 V, 36.44 A | Array Voc and Isc at STC, for the skip rules |
| `eps_b`, `tol_b` | 0.02, 0.01 | Ideas B and C: split a gap while V1 × I2 > (1 + eps_b) P_best and the gap is wider than tol_b |
| `theta_c` | 0.1 | Idea B refined: the corner split stays theta_c × the gap width from each end |
| `pso_n`, `pso_w`, `pso_c1`, `pso_c2` | 3, 0.4, 1.2, 1.6 | PSO. Values from a review table (Magalhaes et al. 2026), not checked against Ishaque et al. (2012) |
| `pso_vstop`, `pso_itmax`, `pso_seed` | 0.01, 20, 1 | PSO stop and seed, chosen in the study |
| `dcr6` | 0.0025 | DIRECT as in the paper: local stop, Eq. (21) |

## Main results of the preliminary study

Read `docs/HANDOFF_ideas_B_C.md` (sections 6, 10 and 11) and `docs/idea_B_theory_and_baselines.md` (sections 1 and 6). In short, on 1800 random static cases: DIRECT found the global peak in 88 to 97 % of the cases, PSO in 93 to 98 %, and Ideas B, B refined and C in 99.7 to 100 %. In Simulink, Ideas B, B refined and C reached the global peak on all nine project patterns.

## Known interaction, found on 2026-11-21

With the placeholder search, `mppt.alg = 3` does not behave as P&O. The restart rule takes P_ref at the hand-over duty, which is `Dstart` (near Voc, low power). The P&O climb then changes the power by more than 5 %, so the controller searches again and returns to `Dstart` again and again. A search that hands over near a peak does not show this. A new search must hand over near a peak, or the restart rule must take P_ref after P&O settles.

## How to restore

1. Copy `src/controller/gmppt_search.m` and `gmppt_init.m` back to `src/controller/` (they replace the placeholders).
2. Add the fields of the table above back to `pv4x4_config.m`, after `p.Dhi`.
3. Copy the files of `results/` and `python/` back if you need the old results. `restructure_manifest.csv` gives the original path of each file. The paths in the run scripts are those of the new layout.

A full zip of the project before the restructure, `Final_Year_Project_snapshot_2026-11-21_before_restructure.zip`, is kept on the local disk next to the project folder. It is not in the repository.
