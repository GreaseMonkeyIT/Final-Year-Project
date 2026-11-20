---
title: 4 x 4 PV array under partial shading, and why plain P&O and INC fail
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
date: 2026-09-29
status: results
---

# 4 x 4 PV array under partial shading, and why plain P&O and INC fail

## 1. Summary

- The model is a 4 x 4 series-parallel array of Emmvee E325P72 panels, 5.19 kW at 1000 W/m². Each column is a string of four panels in series.
- Multiple peaks come only from mismatch inside a string. Row shading gives 2 peaks, triangle shading gives 4. Column shading gives 1 peak, because the mismatch is only between strings.
- P&O on the duty cycle stops on the first peak that it meets. From start-up, it reaches only 47 % of the global peak under row shading and 35 % under an inter-row shadow.
- INC stops on the same peaks, with the same power. INC holds still on every peak except the local peak of row shading, where P&O swings by about 8 V. On that sharp local peak, INC swings like P&O.
- The peak that the tracker finds depends on its start point, not on the power. Under triangle shading, two start points give two different local peaks (96 % and 48 % of the global peak), and neither is the global peak.
- The next step is the four methods in test.docx. This note does not cover them. See gmppt_m1_m4_comparative_study.md for the comparison and the cross-check (2026-10-01). Update 2026-10-22: the project now covers DIRECT, Idea B and Idea C. Their Simulink results are in Notes/gmppt_B_C_simulink.md.

## 2. Files and how to run

| File | Purpose |
|---|---|
| pv4x4_config.m | All values: panel, array, bypass diode, converter, P&O, INC and the global searches. |
| shading_patterns.m | The nine irradiance patterns and their causes. |
| scripts/add_pv_array.m, scripts/pv_workspace_vars.m | Build the array subsystem and its model-workspace variables. |
| scripts/build_pv4x4_sweep.m → PV4x4_sweep.slx | Voltage-sweep testbench, the same structure as MPPT.slx. With the argument true, it makes PV4x4_sweep_grp.slx, with one irradiance for each bypass group (2026-10-22). |
| scripts/build_mppt_4x4.m → MPPT_4x4.slx | Array, averaged buck-boost (as in MPPT_avg.slx), and the tracker. With the argument true, it makes MPPT_4x4_grp.slx (2026-10-22). |
| shading_patterns_grp.m | Three patterns of single bypass groups (12 x 4 matrices) for the _grp models. See Notes/gmppt_B_C_simulink.md, section 8. |
| mppt_controller.m | The P&O and INC code (mppt.alg = 1 or 2), the global searches DIRECT, Idea B and Idea C (mppt.alg = 3, 4, 5, see Notes/gmppt_B_C_simulink.md), and a duty replay for plant tests (mppt.alg = 9). The MATLAB Function block "MPPT" calls it. |
| run_settling_check.m | Settling of the search probes after large duty jumps (section 5.1). Writes results/settling_check.* and fig_settling.png. |
| pv_static_point.m | Steady-state operating point of the array for an input resistance. run_settling_check.m and gmppt_static_check.m use it. |
| run_pv4x4_sweeps.m | P-V and I-V curves and the peak table of each pattern. |
| run_po_demo.m | The P&O and INC runs and figures. Each case runs once with each algorithm. |
| graph_menu.m | Numbered menus in the Command Window to select one graph and draw it from the saved results. See "Draw one graph" below. |
| plots/make_graph.m | Draws one graph from the saved results. graph_menu.m calls it. `help make_graph` gives the list of graphs. |
| plots/plot_*.m | One function for each figure. The run scripts and make_graph.m use the same functions. |
| plots/plot_style.m, plots/sweep_axes.m | Colors, axes format, and axis ends of the figures. |
| scripts/pport.m | Helper of the build scripts. |

To get all the results:

