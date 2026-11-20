---
title: Session notes 2026-09-27 and 2026-09-28 - algorithm choice, notes review, Simulink models, converters, MPPT plan
project: Implementation of MPPT for PV Arrays under Partial Shading Conditions
status: reference
---

# Session notes, 27 September 2026

This note records the results of two Claude Code sessions, on 27 and 28 September 2026. Use it as context for later work. Section 0 lists the files.

## 0. Files in the project folder

| File | Content | Format |
|---|---|---|
| MPPT.slx | The original team model: a voltage-source sweep of a string of 3 cells. First sent as MPPT.slx.zip. Library default diodes. Do not change it. | R2024b |
| MPPT_2.slx | The team model with the switching Buck-Boost Converter. Library default diodes. Do not change it. | R2024b |
| old/MPPT_boost.slx | Superseded. Discrete switching boost converter, 15SQ045 diodes, duty ramp. old/build_mppt_boost.m makes it from MPPT.slx. | R2025b |
| MPPT_avg.slx | Average-Value DC-DC Converter (buck-boost), 15SQ045 diodes, duty ramp. build_mppt_avg.m makes it from MPPT_2.slx. Use this model for MPPT work. | R2025b |
| scripts/build_mppt_avg.m | Build script. A teammate with R2024b runs them to get models that R2024b can open. | |
| scripts/set_realistic_diodes.m | Gives diode blocks the 15SQ045 values. | |
| PV4x4_sweep.slx | Voltage-sweep testbench of a 4 x 4 array of Emmvee E325P72 panels (3 bypass diodes each), like MPPT.slx. build_pv4x4_sweep.m makes it. Added 29 September 2026. | R2025b |
| MPPT_4x4.slx | The 4 x 4 array with the averaged buck-boost of MPPT_avg.slx and P&O or INC on the duty cycle. build_mppt_4x4.m makes it. Added 29 September 2026. | R2025b |
| pv4x4_config.m, shading_patterns.m | All values of the 4 x 4 models, and the nine shading patterns. | |
| old/ | Superseded files: MPPT_boost.slx and its build script, GMPPT_Five_Method_Comparison.docx (replaced by test.docx), and the four abstract drafts. | |
| scripts/add_pv_array.m, scripts/pv_workspace_vars.m, scripts/pport.m | Helpers of the build scripts. All the scripts that make .slx files are in the folder scripts. They save the models in the project folder. | |
| graph_menu.m, plots/ | Numbered Command Window menus to draw one graph from the saved results. plots/ holds one function for each figure, plot_style.m, and make_graph.m. | |
| mppt_controller.m | The P&O and INC code. The MATLAB Function block in MPPT_4x4.slx calls it. | |
| run_pv4x4_sweeps.m, run_po_demo.m | Run the sweeps and the P&O and INC demonstration. They write to the folder results. | |
| Notes/pv4x4_shading_and_po.md | Results of the 4 x 4 study and the P&O demonstration. | |

## 1. Algorithm choice: GA + ANN is not viable at scale

**Decision.** Do not put a genetic algorithm or a neural network inside the tracker. Use the deterministic two-stage tracker from Chapter 11 of the notebook: a window probe, then a golden-section refinement. Keep GA, ANN, and PSO as baselines.

**Reasons.**

- Each GA individual is one duty cycle. The converter must apply it and let it settle. A population of 10 over 10 generations costs 100 settling times. Ahessab et al. (2024) measured plain PSO at 2.7 s in simulation and 35 s to 50 s on hardware.
- The ANN needs the irradiance of each module as an input. That is one sensor for each panel. Ahessab et al. name this as the main barrier to deployment.
- The ANN needs training data for each array. It also needs retraining after a module changes or ages.
- Both methods are stochastic. The worst-case tracking time has no bound.
- An ANN alone cannot tell a local peak from the global peak (Worku et al. 2023).

**Applied operating points for a four-module string (Nm = 4), from Chapter 11.**

