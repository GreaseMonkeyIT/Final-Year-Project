---
title: Final test bench (phase 0)
date: 2026-11-21
status: built and checked on 2026-11-21. Gates 0.1, 0.2 and 0.3 pass. Gate 0.6 runs.
---

# Final test bench (phase 0)

This note describes the test bench of the final tests (`final_test_plan.md`, section 3) and the result of each pass gate. The user started the work on the evening of 2026-11-21.

## 1. Changes to the code and the models

| Item | Change | Files |
|---|---|---|
| Local stage of the searches | `p.local` = 3 (parabolic stage) for all five searches. Before: `[2 2 3 3 3 2 2 2]` (PSO and GWO used the variable-step INC). | `src/config/pv4x4_config.m` |
| New local stage 4 | The INC of the mid-review (`p.alg = 2`) as a local stage, with the step `p.dD`, the hold band `p.eps_inc` and the current band `p.eps_di`. The first local period makes one step with no test, as stages 1 and 2. On 2026-11-22 the current test after a hold of stages 2 and 4 (and of `p.alg = 2`) was changed: it uses the change since the first period of the hold. | `src/controller/mppt_controller.m` |
| State reset | `p.reset = 1` makes the controller start again from its first state. Only the static bench sets it, on the first call of a run. The models always use 0. | `mppt_controller.m`, `pv4x4_config.m` |
| Cell temperature | The Solar Cell blocks use `TIPH1`, `EG`, `TXIS1`, `TRS1`, `Tmeas` and the run-time temperature `pv_T`. | `build/add_pv_array.m`, `build/pv_workspace_vars.m`, `pv4x4_config.m` |
| Sensors and ADC | New block "Sensors and ADC" between the plant and the controller of `MPPT_4x4.slx` and `MPPT_4x4_grp.slx`. Model variable `sens`. Off by default (`sens.on = 0`). | `build/build_mppt_4x4.m`, `src/plant/sensor_adc.m` |
| Static array model | The equations of the Solar Cell block and the bypass diode in MATLAB, for any irradiance of each group and any temperature. | `src/plant/pv_array_curve.m` |
| Static closed loop | The controller, the sensor model and the static plant in one function, compiled with MATLAB Coder. A run of 4 s takes about 1 ms. | `src/plant/static_run.m`, `build/build_static_mex.m` |

The four models were made again with the build scripts on 2026-11-21. Copies of the old files are in the scratch folder of the session.

Speed. The first build made the cell temperature a run-time parameter of Simscape (`TFIXED_conf = runtime`), so that a new temperature needs no new compilation. That made `MPPT_4x4.slx` 60 % slower: 31.3 s against 19.6 s for 2 s of R1 with DIRECT (one process, second run). The first regression run took 949 s for 73 runs. The build now keeps the temperature a compile-time parameter, and the speed is that of the model before the bench (19.6 s against 19.3 s). The sensor block adds no measurable time. A run at a new temperature compiles the network again, which takes a few seconds. Gates 0.1 and 0.3 ran with the run-time parameter. The equations are the same in both modes.

## 2. Gate 0.1: temperature

The datasheet of the Emmvee E325P72 gives Voc -0.34 %/K, Isc +0.05 %/K and Pmax -0.40 %/K. `TIPH1` = 5e-4 /K is the Isc coefficient. `EG` = 1.11 eV is the default of the block. `build/fit_temperature.m` finds `TXIS1` = 6.41 from the Voc coefficient (the block default is 3).

`experiments/check_bench.m` sweeps `PV4x4_sweep.slx` with P0 at 25, 45 and 65 °C:

| Value | Model | Datasheet | Difference |
|---|---|---|---|
| Voc | -0.3399 %/K | -0.34 %/K | 0.0 % |
| Isc | +0.0500 %/K | +0.05 %/K | 0.0 % |
| Pmax | -0.4204 %/K | -0.40 %/K | -5.1 % |

Pmax is 5194.1 W, 4761.8 W and 4320.6 W. The gate (each coefficient within 10 %) passes. A value of `TRS1` above 0 moves Pmax further from the datasheet, so `TRS1` stays 0.

## 3. Gate 0.2: sensors and ADC

### 3.1 Parts (assumptions)

