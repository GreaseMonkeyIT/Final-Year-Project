---
title: Plans after the Simulink baseline
date: 2026-11-21
status: plans. The baseline is done. Each plan needs the approval of the user before work starts.
---

# Plans after the Simulink baseline

These plans start after the baseline runs of the new trackers (algorithms 3 to 7) in Simulink. The baseline uses the code of `fable_controller/` with no tuning. Each plan below is measured against that baseline.

## 1. Fixes for the weak points of DIRECT

DIRECT keeps every old sample. If the irradiance changes during a search, the old samples are wrong, and DIRECT cannot see this. One bad sample, for example a probe that did not settle, also stays in the store for the full search. PSO and GWO measure each particle again in each iteration, so they do not have these two problems.

The fixes below are options in the `mppt` struct. They apply to Idea B and Idea C only. The DIRECT of Nguyen and Low (algorithm 3) stays as the paper gives it, so that it stays a fair baseline.

| Fix | What it does | Cost |
|---|---|---|
| Anchor probe | Each k probes, the search measures the best duty again. If the power changed by more than a limit (for example 5 %), the curve changed, and the search starts again | 1 probe each k probes (k = 4 gives about 25 % more probes) |
| Rescale (option) | For a uniform change, the anchor gives a ratio r. The search multiplies the stored powers by r and continues | none |
| I-V order check | On a PV string, the current does not rise when the voltage rises. A sample that breaks this order is measured again | 0 probes, if no sample breaks the order |
| Settling check | The search accepts a probe only if the voltage in the last quarter of the probe is steady. If not, the probe gets one more quarter | 0 to 1 quarter probe |
| Final check | Before the hand-over, the search measures the two or three best samples again and takes the best | 2 to 3 probes |

Test: each fix on and off, on the nine patterns and on the change tests of plan 3. The report gives the extra probes and the energy that each fix saves.

The ceiling check (Ideas B and C) and the variable-step INC (all searches) already cover two other weak points of DIRECT: it has no natural stop, and its last climb to the peak is slow.

## 2. Other checks on the trackers

1. **GWO sensitivity.** Done on 2026-11-21, with PSO also. With 50 seeds, GWO with 3 wolves and PSO with 3 particles handed over on a wrong peak in 5.6 % and 10.7 % of the static runs. The config now has 6 wolves and 8 particles, with 0 % (`gmppt_local_stage_2026-11-21.md`, section 3). Each evaluation reports PSO and GWO over many seeds, with the worst case.
2. **Hold band of the variable-step INC.** The baseline uses `eps_inc` = 0.30, the value of the INC of `mppt.alg` = 2. In 11 of the 45 baseline runs with the variable-step INC, the tracker held 0.06 to 0.56 points below the GMPP because the hand-over point was already in the hold band (`gmppt_baseline_2026-11-21.md`, section 5.1). Test 0.05, 0.10 and 0.15 with a new field for the local stage only, so that the INC of `mppt.alg` = 2 stays as in the mid-review.
3. **Settling of the first local period.** After a large jump from the last probe to the hand-over duty (PSO and Idea C on R1, all GWO runs), the first local periods of 20 ms measure the converter before it settles. Options: one hold period of `Tsearch` at the hand-over duty before the local stage starts, or a first local period of `Tsearch`.
4. **Slow changes.** Done in part on 2026-11-21: on a ramp of 30 W/m² per s, the VS-INC with `restart_ref` = 1 does not move (51 % to 57 %). The parabolic stage (`local` = 3) gives 99.9 % or more after Ideas B and C (`gmppt_local_stage_2026-11-21.md`, section 6.3).
5. **Restart reference.** The baseline uses `restart_ref` = 1. Both references gave equal results on step changes. Compare them on slow changes of irradiance.

## 3. Weather and cloud simulation

### 3.1 Aim

Test the trackers on real weather: moving clouds, changes of irradiance, and slow shadows. The present patterns are static.

### 3.2 Why EPW files alone are not sufficient

An EPW file (EnergyPlus weather file) gives one value per hour. A search takes 0.5 s to 2.5 s, and a cloud edge crosses a 4 x 4 array in about 1 s. Hourly data averages these events away. Most EPW files are also typical years: each month comes from a different real year. An EPW file gives one point, so it has no change across the array.

An EPW file is correct for the slow background: the position of the sun, the temperature and the diffuse part of the light. Files for sites in India are available (ISHRAE data, climate.onebuilding.org).