1. Open MATLAB R2024b or later in the project folder.
2. Run `run scripts/build_pv4x4_sweep` and `run scripts/build_mppt_4x4`. The models go into the project folder.
3. Run `run_pv4x4_sweeps`. It takes about 1 min.
4. Run `run_po_demo`. It takes about 5 min.
5. Open the folder `results` for the figures and the CSV tables.

The folder scripts holds all the scripts that make the .slx files. The build scripts save each model in the project folder, not in scripts.

MPPT_4x4.slx calls mppt_controller.m. Keep the project folder as the current folder when you run the model.

### Draw one graph

1. Type `graph_menu` in the project folder. The Command Window shows a numbered list.
2. Type the number of a group: 1 P-V sweeps, 2 P&O and INC runs, or 3 Simulate again.
3. Type the number of a graph. For some graphs, also type the number of the algorithm, the pattern, or the run.
4. The graph opens in a figure window, and the first list shows again.
5. To go back, type 0 or press Enter. In the first list, this stops the menu.

The graphs come from results/pv4x4_sweeps.mat and results/mppt_results.mat, so no simulation is necessary. The group "Simulate again" runs run_pv4x4_sweeps.m or run_po_demo.m. To also save each graph as a PNG in the folder results, set `savePng = true` at the top of graph_menu.m.

Two graphs are only in the menu: "One pattern" (irradiance, I-V, and P-V of one pattern) and "One run" (power, voltage, and duty against time for any run of mppt_results.mat).

To change only the figures of run_po_demo.m, set `redraw_only = true` near the top of the script. The script then loads results/mppt_results.mat and draws the figures again, with no simulation.

Before you run a build script, close the model in your MATLAB session without saving. The build script deletes the .slx file and makes a new one. A session that still has the model open keeps the old version in memory, and a save from that session writes the old version back.

To add your own run:

1. Open run_po_demo.m. Go to the section "Cases: one simulation run for each case".
2. In the block "Your cases (set 'D')", remove the % signs from an example, or copy an example line.
3. Set `id` to the pattern that is active at the end of the run. The table compares the final power with the GMPP of that pattern.
4. For a pattern that is not in shading_patterns.m, add it there first. Then run run_pv4x4_sweeps.m, so that its GMPP is known.
5. Run run_po_demo.m. It runs the case with P&O and with INC. Set D shows only in the printed table and in mppt_results.csv.

Example: water-tank shading (R2) with a start duty of 0.70 stops on the low-voltage local peak at 75.6 V. P&O reaches 86.3 % of the GMPP (76.3 V, 4.1 V swing) and INC reaches 86.5 % (76.3 V, holds still). From the start duty 0.30, both trackers find the global peak.

To change the start duty of all runs, change `p.Dstart` in pv4x4_config.m. To change it for one case, change the field `Dstart` of that case in run_po_demo.m. The Run button of MPPT_4x4.slx uses `mppt.Dstart` in the model workspace, which build_mppt_4x4.m copies from pv4x4_config.m.

## 3. Array model

| Item | Value |
|---|---|
| Panel | Emmvee E325P72, 72 multicrystalline cells, 3 bypass diodes. Datasheet: Literature/Emmvee_PV_Module_Brochure_E325P72_p4.pdf, page 4. |
| Datasheet at STC | Pmax 325 W, Voc 45.8 V, Isc 9.11 A, Vmp 37.4 V, Imp 8.68 A |
| Block model | Simscape Electrical Solar Cell block, parameterized by Isc and Voc. Each panel is 3 blocks of 24 cells in series, one for each bypass-diode group. |
| Fitted values | Ideality factor n = 1.0. Series resistance 4.41 mΩ for one cell (0.318 Ω for one panel). |
| Panel in the model | 324.6 W at 37.53 V and 8.65 A (Vmp +0.35 %, Imp −0.35 % against the datasheet) |
| Bypass diode | One 15SQ045 for each group of 24 cells (Vf 0.37 V, Ron 0.012 Ω). A group has a Voc of 15.3 V, inside the 45 V rating. |
| Array | 4 panels in series in each string, 4 strings in parallel |
| Array at STC | Voc 183.2 V, Isc 36.4 A, Pmax 5194 W at 150.1 V and 34.6 A |
| Irradiance | One value for each panel. The 3 groups of a panel get the same irradiance. |
| Temperature | 25 °C, the same for all panels (see section 8) |