| Method | Points | Finds the global peak | Viable at scale |
|---|---|---|---|
| P&O or INC | few | no | only as the refinement stage |
| Full sweep + P&O | about 320 | yes | yes, industry ships this |
| Capacitor-transient I-V capture | 1 event | yes | yes, if the hardware allows it |
| Window probe + golden-section (ours) | 2Nm + 7 = 15 | yes, while the peaks stay in their windows | yes |
| DIRECT | 30 to 60 | yes | yes, as a fallback when Nm is unknown |
| PSO or GWO | about 90 | usually | no |
| GA | 60 to 200 (estimate) | usually | no |
| ANN or ANFIS | 1 inference + refinement | no | no |

**Proposed addition: a skip bound.** In a series string, the current never rises when the voltage rises. After a measurement (V, I), no voltage between V and P_best / I can give more than P_best. Use this rule to mark voltage ranges as empty without a probe. Then scan each range that is not probed and not marked. The window method then finds the global peak, to the voltage step, even when the 0.8·Voc windows move. The published form of this idea is the "search-skip-judge" tracker. The citation is probably Chen et al., IEEE Trans. Sustainable Energy, 2014. Verify the citation before use.

**Document issues.**

- In old/abstract_ieee.tex, Objective 2 does not name the proposed method. Name the deterministic tracker there.
- Notebook Chapter 11, Answer A, says that most commercial string inverters use a capacitor-transient sweep. The landscape notes confirm only a full-range voltage sweep. Verify or soften this claim.

## 2. Review of the study notes (Untitled document.docx)

The document is a set of study notes with questions and answers. It is independent of the Simulink model.

**Correct statements.**

- Uniform irradiance gives one peak. The reason: I = Iph − I0(e^(V/a) − 1). For V > 0, dI/dV and d²I/dV² are both negative. Thus d²P/dV² = 2·dI/dV + V·d²I/dV² is negative. P is concave, so only one maximum exists.
- The bypass diode is reverse biased in normal operation. It conducts when its substring goes negative. It carries only the excess current, I_string − Iph_shaded.
- The load-line explanation, the role of the DC-DC converter, and MPPT as the search for an "apparent load" are correct.
- Answer 3, the fictitious load, is correct.
- Answer 4, the image, is correct: 16 V, 4 A, and 64 W for the 4 Ω load, and the stability argument. Also, 64 W is the MPP of that table (57.6 W at 12 V, 63 W at 14 V, 36 W at 18 V). The 4 Ω resistor is on the MPP by chance. A change in irradiance moves the MPP away from it.

**Corrections.**

1. "Shaded cells get reverse biased" is true only when the string current is more than the photocurrent of the shaded cell. Near Voc, the string current is low and the shaded cell still generates.
2. The last sentence of the notes is wrong. When the load needs less than the maximum power, the controller leaves the MPP. It moves to the point where the array power equals the demand. This point is usually on the high-voltage side of the peak. The current and the losses are lower there, and voltage control is stable.
3. Answer 1 has the correct conclusion but the wrong mechanism. The reverse current of an ideal diode cannot go past −I0, which is some nanoamperes. The shunt resistance Rsh carries the excess current. The cell voltage goes to about −(I_string − Iph)·Rsh. If this voltage reaches breakdown, avalanche current takes over. With a bypass diode, the reverse voltage stays near the forward voltage of the other cells in the same bypass group. For 20 cells, that is about 10 V.
4. Answer 2 is correct, with two refinements. First, the power peak is at the knee of each step of the staircase I-V curve, just before the current drops to the next step. It is not at the kink. Second, the number of peaks is at most the number of different irradiance levels, not the number of substrings.
5. Answer 3 needs one addition. A boost converter can only show the array a resistance that is lower than the load: R_in = R_load(1 − D)². A buck converter can only show a higher resistance. Choose the topology so that the MPP resistance is in range.

## 3. Review of MPPT.slx (saved in R2024b, first sent as MPPT.slx.zip)

The model has three solar cells in series. Each cell has a bypass diode in antiparallel. The irradiances are 1000, 500, and 200 W/m². A controlled voltage source ramps from 0 V to 6 V at 0.2 V/s over 30 s. An XY graph plots P against V. The wiring and the diode polarity are correct. A numeric model of the same circuit gives the same result as the saved graph: −21.33 W to 9.20 W, with the peak at 9.204 W and 2.57 V.

**How the model works.**