### 3.3 Data sources

| Source | Data | Use | Status |
|---|---|---|---|
| EPW file for the NIT Andhra Pradesh area | Hourly irradiance, temperature, sun position | Background of each day | To find |
| NREL Oahu Solar Measurement Grid | About 17 sensors, 1 s samples, over about 1 km, 2010 to 2011 | Speed, direction, edge width and depth of cloud shadows. Cloud enhancement | Details to be verified |
| EN 50530 dynamic MPPT test | Irradiance ramps, slopes from about 0.5 to 100 W/m² per s | Standard test of the tracking of a change, and of false restarts | Profiles to be verified |
| NIWE SRRA stations (India) | 1 min data | Local statistics, if access is given | Access by request |

### 3.4 Cloud model

1. The EPW file sets the base irradiance, the temperature and the sun position for each hour.
2. A cloud shadow is an edge that moves across the array. Its inputs are the speed, the direction, the width of the edge and the depth of the shade.
3. The position of each panel gives its irradiance at each time.
4. The statistics of the inputs come from the 1 s data of the Oahu grid.
5. Near a cloud edge, the irradiance can be 1.2 to 1.5 times the clear-sky value for a short time (cloud enhancement). The model includes this.

### 3.5 Two time scales

A full day in the Simulink model takes tens of hours of computer time. The evaluation therefore has two parts:

1. **Short Simulink windows** of some seconds around each cloud event. The converter dynamics are important here.
2. **A quasi-static model of full days** that uses the static I-V curves, as the static plant of the Fable review does. It gives the daily energy and shows how frequently the periodic rescan is necessary. The slow shadow of a tree or of the row in front moves over hours, so this model tests the rescan.

## 4. Real-time target: OPAL-RT OP5707 and TI C2000

### 4.1 Aim

Run the trackers on the hardware of the course: the plant on the OPAL-RT OP5707 and the tracker on a TI C2000 board (controller hardware-in-the-loop, HIL). This shows that the code works on a low-cost controller with real ADC noise and real timing.

### 4.2 Steps

1. **Real-time simulation.** Run the full model (plant and tracker) on the processor cores of the OP5707 with RT-LAB. This shows that the tracker meets its real-time limits.
2. **Controller HIL.** The OP5707 runs the PV array and the converter. Its analog outputs send V and I to the C2000. The C2000 runs the tracker and sends the PWM signal back to a digital input of the OP5707.

### 4.3 Items to find before the plan

1. The version of RT-LAB on the lab computer, and the MATLAB releases that it supports. R2025b can be not supported. R2024b (the team release) is more probable.
2. The I/O cards of the OP5707.
3. The C2000 board (for example F28379D or F280049C LaunchPad).
4. The library of the PV array block in the model. OPAL-RT supports Specialized Power Systems blocks best. Simscape blocks run on the processor with fixed-step solvers.
5. Access to Embedded Coder and the TI C2000 support package (campus license). Only MATLAB Coder and Simulink Coder are installed now.

### 4.4 Changes to the code for the C2000

1. Use `single` in place of `double` for the `mppt` struct and the signals. No method needs double precision.
2. Move the 50 µs averaging into the ADC interrupt.
3. Use the high-resolution PWM of the C2000. The variable-step INC needs steps of 0.001 in duty, so the PWM needs at least 10 bits of resolution at the switching frequency.
4. RT-LAB needs its own layout of subsystems (`SM_` for computation, `SC_` for the console). The build scripts make this layout, so no model is changed by hand.

### 4.5 Expected load

Each search uses less than 0.1 ms of arithmetic in each 20 ms MPPT period, also on a controller with no floating-point unit. The store of DIRECT, Idea B and Idea C needs 768 bytes in single precision. The C2000 has much more capacity than the trackers need.

## 5. Order

Since 2026-11-21, `final_test_plan.md` replaces this order. It covers plans 2 and 3 and the random cases.


1. Baseline in Simulink. Done on 2026-11-21 (`gmppt_baseline_2026-11-21.md`).
2. Plan 2 (other checks) and plan 1 (fixes), with the approval of the user for each change.
3. The 1800 random cases in Simulink, in parallel on 4 workers (RAM limit of 10 to 12 GiB, `experiments/sim_pool.m`).
4. Plan 3 (weather and cloud simulation).
5. Plan 4 (real-time target), when the lab items of 4.3 are known.