Why n = 1.0. With the Isc and Voc parameterization, the block has two free values, n and Rs. An exact fit of Vmp and Imp needs n = 0.91. A value below 1 is not physical for a silicon cell. The fit therefore uses n = 1.0 and sets Rs so that Pmax is 325 W. The peak is then 0.13 V from the datasheet Vmp. A fit with a shunt resistance (the five-parameter option of the block) does not help: the best shunt resistance is infinite.

To change the panel, edit the panel section of pv4x4_config.m and run the build scripts again. You can also change the pv_* variables in the model workspace. All the cell blocks read the same variables. The number of groups (Nbyp) is part of the structure, so a change of Nbyp needs a new build.

A Python model of the same equations gives the same peaks as Simulink, to 1 W.

## 4. Shading patterns

G(r,c) is the irradiance of the panel in row r of string c. Row 1 is the top row. P1 to P3 use one shade level (300 W/m²), so only the shape changes. R1 to R5 are realistic cases, with a shade level that suits the cause. A solid object leaves only diffuse light, about 150 W/m² on a clear day.

| ID | Pattern | Real cause | Peaks | GMPP | GMPP / uniform |
|---|---|---|---|---|---|
| P0 | Uniform | Clear sky | 1 | 5194 W at 150.1 V | 100 % |
| P1 | Row shading (bottom row 300) | The row in front at low sun, snow or dust on the lower edge | 2 | 3850 W at 111.3 V | 74 % |
| P2 | Column shading (string 1 at 300) | Shadow of a pole, a lightning mast, or a vent pipe | 1 | 4282 W at 149.9 V | 82 % |
| P3 | Triangle shading (6 panels at 300) | Diagonal edge of a building shadow | 4 | 2638 W at 117.8 V | 51 % |
| R1 | Inter-row shadow, low sun (row 4 at 150, row 3 at 600) | Winter morning or evening | 3 | 2563 W at 119.2 V | 49 % |
| R2 | Water tank at one corner (2 x 2 at 150) | Rooftop water tank or stair room | 2 | 3008 W at 151.2 V | 58 % |
| R3 | Tree canopy, graded (700, 500, 300) | Tree at one corner | 3 | 3407 W at 157.3 V | 66 % |
| R4 | One soiled panel (600) | Bird droppings or heavy dust | 2 | 4720 W at 151.6 V | 91 % |
| R5 | Cloud over two strings (400) | Cloud edge | 1 | 3635 W at 149.9 V | 70 % |

Figures: results/fig_patterns.png, results/fig_pv_curves.png (one graph for each pattern), results/fig_pv_all.png (all nine curves on one graph), results/fig_iv_pv_test.png.

What the curves show:

- A string has as many current steps as it has different irradiance levels. Each step gives one peak. The array curve adds the string currents at the same voltage.
- In P2 and R5, each string has only one irradiance level. No bypass diode conducts, so the array has one peak. The power falls, but P&O and INC still find the peak.
- In P1, every string has one shaded panel. The global peak (111.3 V) is the step where the three sunny panels work and the bypass diodes carry the shaded panel. The local peak (167.3 V) is the step where all four panels work at the current of the shaded panel.
- The wiring decides the number of peaks. If the strings ran along the rows, row shading would shade one full string and give one peak. For inter-row shading, wire each string along one row of the rack.

## 5. P&O and INC on the duty cycle

Both trackers change the converter duty directly. They have no voltage loop. They use the same values, so only the decision rule is different and the comparison is fair.