- Three Constant blocks give the irradiance of each cell. Simulink-PS Converter blocks change these Simulink signals into physical signals.
- Each Solar Cell block is a single-diode model: a current source Iph in parallel with a diode. Iph is proportional to the irradiance: 7.34 A, 3.67 A, and 1.47 A. Rs = 0 and Rp = ∞ make the cell ideal, so the current steps are flat.
- The cells are in series. The same current flows through each cell, and the voltages add.
- Each bypass diode is antiparallel to one cell. The cell voltage holds the diode in reverse bias. When the string current is more than the photocurrent of a cell, the cell voltage goes negative and the diode conducts the excess current.
- Electrical Reference is the ground. Solver Configuration holds the settings of the physical network solver. Each Simscape network needs one of each.
- The Current Sensor is in series between the string and the load. The Voltage Sensor is across the string. The Product block calculates P = V × I. The XY Graph plots P against V.
- The Controlled Voltage Source is an ideal voltage source. Its voltage follows its input signal, and the ramp drives it at 0.2 V/s. The source sets the string voltage, and the PV curve gives the current. The source absorbs the power, like an electronic load in constant-voltage mode. Above Voc, the source pushes current into the cells.
- The circuit has no inductors or capacitors. Each instant is a DC operating point. The time only moves the voltage.

**Problems.**

1. The bypass diodes use the library default values, Vf = 0.6 V and Ron = 0.3 Ω. At 7.3 A, the two bypassed diodes drop 1.7 V + 2.4 V. This is more than the 2 V of the lit cell, so the first peak goes below 0 V. The model shows 2 peaks, not 3. Section 7 gives the peaks with the 15SQ045 values and the full explanation. The saved model shows a global peak that is 25 % too low and at the wrong voltage.
2. Each cell has Voc = 2 V, Rs = 0, and Rp = ∞. A silicon cell has a Voc of about 0.6 V. For the study, use the module datasheet. Set N_series to the number of cells in one bypass group. Use Rs and Rp from the five-parameter fit.
3. The ramp goes to 6.0 V, but the string Voc is 5.91 V. Above Voc, the source pushes current into the cells. This causes the −21 W dip at the end of the graph. Stop the ramp at about 5.9 V.

## 4. Boost converter model (old/MPPT_boost.slx, superseded)

**Files in the project folder.**

- build_mppt_boost.m builds the model from MPPT.slx. It does not change MPPT.slx.
- set_realistic_diodes.m gives diode blocks the values of a 15SQ045 Schottky diode. The build script uses it.
- MPPT_boost.slx is the output, saved in R2025b format.

The boost converter replaces the controlled voltage source. The PV-side voltage sensor and current sensor stay in place, because the MPPT needs PV-side values.

| Part | Value | Reason |
|---|---|---|
| C_in | 220 µF | PV voltage ripple less than 1 % |
| L | 150 µH, 10 mΩ | current ripple about 18 % at the MPP |
| Switch | MOSFET (Ideal, Switching), 20 kHz, Rds 10 mΩ | |
| Diode | Vf 0.4 V, Ron 0.01 Ω | similar to a Schottky diode |
| C_out | 470 µF | output ripple less than 1 % |
| R_load | 10 Ω | R_load(1 − D)² covers 10 Ω to 0.06 Ω, so the full curve is reachable |
| Gate drive | duty compared with a 20 kHz sawtooth, then a gain of 10 V | the MOSFET block turns on above 2 V |

The duty source is a block with the name "Duty ramp (replace with MPPT)". It ramps from 0 to 0.92 over 0.6 s. The model logs Vpv, Ipv, Ppv, Vout, and D once per switching period. The solver is the Simscape local solver (Backward Euler) with a fixed step of 0.5 µs.

**Verification results.**

- The netlist in the saved file is correct.
- A 0.6 s run takes about 100 s on the local machine.
- With the library default diodes, the traced P-V curve is on the original sweep. The peak is 9.204 W at 2.57 V at a duty of 0.739. The formula R_load(1 − D)² predicts 0.732. Converter losses cause the difference.
- With the 15SQ045 diodes (28 September 2026), the trace is within 0.004 W of the sweep. The global peak is 12.258 W at 3.379 V, at a duty of 0.694 and Vout = 10.7 V. A run takes about 70 s.

