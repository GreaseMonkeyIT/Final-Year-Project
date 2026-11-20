# Final Year Project: MPPT for PV arrays under partial shading

EE449 Major Project-A, NIT Andhra Pradesh, A.Y. 2026-27. 4 x 4 array of Emmvee E325P72 panels, averaged buck-boost, direct duty control, MATLAB R2025b with Simscape Electrical.

## Start here

Read `README.md` before any work. It gives the folder layout, the status and the quick start. On 2026-11-21 the project was restructured, and the global searches of the preliminary study were archived. `archive/2026-11-21_post_midreview/README.md` says what was archived, why, and how to restore it. New global searches go into `src/controller/gmppt_search.m` and `src/controller/gmppt_init.m`, which are placeholders today.

## Rules

1. **Plan means plan.** When the user writes "plan", return a plan with the open decisions and wait before any project file changes.
2. **Writing.** Simplified Technical English in every document, comment and commit text. No em dashes, no semicolons, no marketing adjectives, no hedge openers. Active voice. One idea per sentence.
3. **No false claims.** Published methods and their parts are implementations. Call them implementations and cite the source of every part. Never write "novel", "first" or "proposed method" for a borrowed structure. See `docs/research/novelty_check_ideas_B_C.md`, section 7.
4. **Scope.** The user chooses the global searches and the baselines that they are measured against. Do not restore the archived searches unless the user asks.
5. **Models.** The team uses R2024b. Change models only through the build scripts in `build/`. Never overwrite `models/legacy/MPPT.slx` or `models/legacy/MPPT_2.slx`. A rebuild recreates the file, so ask the user to close the model first.
6. **Code.** Keep `src/controller/mppt_controller.m` and the search files ready for Simulink Coder: persistent fixed-size data, every parameter in the `mppt` struct of `src/config/pv4x4_config.m`.
7. **Documentation.** When a task changes behaviour, a config value or an interface, update `README.md` and the affected notes in `docs/notes/` in the same pass.
8. **Sources.** Prefer journal papers, IEEE when possible. Mark conference papers as conference papers.
9. **Repository.** The GitHub repository is public. Do not commit paper PDFs or other third-party files (`.gitignore` excludes them). Commit only when the user asks.