| Item | Value | Reason |
|---|---|---|
| Control sample Tc | 50 µs | One period at 20 kHz, as in an ADC interrupt on the real-time target |
| MPPT period | 20 ms | One applied operating point. The converter settles in less than 10 ms. |
| Averaging | V and I over the second half of each period | Removes the settling transient. On hardware, it also removes the switching ripple and the ADC noise. |
| Duty step | 0.005 | One step moves the voltage by about 4 V near the peaks. P&O swings over two steps, about 8 V. |
| Start duty | 0.30 | The converter input resistance is then 54 Ω, so the array is near Voc, to the right of the highest-voltage peak of every pattern. This is the state after start-up. |
| Start delay | 3 periods | The input capacitor charges |
| Computation delay | 1 sample | The new duty goes to the PWM one sample after the ADC read. The delay also breaks the algebraic loop in Simulink. |
| Converter | Average-Value DC-DC Converter, buck-boost, L 150 µH, Cout 470 µF, C_in 220 µF | The values of MPPT_avg.slx |
| ESR | 50 mΩ on C_in and on Cout | Typical for electrolytic capacitors. The ESR also adds damping to the resonance of L and C_in. |
| Load | 10 Ω | The MPP of the uniform array (4.3 Ω) is near D = 0.60, with an output of about 230 V. A 1 Ω load puts it near D = 0.33 with a low output voltage. |
| INC hold band | \|dI/dV + I/V\| ≤ 0.30 · I/V | The same as \|dP/dV\| ≤ 0.30 · I. On this array, the band is about ±1.5 V around a smooth peak, less than one duty step. A band of 0.05 almost never holds, because one step jumps over it. |
| INC current band after a hold | \|dI\| > 0.005 · I | A smaller change of current is not a change of irradiance. |

In a buck-boost, a higher duty gives a lower PV voltage. For both trackers, the first step is a perturbation only (+0.005), because the two points before it have the same duty.

P&O rule: if the power increased in the last period, step the duty again in the same direction. If the power decreased, reverse the direction.

INC rule. At a peak, dP/dV = 0, which is the same as dI/dV = −I/V.

1. Calculate dV and dI against the last period.
2. If dI/dV > −I/V, the point is left of a peak. Decrease the duty, so the voltage increases.
3. If dI/dV < −I/V, the point is right of a peak. Increase the duty.
4. If the two values are in the hold band, keep the duty.
5. After a hold, V does not change. INC then tests only dI. If the current increased by more than the current band, the irradiance increased, so decrease the duty. If it decreased, increase the duty. Else keep the duty.

The code is the local function incStep in mppt_controller.m. For step 5, it uses the hold flag of the last period, not a voltage threshold. A fixed duty gives a fixed voltage, so the flag is not affected by noise.

Settling check: in all 24 runs of sets A, B and C, the average array voltage over the second half of a period and the average over its last quarter agree to 0.34 V, which is 0.2 % of the voltage at the peaks. This check includes the periods with an irradiance step.

### 5.1 Settling of the search probes (2026-10-22, task T1)

The check above covers P&O steps of 0.005 in duty. The global searches (DIRECT, Ideas B and C) jump by up to 0.32 in duty. The ceiling V1 x I2 of Ideas B and C holds only for samples in steady state, so the large jumps need their own check.

Method (`run_settling_check.m`):

1. The duty sequences come from the Python cross-check on the Simulink curves (`crosscheck/run_simulink_curves.py`). Five sequences: DIRECT on P1 and R1, Idea B on R1, Idea C on P1 and R1. Each has its search probes and 10 P&O probes after the hand-over.
2. A replay mode of the controller (`mppt.alg = 9`) applies a duty list. Each entry holds for `mppt.Nhold` MPPT periods.
3. Fast runs hold each entry for one period (20 ms) or two periods (40 ms). A slow run holds each entry for 5 periods and gives the settled value at each duty.
4. For each probe, the script compares the average at the end of the fast probe with the settled value.