**Known limits.**

- Simulink cannot export Simscape Electrical models to an earlier release. A teammate with R2024b must run build_mppt_boost.m in R2024b. The script was tested only in R2025b.
- The script gives the bypass diodes and the boost diode the 15SQ045 values. Set USE_REALISTIC_DIODES = false to keep the library default values in the bypass diodes.
- The duty resolution is 1 % (a 0.5 µs step at 20 kHz). For finer steps, halve Ts. The run time then doubles.
- With the resistive load, the operating point settles with the output time constant: 10 Ω × 470 µF = 4.7 ms. One applied operating point costs about 15 ms to 25 ms. This is inside the 1 ms to 50 ms range in Chapter 11. A battery load settles in about 1 ms.

## 5. Built-in DC-DC converter blocks in MATLAB R2025b

Simscape Electrical library path: ee_lib > Semiconductors & Converters > Converters.

| Library | Block | Description | Use for MPPT |
|---|---|---|---|
| Simscape Electrical | Buck-Boost Converter | Switching model. Two variants: inverting (default, negative output) and four-switch (non-inverting). Contains Lf and Cf, but no input capacitor. Switch types: ideal, MOSFET, IGBT, GTO, thyristor, averaged. Gate input G. | Yes. MPPT_2.slx uses it. |
| Simscape Electrical | Boost Converter, Buck Converter | Switching models with the same structure. | Yes (boost). |
| Simscape Electrical | Average-Value DC-DC Converter | No switching. Type: buck, boost, or buck-boost. Control: duty cycle, current, or voltage. Implementation: "behavioral" or "average-value". DutyCycle input. | Yes, for algorithm development. MPPT_avg.slx uses it. |
| Simscape Electrical | Bidirectional DC-DC Converter | Non-isolated, isolated, or dual active bridge. | No. A PV array only delivers power. |
| Simscape Electrical | DC-DC Converter | Holds its output at a set voltage. | No. The MPPT must control the PV-side operating point. |
| Simscape Electrical | One-, Two-, and Four-Quadrant Chopper, Average-Value Chopper | Choppers for DC motor drives. | No. |
| Specialized Power Systems (sps_lib) | Boost Converter, Buck Converter, Two-Quadrant DC/DC Converter, PWM Generator (DC-DC) | No buck-boost block. This library uses a different modeling engine. | Do not mix its converters with the Simscape model. The PWM generator is not tested in a Simscape model. |
| Powertrain Blockset | Bidirectional DC-DC | Vehicle-level efficiency model, not a circuit. | No. |

The Simscape foundation library, Simscape Battery, and Motor Control Blockset have no converter blocks.

Shipped examples: elec_conv_BoostConverter.slx and elec_conv_PVArray.slx.

MPPT_boost.slx uses discrete parts. They show each component that the MPPT depends on, and they match the hardware boost board. The built-in Boost Converter block gives the same circuit with fewer blocks.

## 6. Team model update (MPPT_2.slx, 28 September 2026)

The team removed the voltage source and the ramp. They added the built-in Buck-Boost Converter block (inverting variant, library defaults), a Pulse Generator (10 kHz, 50 %, amplitude 1), and a 1 Ω resistor. The PV string, the sensors, and the XY graph did not change. The solver is still ode23t with a stop time of 30 s.

The choice of a buck-boost is valid. It shows the array R_in = R_load((1 − D)/D)², which covers 0 Ω to infinity. With 1 Ω, the MPP (0.72 Ω) is at D = 0.54.

Results of 20 ms simulation runs:

| Case | Vpv | Mean Ppv |
|---|---|---|
| As saved | 5.911 V, constant (open circuit) | 0 W |
| Gate amplitude 10 V | 0.004 V to 5.911 V every cycle | 5.19 W |
| + Lf 150 µH, Cf 470 µF | 0.11 V to 5.91 V every cycle | 6.94 W |
| + C_in 220 µF | 2.82 V to 3.32 V | 6.83 W, at 3.09 V and 2.24 A |

Problems and fixes:

