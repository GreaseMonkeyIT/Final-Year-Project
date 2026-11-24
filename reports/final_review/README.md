# Final review: global MPPT of the 4 x 4 PV array

This folder holds the material of the final review of the project: the figures and the summary table of the final tests, the code that draws them, a short report in the IEEE format, and the review slides.

The final approach is Idea C with the parabolic local stage. The comparison is against DIRECT as in its paper (Nguyen and Low 2010), Idea B, PSO and GWO with the parabolic stage, and P&O and INC from start-up. All the values come from the third run of the final tests (`docs/notes/final_test_plan.md`).

## Contents

| Path | Content |
|---|---|
| `FinalReport_MPPT.docx` | Short report in the IEEE A4 two-column format of the EE420 report. Full draft (2026-11-24) for the team to edit: abstract, introduction, system, methods, tests, discussion of the results and conclusion, with Idea C as the main method. The references are numbered in the order of their first citation. |
| `FinalReview_MPPT.pptx` | Review slides (29), made from the mid-review slides of batch 4. Slides 1 to 7 are the opening slides of the mid review, updated for the final review. Slide 8 is "Why a Global Search". Then: system, methods, two Idea C slides, two worked-example slides, the result figures, the summary, the findings, limits and next steps, the conclusion, and the references of the final methods. The date is the placeholder DD/MM/2026 (`DATE` in `build_deck.py`). |
| `figures/` | The figures (PNG, 200 dpi) and `summary.csv`, the summary table of all the tests. |
| `make_figures.m` | Draws all the figures and writes `summary.csv`. It runs no simulation. |
| `graph_menu.m` | Draws one figure at a time from a numbered list. |
| `plots/` | One function for each figure, the colors (`fr_style.m`) and the summary table (`fr_summary.m`). |
| `build_report.py` | Writes `FinalReport_MPPT.docx` from the figures and `summary.csv`. |
| `build_deck.py` | Writes `FinalReview_MPPT.pptx` from the template slides, the figures and the worked-example figures of `docs/explainer/ceiling_example` (needs `python-pptx`, see `requirements.txt`). |

## Figures

| File | Content | Source of the data |
|---|---|---|
| `fig_pv_patterns.png` | P-V curves of the nine shading patterns, peaks marked | Static array model |
| `fig_startup_R1.png`, `fig_startup_P3.png` | Start-up waveforms of all the variants on one pattern | Simulink, `run_final_traces.m` |
| `fig_search_points.png` | The samples of each search on the P-V curve of R1 | Static bench, `run_final_traces.m` |
| `fig_startup_stats.png` | Mean and worst power at 4 s, wrong-peak ends, and the share of runs that reach a level | Phases 1c (Simulink) and 1b (static) |
| `fig_en50530.png` | Dynamic MPPT efficiency against the ramp slope | Phase 2, part A |
| `fig_ramp_trace.png` | Power against time on one ramp | Static bench, `run_final_traces.m` |
| `fig_cloud_trace.png` | Power against time on one cloud event | Static bench, `run_final_traces.m` |
| `fig_cloud_stats.png` | Efficiency and recovery time on 40 cloud events | Phase 3 (Simulink) |
| `fig_day.png` | One full day, and the energy ratio over four days | Phase 4, `run_final_traces.m` |
| `fig_noise.png` | Efficiency and wrong-peak ends under sensor noise | Phase p3n, set B |
| `fig_compute.png` | Time of one decision and compute energy of one search | Phase compute |

## How to make the files again

Use `run.sh` in the project folder (see "How to run" in the main `README.md`):

1. `bash run.sh all` runs the final tests and the traces.
2. `bash run.sh outputs` draws the figures, then writes the report and the slides.

The slides need the template `Batch-4_projectppt.pptx`. `run.sh` looks for it in the Downloads folder. Change `DECK_TEMPLATE` at the top of `run.sh` if it is in a different folder. The slides show the date placeholder DD/MM/2026. Set `DATE` at the top of `build_deck.py`, or change it in PowerPoint.

To make one output only: `bash run.sh figures`, `bash run.sh report` or `bash run.sh deck`.

The figures use the colors of the mid review, checked for color vision deficiency. Each variant has the same color in every figure, and each figure has a legend or direct labels.