Result (worst power error over 62 search probes and 50 P&O probes):

| Probe length | Average over the last half | Average over the last quarter |
|---|---|---|
| 20 ms (the P&O timing) | 4.42 % | 1.77 % |
| 40 ms | 0.37 % | **0.21 %** |

- With the P&O timing, a search probe can be 4.4 % off its settled power. The error is in the voltage. The current error stays below 0.5 %.
- The large errors follow a jump into the low-voltage part of the curve (duty 0.70 to 0.78). There, the array acts as a current source and adds almost no damping. The jump starts a ringing of L and C_in at about 670 Hz. The ringing decays with a time constant of about 6 ms. Figure: `results/fig_settling.png`.
- A step response from a settled start gives these worst errors: 30 ms and the last quarter 0.49 %, 40 ms and the last half 0.37 %, 50 ms and the last quarter 0.09 %.
- P&O steps settle well with the 20 ms timing. The worst P&O probe is 0.08 % off.

Decision: a search probe lasts `mppt.Tsearch` = 40 ms, and the controller averages its last quarter (`mppt.Navg_s` = 200 samples, 10 ms). The worst error is then 0.21 %, below the limit of 0.5 %. P&O keeps the 20 ms period. A search probe therefore costs 40 ms, not the 20 ms of the static cross-check.

Second result: the settled points of `MPPT_4x4.slx` lie on the static sweep curve to 0.001 % if the converter input resistance includes the inductor resistance RL: R_in = (R (1 - D)^2 + RL) / D^2. The ideal map R (1 - D)^2 / D^2 of `crosscheck/algos.py` puts the static point off by -0.55 % to +2.07 % in power. The Python results stay valid as a comparison between methods. A Simulink run can make a different choice from Python where two samples are close in power (see `Notes/gmppt_B_C_simulink.md`).

The solver reported a minimum step size warning 3 times in the 15 runs (at 0.104 s, 0.107 s and 0.269 s). Each run continued. The probes near these times show no outlier against the slow runs.

## 6. Results

"V swing" is the peak-to-peak array voltage over the last 0.3 s of a run. 0 V means that the tracker holds still.

### 6.1 Set A: from start-up (start duty 0.30, 2.5 s)

| ID | Pattern | Stops on | P&O reached | INC reached | P&O V swing | INC V swing |
|---|---|---|---|---|---|---|
| P0 | Uniform | global | 99.8 % | 100 % | 8.3 V | 0 V |
| P1 | Row shading | local, 167.3 V | **46.6 %** | **46.6 %** | 7.4 V | 7.4 V |
| P2 | Column shading | global | 99.8 % | 100 % | 8.0 V | 0 V |
| P3 | Triangle shading | local, 153.8 V | **95.9 %** | **96.1 %** | 7.8 V | 0 V |
| R1 | Inter-row shadow, low sun | local, 167.6 V | **34.9 %** | **35.1 %** | 11.9 V | 0 V |
| R2 | Water tank at one corner | global | 99.8 % | 100 % | 7.9 V | 0 V |
| R3 | Tree canopy, graded | global | 99.8 % | 100 % | 8.1 V | 0 V |
| R4 | One soiled panel | global | 99.8 % | 100 % | 8.2 V | 0 V |
| R5 | Cloud over two strings | global | 99.8 % | 100 % | 8.0 V | 0 V |

From start-up, the array is near Voc, so both trackers climb to the highest-voltage peak. They succeed only when that peak is also the global peak (R2, R3, R4) or when the curve has one peak (P0, P2, R5). P&O and INC always stop on the same peak. Figures: results/fig_po_startup.png, results/fig_inc_startup.png.

### 6.2 Set B: a different start point