1. The gate signal is 1 V. The switch threshold Vth is 6 V. The switch never turns on. The saved XY graph shows the same result: the voltage stays at 5.911 V. Set the pulse amplitude to 10.
2. The model has no input capacitor. A buck-boost takes input current only while the switch is on. The PV voltage then jumps between short circuit and open circuit. Add C_in across the PV terminals. At 10 kHz, 220 µF gives a ripple of 0.5 V. Use a higher frequency or about 1 mF for less ripple.
3. Lf = 1 µH and Cf = 0.1 µF are library defaults. At 10 kHz, the 1 µH inductor has a ripple of about 150 A. Use about 150 µH and 470 µF.
4. The block diode has Vf = 0.8 V, but |Vout| is only about 2.3 V with a 1 Ω load. The loss is large. Use a higher load resistance, for example 10 Ω, with the MPP near D = 0.79.
5. A stop time of 30 s at 10 kHz with a variable-step solver is very slow. Use less than 1 s and the Simscape local solver with a fixed step.
6. The output voltage is negative, because the block uses the inverting topology.
7. The hardware plan in old/abstract_ieee.tex is a boost converter. The simulation converter should match the hardware.

## 7. Realistic diodes (28 September 2026)

The diode blocks keep the piecewise-linear model. Only three values change. The part is the 15SQ045, a 45 V, 15 A Schottky rectifier for PV junction boxes.

| Datasheet value (Diotec 15SQ045-3G, 25 °C) | |
|---|---|
| VRRM | 45 V |
| IF(AV) | 15 A |
| IFSM | 290 A |
| VF | 0.43 V at 5 A, 0.55 V at 15 A |
| IR | 200 µA at 45 V (25 °C), 10 mA at 45 V (100 °C) |
| Cj | 720 pF at 4 V |

| Block value | Default | 15SQ045 |
|---|---|---|
| Forward voltage Vf | 0.6 V | 0.37 V |
| On resistance Ron | 0.3 Ω | 0.012 Ω |
| Off conductance Goff | 1e-8 S | 4.4e-6 S |

A straight line through the two VF points gives Vf and Ron. The leakage at 45 V gives Goff.

Voltage sweep of MPPT.slx with the 15SQ045 values:

| Peak | Default diodes | 15SQ045 |
|---|---|---|
| Step 1 (only the 1000 W/m² cell produces) | not visible | 7.25 W at 1.03 V |
| Step 2 | 9.20 W at 2.57 V (global) | 12.26 W at 3.38 V (global) |
| Step 3 (all cells produce) | 8.30 W at 5.69 V | 8.30 W at 5.69 V |

**Why the default diode removes a peak.** The default diode is not ideal. It has more loss than a real bypass diode. An ideal diode (0 V drop) also gives three peaks. The ideal values come from a numeric model of the same circuit, not from Simulink.

| Bypass diode | Peak 1 | Peak 2 | Peak 3 |
|---|---|---|---|
| Ideal (0 V drop) | 13.30 W at 1.85 V | 13.70 W at 3.77 V | 8.30 W at 5.69 V |
| 15SQ045 | 7.25 W at 1.03 V | 12.26 W at 3.38 V | 8.30 W at 5.69 V |
| Default | none | 9.20 W at 2.58 V | 8.30 W at 5.69 V |

The string current sets which cells generate. Each step of the I-V curve gives one peak.

| String current | Generating cells | Bypassed cells | Step |
|---|---|---|---|
| 3.67 A to 7.34 A | 1000 W/m² | 500 and 200 W/m² | 1 |
| 1.47 A to 3.67 A | 1000 and 500 W/m² | 200 W/m² | 2 |
| less than 1.47 A | all | none | 3 |

On each step, the string voltage is the sum of the generating cell voltages minus the drops of the conducting bypass diodes. Each diode carries I − Iph of its cell. A peak shows only if this voltage is more than 0 V.

Voltage budget at 7 A (step 1):

| | Ideal | 15SQ045 | Default |
|---|---|---|---|
| 1000 W/m² cell | +1.88 V | +1.88 V | +1.88 V |
| Diode across the 500 W/m² cell (3.3 A) | 0 V | −0.41 V | −1.60 V |
| Diode across the 200 W/m² cell (5.5 A) | 0 V | −0.44 V | −2.26 V |
| String voltage | +1.88 V | +1.04 V | −1.98 V |