| Part | Value | Source |
|---|---|---|
| ADC | TMS320F28379D, 12-bit single-ended, VREFHI = 3.0 V. Gain error ±3 LSB, offset ±2 LSB, INL ±1 LSB (typical). SNR 69.1 dB, ENOB 11.2 bits | TI SPRS880P, section 6.10.1.2.4 |
| Voltage sensor | Divider and AMC1311, input range 0 V to 2 V, then a gain of 1.5 to the ADC. 200 V full scale. Gain error 0.4 %, offset 0.4 mV, output noise 220 µV rms, bandwidth 220 kHz (typical) | TI AMC1311 datasheet (SBAS786C) |
| Current sensor | LEM LA 55-P, 1:1000, RM = 56 Ω, 53.6 A full scale. Error ±0.65 % at 50 A, offset ±0.2 mA, bandwidth 200 kHz. The datasheet gives no noise value | LEM datasheet, version 17 (2018) |

The ADC noise other than the quantization comes from the SNR: 0.508 LSB rms of total noise, minus 0.289 LSB of quantization, gives 0.42 LSB rms. The bandwidth of both sensors (200 kHz and more) is much higher than the sample rate (20 kHz), so the model has no sensor filter. One resolution step is 48.8 mV on the array voltage and 13.1 mA on the array current.

### 3.2 Result

| Check | Result |
|---|---|
| ADC alone, full-scale sine | SNR 69.0 dB (datasheet 69.1 dB), noise 0.513 LSB rms |
| Voltage at 150 V, typical errors | mean error +0.590 % (expected +0.589 %), noise 0.033 V rms |
| Current at 30 A, typical errors | mean error +1.521 %, noise 6.9 mA rms |
| Power noise | 0.032 % rms for each sample |
| Switch off | the exact values come back |

Limits (norms check, 2026-11-23). The 1 x noise has only the datasheet noise of the sensors and the ADC. The converter model is averaged, so it has no switching ripple and no interference, which real hardware adds. The 10 x and 30 x levels of phase p3n stand for this larger noise. TI measures the ADC values at VREFHI = 2.5 V. The model uses 3.0 V.

The gate passes. The noise of one sample is small: the average over one MPPT period (200 samples) has about 0.002 % rms. The static errors (gain and offset) are larger than the noise. A gain error does not move the peak, because the controller compares powers that have the same error.

## 4. Gate 0.3: static array model

`pv_array_curve.m` against the Simscape sweep, GMPP power:

- 90 cases: the nine patterns at 25, 45 and 65 °C and at 100 %, 60 % and 30 % of their irradiance (81 cases), and the three group patterns at 3 temperatures on `PV4x4_sweep_grp.slx` (9 cases).
- Mean difference 0.0001 %, largest 0.0014 % (P3, 65 °C), largest voltage difference 0.034 V.
- The gate (0.2 %) passes. The 90 sweeps took 318 s on 4 workers.

The static closed loop (`static_run.m`) gives the Simulink results of `results/gmppt_local3.mat` (parabolic stage after DIRECT, Idea B and Idea C, nine patterns): the final power is the same within 0.001 points in all 27 runs, and the hand-over time is the same in 26 runs. In the other run (Idea C on P0) the static bench hands over 0.08 s earlier: one probe differs, because a probe in Simulink has a small settling error.

## 5. Step 0.4: irradiance sources

| Source | Status |
|---|---|
| Nine patterns, three group patterns | `shading_patterns.m`, `shading_patterns_grp.m` |
| Random patterns | `src/config/random_patterns.m`: 300 panel, 300 edge and 300 group patterns, with the rules of the preliminary study. MATLAB draws other numbers than NumPy, so the set is a new sample of the same kinds. |
| EN 50530 ramps | All rows of both sequences, from a TÜV Rheinland test report that lists them (report CN21VE2D 001, EN 50530:2010+A1:2013). The row 30 W/m²/s of the sequence 30 % to 100 % is the row that Andrean et al. (2018) use. |
| Oahu data | Four months (2010-07, 2010-10, 2011-01, 2011-04) in `data/oahu` (not in git: the data may not be distributed again). Fit: `experiments/oahu_fit.m`. |
| Cloud events | `src/config/cloud_events.m`: a moving straight edge with values drawn from the Oahu fit. |
| Weather days | TMYx file of Gannavaram (Vijayawada airport, 2011-2025) in `data/epw` (not in git). |

## 6. Step 0.5: metrics

`experiments/bench_metrics.m` gives the dynamic efficiency of Andrean et al. (2018), Eq. (10), the searches and their length, and the lost energy in three parts: during the searches, in the local stage on the global peak, and in the local stage on a wrong peak. `static_run.m` also counts the searches and the search loss at each control sample.