| ID | Start duty | Stops at | P&O reached | INC reached | Peak |
|---|---|---|---|---|---|
| P1 | 0.30 | 167.6 V | 46.6 % | 46.6 % | local |
| P1 | 0.66 | 110.7 V | 99.7 % | 100 % | global |
| P3 | 0.30 | 153.1 V | 95.9 % | 96.1 % | local (right of the GMPP) |
| P3 | 0.75 | 37.9 V (P&O), 36.9 V (INC) | 48.2 % | 48.2 % | local, 37.7 V (the lowest-voltage peak) |

The same tracker on the same curve gives a different result for each start point. Under P3, both trackers miss the global peak from both sides. From duty 0.75, they stop on the first peak at 37.7 V and do not reach the peak at 78.4 V or the global peak at 117.8 V. Figures: results/fig_po_trap.png, results/fig_inc_trap.png.

### 6.3 Set C: winter morning

The inter-row shadow R1 shrinks to the row shading P1 at 1.2 s. The sky is clear (P0) at 2.4 s.

| Time | Pattern | GMPP | P&O | INC | P&O V swing | INC V swing |
|---|---|---|---|---|---|---|
| 0 s to 1.2 s | R1 | 2563 W | 894 W (34.9 %) | 901 W (35.1 %) | 11.9 V | 0 V |
| 1.2 s to 2.4 s | P1 | 3850 W | 1795 W (46.6 %) | 1795 W (46.6 %) | 7.4 V | 7.4 V |
| 2.4 s to 3.6 s | P0 | 5194 W | 5181 W (99.7 %) | 5193 W (100 %) | 8.3 V | 0 V |

Both trackers stay on the high-voltage local peak while any shade is present. They recover only when the curve has one peak again. INC holds still in R1 and P0, and swings like P&O in P1. P&O keeps a swing of 7 V to 12 V in all three phases. Figures: results/fig_po_morning.png, results/fig_inc_morning.png, results/fig_po_vs_inc.png.

### 6.4 Why P&O and INC fail

- P&O makes one test in each period: did the power increase? At any peak, a small step in either direction decreases the power. P&O therefore stays at the first peak that it reaches, local or global.
- INC tests dI/dV = −I/V. This is true at every peak, local or global. INC therefore stops on the same peak as P&O.
- Neither tracker has information about the other peaks. To see a higher peak, a tracker must go through the valley between the peaks, and each step into the valley decreases the power.
- The start point and the load line after a change decide the peak. The height of the peak does not.
- Nothing in P&O or INC starts a new search. A shade that stays for minutes costs power for minutes.
- INC removes the steady swing of P&O on every peak in this study except the local peak of P1. That peak is sharp. One duty step jumps across it, the test never falls in the hold band, and INC swings like P&O. INC does not change the power: it reaches the same percentage of the GMPP as P&O, within 0.3 %.

## 7. Figures

| Figure | Content |
|---|---|
| fig_patterns.png | Irradiance of each panel, for each pattern |
| fig_pv_curves.png | P-V curve of each pattern, peaks marked |
| fig_pv_all.png | All nine P-V curves on one graph |
| fig_iv_pv_test.png | I-V and P-V of P0 to P3 |
| fig_po_startup.png, fig_inc_startup.png | Power reached from start-up, set A |
| fig_po_trap.png, fig_inc_trap.png | Operating point of each decision on the curves of P1 and P3, sets A and B |
| fig_po_morning.png, fig_inc_morning.png | Power and voltage against time, set C |
| fig_po_vs_inc.png | P&O and INC side by side: power reached, and the voltage in set C |
| fig_pattern_<id>.png, fig_run_<alg>_<set>_<id>.png | Only from graph_menu.m with savePng = true: one pattern, or one run |

## 8. Temperature (for the presentation)

The models run at a cell temperature of 25 °C. A panel in the sun runs hotter. The datasheet values, applied at 1000 W/m² and a cell temperature of 46 °C (the NOCT, +21 K):