Step 1 has one generating cell, two conducting diodes, and the highest diode currents. Thus it fails first. With the default diode, step 1 is between −4.1 V (at 7.34 A) and 0 V, below the start of the sweep. Step 2 has one conducting diode, so it only becomes smaller. Step 3 has no conducting diode, so it does not change. The effect is large in this model because each cell is only 2 V. In a real module, one bypass diode covers about 20 cells (about 12 V).

Earlier values of 6.95 W at 0.99 V and 12.17 W at 3.36 V came from a numeric model with round values (0.4 V, 0.01 Ω). The values in this section replace them.

**Why the 15SQ045.** The bypass current in this model goes up to 5.9 A. The IEC 61215 bypass diode thermal test uses 1.25 × Isc (9.2 A). A 15 A rating gives margin. A Schottky diode has a low forward voltage. A 1N4007 is not suitable: it is a 1 A, 1000 V silicon rectifier with a forward voltage of about 1 V.

## 8. Averaged converter model (MPPT_avg.slx, 28 September 2026)

MPPT.slx and MPPT_2.slx still have the library default diodes. Only the models that the build scripts make have the 15SQ045 values.

build_mppt_avg.m makes MPPT_avg.slx from MPPT_2.slx. MPPT_2.slx does not change. The script makes these changes:

1. It replaces the Buck-Boost Converter with the Average-Value DC-DC Converter. The settings are: implementation "average-value", type "buck-boost", control "duty cycle", Lf = 150 µH, Rl = 10 mΩ, Cf = 470 µF.
2. It replaces the Pulse Generator with a duty ramp from 0 to 0.95 over 1 s. The ramp drives the DutyCycle input directly. There is no PWM.
3. It adds C_in = 220 µF across the PV terminals.
4. It gives the bypass diodes the 15SQ045 values.
5. It keeps the 1 Ω load, the ode23t solver, and the XY graph. The maximum step is 0.1 ms.

Results:

| Item | Value |
|---|---|
| Run time for 1 s of simulation | about 5 s (the switching boost model needs 70 s to 100 s) |
| Difference from the static sweep | less than 0.005 W |
| Peak 1 | 7.25 W at 1.03 V, D = 0.737 |
| Peak 2 (global) | 12.26 W at 3.38 V, D = 0.514 (the ideal formula gives 0.509) |
| Peak 3 | 8.30 W at 5.69 V, D = 0.339 |
| Output voltage at the global peak | +3.43 V (positive, not inverted) |
| Duty step 0.45 to 0.514 | Vpv settles to 2 % in about 4 ms, with one dip to 3.21 V |

The "behavioral" implementation gives the same curve with 100 % efficiency and no inductor loss. Use "average-value", because it includes the L-C dynamics that set the settling time.

**How to see the outputs.**

1. Open MPPT_avg.slx in R2025b. Open the XY Graph block, then click Run. The XY Graph plots Ppv against Vpv.
2. After the run, the variable out is in the base workspace. It holds Vpv, Ipv, Ppv, Vout, and D as timeseries, sampled every 0.5 ms. The model has no Scope block.
3. For the internal variables of each block, set Model Settings > Simscape > Data logging to "All", run the model, then use sscexplore(out.simlog).

**Start-up transient.** At t = 0, C_in is at 0 V and the duty is almost 0. The array charges C_in to Voc in less than 1 ms. The sample at 0.5 ms is on the way up: 5.69 V and 8.30 W. A plot that joins the samples in time order then shows a false line from the origin (P-V plot) or a spike at D = 0 (P-D plot). Remove the first 10 ms before you plot:

```matlab
k = out.Vpv.Time > 0.01;
V = out.Vpv.Data(k); P = out.Ppv.Data(k); D = out.D.Data(k);
figure; plot(V, P); xlabel('Vpv (V)'); ylabel('Ppv (W)'); grid on
figure; plot(D, P); xlabel('Duty');    ylabel('Ppv (W)'); grid on
[Pmax, i] = max(P); [Pmax, V(i), D(i)]
```

## 9. Control structure: command, actuator, and measurement

Each model has three functions.