| Value | Coefficient | 25 °C | 46 °C |
|---|---|---|---|
| Voc of a panel | −0.34 %/K | 45.8 V | 42.5 V |
| Isc of a panel | +0.05 %/K | 9.11 A | 9.21 A |
| Pmax of a panel | −0.40 %/K | 325 W | 298 W |
| Voc of the array | | 183.2 V | 170.1 V |

Points for the presentation:

- Heat lowers the voltage of every peak and the power of the array. The current changes very little.
- A shaded panel gets less light, so it runs cooler than the panels in the sun. Its voltage falls less, so the peaks move a little. Any rule that puts the peaks at fixed fractions of Voc moves with the temperature.
- Temperature changes over minutes, much slower than one MPPT period (20 ms). It moves the peaks, but it does not decide which peak P&O or INC finds.
- NOCT is a test condition (800 W/m², air at 20 °C, wind at 1 m/s). On a hot roof, the cell temperature can be much higher.

## 9. Porting the controller to the dSPACE MicroLabBox

Only the controller goes to the real-time target. The Simscape panels and converter are the plant. On the bench, the real hardware replaces them. PV4x4_sweep.slx is a simulation tool only.

- **Toolchain.** Simulink Coder generates C code from the model. The dSPACE RTI compiles the code and loads it into the MicroLabBox. ControlDesk shows and changes the variables during the run. The `ver` list of the local laptop has no Simulink Coder, so the build must be on the lab PC.
- **Version.** Each dSPACE release supports only some MATLAB releases. Find the MATLAB release that the lab's dSPACE release supports. Then run the build scripts in that release.
- **What is ready now.**
  - The Controller subsystem has only the MATLAB Function block, with inputs Vpv and Ipv and output D. It has no Simscape blocks and no logging blocks.
  - The controller runs at a fixed discrete sample time (50 µs).
  - mppt_controller.m, gmppt_search.m and gmppt_init.m use only persistent variables of fixed size and fixed-size arithmetic, which code generation accepts. Check of 2026-10-23: coder.screener reports no message and no unsupported call for the three files. All six modes (mppt.alg = 1, 2, 3, 4, 5, 9) build and run with dynamic memory allocation off (model parameter MATLABDynamicMemAlloc).
  - The controller averages V and I in software.
  - The algorithm, the step, the period, the start duty, the INC bands, and the values of the global search are fields of the struct mppt, so ControlDesk can change them. The sizes of the arrays of the search come from the size of mppt.Drep (1 x mppt.Nmax), so a change of Nmax needs a new build.
- **What the team adds in the lab.**
  - ADC input blocks with the gains of the voltage and current sensors.
  - The PWM output block. Direct-duty P&O and INC send D straight to the PWM duty input. There is no voltage loop to tune again on the real converter.
  - Limits that stop the converter on over-voltage, over-current, or a duty outside the limits.
- **Later.** The four methods in test.docx also need little computation. Update 2026-10-22: DIRECT, Idea B and Idea C now run in the controller with fixed-size arrays (Notes/gmppt_B_C_simulink.md).

## 10. Limits of this study

- Each panel has one irradiance, so its 3 bypass groups always bypass together. A real partial shadow can cover one group only, which gives more peaks (up to 12 in a string of 4 panels). Update 2026-10-22: MPPT_4x4_grp.slx and PV4x4_sweep_grp.slx give each group its own irradiance (Notes/gmppt_B_C_simulink.md, section 8).
- A partial shadow on a panel acts approximately like a panel at the irradiance of its most shaded cell.
- All panels are at 25 °C. See section 8.
- The converter model is averaged. It has no ripple and no switching losses. The settling time on hardware can differ.
- The load is a 10 Ω resistor, not a battery or a DC bus.
- The sensors are ideal. Noise on hardware can make P&O and INC step in the wrong direction. Set the INC bands above the noise level.