| Function | MPPT.slx | MPPT_2.slx and MPPT_avg.slx | Final system |
|---|---|---|---|
| Command: selects the operating point | Ramp | Duty ramp | MPPT controller |
| Actuator: moves the array to the operating point | Controlled voltage source | DC-DC converter | DC-DC converter |
| Measurement | V and I sensors | V and I sensors | V and I sensors, as inputs to the MPPT |

- The ramp drives the actuator. The actuator does not drive the ramp.
- The current sensor is between the string and the converter input, before C_in. It measures the PV current, which the MPPT needs. The MPPT does not need a current sensor on the converter output.
- A voltage source with a voltage that follows its own current (V = k × I) is a resistor of k ohms. It gives one fixed operating point. The measurements must go to a controller, and the controller sets the next command.
- At this time, all models are open loop. The sensors only feed the XY graph.

## 10. MPPT implementation plan (discussion, 28 September 2026)

No MPPT code exists yet. The plan:

1. **Interface.** The MPPT gives a voltage reference, not a duty. An inner PI loop compares Vpv with the reference and sets the duty. Reasons: the window tracker works in voltages, the inner loop holds the voltage for any load, and the tuning of the inner loop sets the settling time. In a boost or buck-boost converter, a higher duty lowers Vpv. Thus the PI loop must use the reverse sign. Limit the duty and prevent integrator windup. Direct duty control is simpler, but the duty-to-voltage relation then changes with the load.
2. **Timing.** The MPPT runs at a fixed sample rate that is slower than the settling time of the inner loop. At each sample, it reads the averaged V and I, calculates P, and gives the next reference. Each sample is one applied operating point.
3. **Structure.** The tracker is a state machine: track (small P&O or INC steps at the present peak), trigger (a sudden change in power, or a timer), global scan (two probes in each bypass window), select, refine (golden-section search in the best window), then back to track.
4. **Baselines.** P&O, INC, PSO, GA, and the ANN-seeded PSO use the same interface, timing, and measurements. Only the rule that selects the next reference changes. This makes the comparison fair.
5. **Simulink block.** Use a MATLAB Function block with persistent variables for the state. Run it at the MPPT sample rate. Stateflow and the code generation products are not installed on the local machine.
6. **Order of work.** First, the inner voltage loop with a manual reference. Then plain P&O. Then the window tracker. Then the baselines. Then test cases with Step blocks in place of the irradiance Constant blocks, so that the shading changes during a run. The final check is in the switching model.
7. **Optional testbench.** Test the tracker first on the structure of MPPT.slx. The MPPT reference then drives the controlled voltage source directly, with no converter and no PI loop.

**Change on 29 September 2026.** The team decided to show only that plain P&O fails first. MPPT_4x4.slx therefore uses P&O on the duty cycle, with no voltage loop (item 1 does not apply to it yet). A linear model of the averaged converter showed that a single PI loop from Vpv to duty is lightly damped near the MPP, because of the resonance of L and C_in. A method that needs a voltage reference (for example M3 in test.docx) needs a cascade instead: an outer Vpv loop that sets an input-current reference, and an inner current loop that sets the duty. Details are in Notes/pv4x4_shading_and_po.md.

## 11. Open items

1. Done: the generated models use the 15SQ045 values (section 7).
2. Put the 15SQ045 values into MPPT.slx and MPPT_2.slx. A teammate with R2024b can run set_realistic_diodes(bdroot) and save.
3. Decide if the hardware is boost or buck-boost. Set converter_type in MPPT_avg.slx to match. For a boost, increase the load to about 10 Ω.
4. Done for P&O and INC (29 September 2026): MPPT_4x4.slx, both on the duty cycle. Results are in Notes/pv4x4_shading_and_po.md. The next algorithms are the four methods in test.docx.
5. Done for the 4 x 4 models (29 September 2026): Emmvee E325P72, 72 cells, 3 bypass diodes, fitted to the datasheet (Literature/Emmvee_PV_Module_Brochure_E325P72_p4.pdf). MPPT.slx, MPPT_2.slx, and MPPT_avg.slx still use the simplified cells.
6. Verify the search-skip-judge citation and the Chapter 11 claim about the capacitor-transient sweep.
7. Update Objective 2 in old/abstract_ieee.tex to name the proposed method.
8. Optional: add a Scope block to MPPT_avg.slx.
