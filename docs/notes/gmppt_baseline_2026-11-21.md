---
title: Simulink baseline of the global searches
date: 2026-11-21
status: baseline. No value was tuned. Results in results/gmppt_baseline.* and results/gmppt_restart_tests.*
---

# Simulink baseline of the global searches

## 1. Scope

This note gives the first Simulink results of the five global searches in `MPPT_4x4.slx`:

- 3 DIRECT (Nguyen and Low 2010)
- 4 Idea B refined
- 5 Idea C
- 6 PSO (Ishaque et al. 2012)
- 7 GWO (Mohanty et al. 2016)

Each search is an implementation of a published method or of published parts (`gmppt_methods.md`). Each search hands over to a local stage: `mppt.local` = 1 (P&O) or 2 (variable-step INC of Liu et al. 2008, the default). P&O and INC with no search are the references.

All the values come from `src/config/pv4x4_config.m`. No value was tuned after a result. The only change to the delivered code is the margin check of Idea B (`gmppt_review.md`, section 10). It did not open on any pattern of this note.

## 2. Runs

| Script | Runs | Content | Time on 16 workers |
|---|---|---|---|
| `experiments/run_gmppt_baseline.m` | 108 | Set A: each of the nine patterns from start-up, 4 s. Algorithms 1 and 2 once, algorithms 3 to 7 with each local stage. `T_rescan` = 0 | 371 s |
| `experiments/run_gmppt_restart_tests.m` | 30 | Set E: P0 to R1 at 3 s (three variants). Set F: R1 to P0 at 3 s. Set T: P1 for 7 s with `T_rescan` = 1 s. Set C: R1, then P1 at 4 s, then P0 at 8 s | 203 s |

The values of each run are defined in `experiments/gmppt_metrics.m`.

- **Probes** and **search time**: the first search. One probe lasts 40 ms.
- **Hand-over power, static**: the power of the static curve at the hand-over duty, with the converter resistance (R (1 - D)² + R_L) / D². This is the settled power at the hand-over duty.
- **Hand-over power, Simulink**: the mean power 10 ms to 20 ms after the hand-over. This window can include the settling after the jump from the last probe (section 4.2).
- **End power**: the mean power of the last 0.3 s, as a percentage of the global maximum power point (GMPP).
- **V swing**: the peak-to-peak voltage in the last 0.3 s.

## 3. Main results

Summary over the nine patterns, with the variable-step INC as the local stage:

| Method | Probes | Search time [s] | Lowest end power [%] | Mean end power [%] | Mean power in the first 1 s [%] | Mean power over 4 s [%] | Patterns on the global peak |
|---|---|---|---|---|---|---|---|
| P&O | none | none | 34.86 | 86.23 | 42.1 | 75.0 | 6 of 9 |
| INC | none | none | 35.14 | 86.42 | 42.2 | 75.2 | 6 of 9 |
| DIRECT | 11 to 15 | 0.44 to 0.60 | 99.93 | 99.99 | 85.7 | 96.4 | 9 of 9 |
| Idea B | 9 to 16 | 0.36 to 0.64 | 99.84 | 99.94 | 85.7 | 96.4 | 9 of 9 |
| Idea C | 10 to 18 | 0.40 to 0.72 | 99.64 | 99.89 | 83.4 | 95.8 | 9 of 9 |
| PSO | 36 to 60 | 1.44 to 2.40 | 99.69 | 99.95 | 78.7 | 94.1 | 9 of 9 |
| GWO | 30 | 1.20 | 97.22 | 99.56 | 52.7 | 86.6 | 8 of 9 |

1. Each search reached the global peak on each pattern, with one exception: GWO on R1 handed over at the local peak at 72.6 V (97.2 % of the GMPP).
2. DIRECT, Idea B and Idea C used 9 to 18 probes. PSO used 36 to 60 probes and GWO 30 probes. The searches with few probes gave about 2 percentage points more energy over the 4 s run than PSO, and about 10 points more than GWO.
3. Idea B used fewer probes than DIRECT on six patterns, the same number on one, and more on two (P3, R3). Its hand-over power was 0.00 to 0.11 points below DIRECT.
4. Idea C used the most probes of the three on four patterns (P3, R1, R2, R3). It handed over at 99.44 % on R1 (static value).
5. With the variable-step INC, the voltage swing at the end was 0 V in all 90 runs. With P&O as the local stage, it was 4 V to 8.4 V, as in the mid-review.
6. Each run with no change of the pattern made one search only. The local stage never started a new search. The restart-loop fault of the earlier code does not occur.

The full tables for each method and pattern are in section 7.

## 4. Comparison with the static check

`gmppt_review.md`, section 9.1, gives the results of each search on the static plant.

### 4.1 Probes and hand-over duties

The probe counts in Simulink are equal to the static counts in all 45 cases (five searches, nine patterns). The hand-over duties are also equal to three decimals.

Reason: each search uses only the averages of its probes. With 40 ms probes and the average of the last 10 ms, each average is within 0.21 % of the settled value (`pv4x4_shading_and_po.md`, section 5). An error of this size did not change a decision of any search on these patterns.

### 4.2 Power at the hand-over

For DIRECT, Idea B and Idea C, the Simulink value and the static value agree to 0.02 points, with one exception. For PSO and GWO, the values differ by up to 1.4 points. The difference comes from the jump from the last probe to the hand-over duty:

| Method | Jump from the last probe to the hand-over duty (duty) | Largest difference, Simulink against static [points] |
|---|---|---|
| DIRECT | 0 to 0.004 | 0.00 |
| Idea B | 0 to 0.037 | 0.02 |
| Idea C | 0.008 to 0.135 | 0.15 (R1, jump 0.135) |
| PSO | 0 to 0.116 | 0.12 (R1, jump 0.116) |
| GWO | 0.059 to 0.096 | 1.41 (R5) |

DIRECT ends with small divisions around the best sample, so its last probe is near the hand-over duty. GWO ends after the last wolf of the last iteration, which can be far from the alpha wolf. After a large jump, the converter is not settled 10 ms to 20 ms later. This is a property of the measurement window, not of the search. The static value is the settled power at the hand-over duty.

### 4.3 Power at the end

The static check ran 10 to 60 P&O steps after the search, so its end values are not comparable with the variable-step INC. Section 5 explains the end values of the variable-step INC.

## 5. Findings

### 5.1 The hold band of the variable-step INC stops the climb near the peak

In 13 of the 45 runs with `mppt.local` = 2, the tracker holds on the global peak but 0.06 to 0.56 points below the GMPP. Examples: GWO on P3 (99.48 %) and P2 (99.44 %), Idea C on R1 (99.64 %) and R4 (99.75 %), PSO on R1 (99.69 %).

Cause in 11 of the 13 runs:

1. The first local period makes one step of +`vs_dDmin` (0.001) with no test.
2. The INC test then finds |dP/dV| <= `eps_inc` I. With `eps_inc` = 0.30, this is a slope of about 6.7 W/V on P3 (about 22 A). The point is in the hold band, and the tracker holds.
3. In these runs, the hand-over duty was 0.006 or less from the peak. On the flat top of a peak, that is inside the hold band. The tracker therefore holds near the hand-over point and does not climb.

Cause in the other 2 runs (PSO and Idea C on R1): the jump from the last probe to the hand-over duty was large (0.116 and 0.135, section 4.2). The first local periods measured the converter before it settled. The variable step then made steps of up to 0.013 from these readings and came to a hold 0.003 from the peak. The local period of 20 ms with the average of its second half is shorter than the settling time after a large jump.

With P&O as the local stage, the same runs end higher (for example GWO on P3: 99.83 %), but with a voltage swing of 6 V to 8 V.

This is open question 11 of `gmppt_review.md`. The value `eps_inc` = 0.30 comes from the INC of `mppt.alg` = 2, where a narrow band never holds because one fixed step of 0.005 jumps over it. The variable step can make steps of 0.001, so a narrower band can hold. Recommendation for the user: test `eps_inc` = 0.05, 0.10 and 0.15 for the local stage only, with a separate field, so that the INC of `mppt.alg` = 2 stays as in the mid-review. This is a change of a value and needs the approval of the user.

In some of these runs, the first step of +0.001 went away from the peak (for example Idea B on P0 and P2, Idea C on R4 and R5, GWO on P3). The direction of the first step is fixed. The paper of Liu et al. uses a start program that the code does not have (`gmppt_methods.md`, section 7.4).

### 5.2 GWO stops on a local peak on R1

GWO with 3 wolves and 10 iterations handed over at the duty 0.697, on the local peak at 72.6 V, in each run on R1 (sets A, E, F and C). The static check gave the same result. The local stage then holds that peak. This is open question 7. The check with 4 and 5 wolves follows (`plans_after_baseline.md`, plan 2).

### 5.3 PSO uses the longest searches

PSO used 36 to 60 probes (1.44 s to 2.40 s). On R1 and R3 it reached the limit of 20 iterations. The end test `pso_tol` and the limit `pso_itmax` are values of this project (open question 6). PSO handed over at the GMPP duty on each pattern.

## 6. Restart rule and timer

### 6.1 Change of the pattern (sets E, F and C)

- Each method started exactly one new search after each change of the pattern, 20 ms after the change. This is one MPPT period: the first local period after the change has the same duty as the period before it, and the power changed by more than 5 %.
- No search started at another time. Over 25 runs and 55 phases, the local stage did not start a search.
- The new search used the same number of probes as the search from start-up on the same pattern. Each search starts from the same state (`pso_reinit` = 0).
- `restart_ref` = 1 and 2 gave equal results in set E. Both references see a step change. The difference between them is for slow changes (`gmppt_methods.md`, section 8.1). The runs of this note have no slow change.
- In set C (winter morning), each method tracked each of the three phases. The end power in each phase was 99.64 % to 100.00 %, except GWO in the R1 phase (97.22 %, section 5.2).

The detection time of 0.060 s in the first phase of each run is the wait of `mppt.Nwait` = 3 periods at start-up, not a detection.

### 6.2 Timer (set T)

With `T_rescan` = 1 s on P1, each method started a new search after 1 s of the local stage, each time:

| Method | Searches in 7 s | Interval between searches [s] | Search time [s] + 1 s |
|---|---|---|---|
| DIRECT | 5 | 1.56 | 0.56 + 1.00 |
| Idea B | 5 | 1.44 | 0.44 + 1.00 |
| Idea C | 5 | 1.40 | 0.40 + 1.00 |
| PSO | 3 | 2.68 | 1.68 + 1.00 |
| GWO | 4 | 2.20 | 1.20 + 1.00 |

The timer works as specified. The end power of set T is not a result: the last 0.3 s of the run overlap a search for GWO (start at 6.66 s) and for DIRECT (start at 6.30 s, end at 6.86 s).

## 7. Tables for each method and pattern

"Searches" gives the number of searches in the run for the P&O local stage and for the variable-step INC. "Stops on" is the peak nearest to the end voltage.

### DIRECT

| Pattern | Probes | Search time [s] | Hand-over duty | Hand-over power, static [%] | Hand-over power, Simulink [%] | End power, P&O [%] | End power, VS-INC [%] | V swing, P&O [V] | V swing, VS-INC [V] | Searches | Stops on (VS-INC) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P0 | 11 | 0.44 | 0.603 | 100.00 | 100.00 | 99.81 | 99.99 | 8.12 | 0.00 | 1, 1 | global |
| P1 | 14 | 0.56 | 0.639 | 100.00 | 100.00 | 99.80 | 99.98 | 6.11 | 0.00 | 1, 1 | global |
| P2 | 11 | 0.44 | 0.581 | 99.98 | 99.98 | 99.78 | 99.93 | 8.16 | 0.00 | 1, 1 | global |
| P3 | 15 | 0.60 | 0.580 | 99.99 | 99.99 | 99.85 | 100.00 | 6.32 | 0.00 | 1, 1 | global |
| R1 | 15 | 0.60 | 0.574 | 100.00 | 100.00 | 99.51 | 99.97 | 6.25 | 0.00 | 1, 1 | global |
| R2 | 13 | 0.52 | 0.534 | 99.99 | 99.99 | 99.83 | 100.00 | 7.82 | 0.00 | 1, 1 | global |
| R3 | 13 | 0.52 | 0.540 | 100.00 | 100.00 | 99.79 | 99.99 | 8.12 | 0.00 | 1, 1 | global |
| R4 | 11 | 0.44 | 0.589 | 100.00 | 100.00 | 99.82 | 99.99 | 8.17 | 0.00 | 1, 1 | global |
| R5 | 11 | 0.44 | 0.560 | 99.99 | 99.99 | 99.82 | 100.00 | 7.92 | 0.00 | 1, 1 | global |

### Idea B

| Pattern | Probes | Search time [s] | Hand-over duty | Hand-over power, static [%] | Hand-over power, Simulink [%] | End power, P&O [%] | End power, VS-INC [%] | V swing, P&O [V] | V swing, VS-INC [V] | Searches | Stops on (VS-INC) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P0 | 9 | 0.36 | 0.606 | 99.93 | 99.93 | 99.70 | 99.84 | 8.35 | 0.00 | 1, 1 | global |
| P1 | 11 | 0.44 | 0.639 | 100.00 | 100.00 | 99.80 | 99.99 | 6.09 | 0.00 | 1, 1 | global |
| P2 | 9 | 0.36 | 0.582 | 99.95 | 99.95 | 99.73 | 99.87 | 8.23 | 0.00 | 1, 1 | global |
| P3 | 16 | 0.64 | 0.582 | 99.97 | 99.97 | 99.82 | 99.91 | 6.44 | 0.00 | 1, 1 | global |
| R1 | 14 | 0.56 | 0.574 | 100.00 | 100.00 | 99.50 | 99.92 | 6.34 | 0.00 | 1, 1 | global |
| R2 | 11 | 0.44 | 0.533 | 99.95 | 99.95 | 99.80 | 99.99 | 7.74 | 0.00 | 1, 1 | global |
| R3 | 14 | 0.56 | 0.540 | 100.00 | 100.00 | 99.78 | 99.99 | 8.12 | 0.00 | 1, 1 | global |
| R4 | 11 | 0.44 | 0.587 | 99.89 | 99.91 | 99.68 | 99.96 | 8.41 | 0.00 | 1, 1 | global |
| R5 | 10 | 0.40 | 0.559 | 99.99 | 99.99 | 99.80 | 100.00 | 7.90 | 0.00 | 1, 1 | global |

### Idea C

| Pattern | Probes | Search time [s] | Hand-over duty | Hand-over power, static [%] | Hand-over power, Simulink [%] | End power, P&O [%] | End power, VS-INC [%] | V swing, P&O [V] | V swing, VS-INC [V] | Searches | Stops on (VS-INC) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P0 | 11 | 0.44 | 0.600 | 99.79 | 99.79 | 99.74 | 99.89 | 8.29 | 0.00 | 1, 1 | global |
| P1 | 10 | 0.40 | 0.638 | 99.97 | 99.97 | 99.76 | 100.00 | 6.01 | 0.00 | 1, 1 | global |
| P2 | 10 | 0.40 | 0.578 | 99.86 | 99.86 | 99.71 | 99.94 | 8.25 | 0.00 | 1, 1 | global |
| P3 | 18 | 0.72 | 0.578 | 99.90 | 99.90 | 99.74 | 99.96 | 6.48 | 0.00 | 1, 1 | global |
| R1 | 17 | 0.68 | 0.570 | 99.44 | 99.59 | 99.33 | 99.64 | 6.52 | 0.00 | 1, 1 | global |
| R2 | 14 | 0.56 | 0.532 | 99.91 | 99.92 | 99.73 | 99.97 | 7.70 | 0.00 | 1, 1 | global |
| R3 | 16 | 0.64 | 0.540 | 100.00 | 99.99 | 99.78 | 99.99 | 8.12 | 0.00 | 1, 1 | global |
| R4 | 11 | 0.44 | 0.593 | 99.87 | 99.87 | 99.73 | 99.75 | 8.00 | 0.00 | 1, 1 | global |
| R5 | 11 | 0.44 | 0.562 | 99.92 | 99.92 | 99.70 | 99.83 | 8.15 | 0.00 | 1, 1 | global |

### PSO

| Pattern | Probes | Search time [s] | Hand-over duty | Hand-over power, static [%] | Hand-over power, Simulink [%] | End power, P&O [%] | End power, VS-INC [%] | V swing, P&O [V] | V swing, VS-INC [V] | Searches | Stops on (VS-INC) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P0 | 45 | 1.80 | 0.604 | 100.00 | 100.00 | 99.81 | 99.98 | 8.16 | 0.00 | 1, 1 | global |
| P1 | 42 | 1.68 | 0.639 | 100.00 | 100.00 | 99.80 | 99.98 | 6.12 | 0.00 | 1, 1 | global |
| P2 | 42 | 1.68 | 0.580 | 100.00 | 100.00 | 99.81 | 99.98 | 8.07 | 0.00 | 1, 1 | global |
| P3 | 45 | 1.80 | 0.580 | 100.00 | 100.00 | 99.84 | 99.98 | 6.36 | 0.00 | 1, 1 | global |
| R1 | 60 | 2.40 | 0.574 | 100.00 | 99.88 | 99.51 | 99.69 | 6.29 | 0.00 | 1, 1 | global |
| R2 | 45 | 1.80 | 0.535 | 100.00 | 100.00 | 99.82 | 99.98 | 7.88 | 0.00 | 1, 1 | global |
| R3 | 60 | 2.40 | 0.540 | 100.00 | 100.00 | 99.79 | 99.98 | 8.18 | 0.00 | 1, 1 | global |
| R4 | 42 | 1.68 | 0.590 | 100.00 | 100.00 | 99.82 | 99.98 | 8.20 | 0.00 | 1, 1 | global |
| R5 | 36 | 1.44 | 0.560 | 100.00 | 100.00 | 99.82 | 99.99 | 7.97 | 0.00 | 1, 1 | global |

### GWO

| Pattern | Probes | Search time [s] | Hand-over duty | Hand-over power, static [%] | Hand-over power, Simulink [%] | End power, P&O [%] | End power, VS-INC [%] | V swing, P&O [V] | V swing, VS-INC [V] | Searches | Stops on (VS-INC) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P0 | 30 | 1.20 | 0.612 | 98.83 | 97.91 | 99.77 | 99.99 | 7.96 | 0.00 | 1, 1 | global |
| P1 | 30 | 1.20 | 0.638 | 99.99 | 99.94 | 99.78 | 100.00 | 6.05 | 0.00 | 1, 1 | global |
| P2 | 30 | 1.20 | 0.573 | 99.26 | 99.47 | 99.73 | 99.44 | 7.88 | 0.00 | 1, 1 | global |
| P3 | 30 | 1.20 | 0.585 | 99.65 | 99.49 | 99.83 | 99.48 | 6.35 | 0.00 | 1, 1 | global |
| R1 | 30 | 1.20 | 0.697 | 95.32 | 94.61 | 97.58 | 97.22 | 4.09 | 0.00 | 1, 1 | local, 72.6 V |
| R2 | 30 | 1.20 | 0.540 | 99.56 | 98.95 | 99.80 | 99.95 | 7.88 | 0.00 | 1, 1 | global |
| R3 | 30 | 1.20 | 0.540 | 100.00 | 99.99 | 99.78 | 99.99 | 8.12 | 0.00 | 1, 1 | global |
| R4 | 30 | 1.20 | 0.581 | 98.98 | 99.04 | 99.75 | 99.99 | 8.33 | 0.00 | 1, 1 | global |
| R5 | 30 | 1.20 | 0.574 | 96.54 | 95.13 | 99.78 | 100.00 | 7.88 | 0.00 | 1, 1 | global |

### Restart tests

| Set | Method | Local | restart_ref | Phase | End power [%] | Searches in phase | Detection time [s] | Probes | Mean power in phase [%] | Search starts [s] |
|---|---|---|---|---|---|---|---|---|---|---|
| E (P0 to R1 at 3 s) | DIRECT | 2 | 1 | 1: P0 | 99.99 | 1 | 0.060 | 11 | 95.3 | 0.06 |
| E (P0 to R1 at 3 s) | DIRECT | 2 | 1 | 2: R1 | 99.97 | 1 | 0.020 | 15 | 97.0 | 3.02 |
| E (P0 to R1 at 3 s) | Idea B | 2 | 1 | 1: P0 | 99.84 | 1 | 0.060 | 9 | 95.3 | 0.06 |
| E (P0 to R1 at 3 s) | Idea B | 2 | 1 | 2: R1 | 99.92 | 1 | 0.020 | 14 | 97.0 | 3.02 |
| E (P0 to R1 at 3 s) | Idea C | 2 | 1 | 1: P0 | 99.89 | 1 | 0.060 | 11 | 94.7 | 0.06 |
| E (P0 to R1 at 3 s) | Idea C | 2 | 1 | 2: R1 | 99.65 | 1 | 0.020 | 17 | 95.9 | 3.02 |
| E (P0 to R1 at 3 s) | PSO | 2 | 1 | 1: P0 | 99.98 | 1 | 0.060 | 45 | 93.1 | 0.06 |
| E (P0 to R1 at 3 s) | PSO | 2 | 1 | 2: R1 | 99.69 | 1 | 0.020 | 60 | 91.2 | 3.02 |
| E (P0 to R1 at 3 s) | GWO | 2 | 1 | 1: P0 | 99.99 | 1 | 0.060 | 30 | 80.5 | 0.06 |
| E (P0 to R1 at 3 s) | GWO | 2 | 1 | 2: R1 | 97.22 | 1 | 0.020 | 30 | 85.6 | 3.02 |
| E (P0 to R1 at 3 s) | DIRECT | 2 | 2 | 1: P0 | 99.99 | 1 | 0.060 | 11 | 95.3 | 0.06 |
| E (P0 to R1 at 3 s) | DIRECT | 2 | 2 | 2: R1 | 99.97 | 1 | 0.020 | 15 | 97.0 | 3.02 |
| E (P0 to R1 at 3 s) | Idea B | 2 | 2 | 1: P0 | 99.84 | 1 | 0.060 | 9 | 95.3 | 0.06 |
| E (P0 to R1 at 3 s) | Idea B | 2 | 2 | 2: R1 | 99.92 | 1 | 0.020 | 14 | 97.0 | 3.02 |
| E (P0 to R1 at 3 s) | Idea C | 2 | 2 | 1: P0 | 99.89 | 1 | 0.060 | 11 | 94.7 | 0.06 |
| E (P0 to R1 at 3 s) | Idea C | 2 | 2 | 2: R1 | 99.65 | 1 | 0.020 | 17 | 95.9 | 3.02 |
| E (P0 to R1 at 3 s) | PSO | 2 | 2 | 1: P0 | 99.98 | 1 | 0.060 | 45 | 93.1 | 0.06 |
| E (P0 to R1 at 3 s) | PSO | 2 | 2 | 2: R1 | 99.69 | 1 | 0.020 | 60 | 91.2 | 3.02 |
| E (P0 to R1 at 3 s) | GWO | 2 | 2 | 1: P0 | 99.99 | 1 | 0.060 | 30 | 80.5 | 0.06 |
| E (P0 to R1 at 3 s) | GWO | 2 | 2 | 2: R1 | 97.22 | 1 | 0.020 | 30 | 85.6 | 3.02 |
| E (P0 to R1 at 3 s) | DIRECT | 1 | 1 | 1: P0 | 99.80 | 1 | 0.060 | 11 | 95.2 | 0.06 |
| E (P0 to R1 at 3 s) | DIRECT | 1 | 1 | 2: R1 | 99.44 | 1 | 0.020 | 15 | 96.6 | 3.02 |
| E (P0 to R1 at 3 s) | Idea B | 1 | 1 | 1: P0 | 99.75 | 1 | 0.060 | 9 | 95.2 | 0.06 |
| E (P0 to R1 at 3 s) | Idea B | 1 | 1 | 2: R1 | 99.42 | 1 | 0.020 | 14 | 96.6 | 3.02 |
| E (P0 to R1 at 3 s) | Idea C | 1 | 1 | 1: P0 | 99.74 | 1 | 0.060 | 11 | 94.6 | 0.06 |
| E (P0 to R1 at 3 s) | Idea C | 1 | 1 | 2: R1 | 99.35 | 1 | 0.020 | 17 | 95.7 | 3.02 |
| E (P0 to R1 at 3 s) | PSO | 1 | 1 | 1: P0 | 99.81 | 1 | 0.060 | 45 | 93.0 | 0.06 |
| E (P0 to R1 at 3 s) | PSO | 1 | 1 | 2: R1 | 99.43 | 1 | 0.020 | 60 | 91.1 | 3.02 |
| E (P0 to R1 at 3 s) | GWO | 1 | 1 | 1: P0 | 99.73 | 1 | 0.060 | 30 | 80.3 | 0.06 |
| E (P0 to R1 at 3 s) | GWO | 1 | 1 | 2: R1 | 97.56 | 1 | 0.020 | 30 | 85.8 | 3.02 |
| F (R1 to P0 at 3 s) | DIRECT | 2 | 1 | 1: R1 | 99.97 | 1 | 0.060 | 15 | 95.0 | 0.06 |
| F (R1 to P0 at 3 s) | DIRECT | 2 | 1 | 2: P0 | 99.99 | 1 | 0.020 | 11 | 97.4 | 3.02 |
| F (R1 to P0 at 3 s) | Idea B | 2 | 1 | 1: R1 | 99.92 | 1 | 0.060 | 14 | 95.1 | 0.06 |
| F (R1 to P0 at 3 s) | Idea B | 2 | 1 | 2: P0 | 99.84 | 1 | 0.020 | 9 | 97.3 | 3.02 |
| F (R1 to P0 at 3 s) | Idea C | 2 | 1 | 1: R1 | 99.64 | 1 | 0.060 | 17 | 93.8 | 0.06 |
| F (R1 to P0 at 3 s) | Idea C | 2 | 1 | 2: P0 | 99.89 | 1 | 0.020 | 11 | 96.9 | 3.02 |
| F (R1 to P0 at 3 s) | PSO | 2 | 1 | 1: R1 | 99.69 | 1 | 0.060 | 60 | 88.3 | 0.06 |
| F (R1 to P0 at 3 s) | PSO | 2 | 1 | 2: P0 | 99.98 | 1 | 0.020 | 45 | 95.5 | 3.02 |
| F (R1 to P0 at 3 s) | GWO | 2 | 1 | 1: R1 | 97.22 | 1 | 0.060 | 30 | 82.2 | 0.06 |
| F (R1 to P0 at 3 s) | GWO | 2 | 1 | 2: P0 | 99.99 | 1 | 0.020 | 30 | 84.5 | 3.02 |
| T (P1, T_rescan = 1 s) | DIRECT | 2 | 1 | 1: P1 | 99.44 | 5 | 0.060 | 14 | 88.9 | 0.06, 1.62, 3.18, 4.74, 6.30 |
| T (P1, T_rescan = 1 s) | Idea B | 2 | 1 | 1: P1 | 99.99 | 5 | 0.060 | 11 | 89.3 | 0.06, 1.50, 2.94, 4.38, 5.82 |
| T (P1, T_rescan = 1 s) | Idea C | 2 | 1 | 1: P1 | 100.00 | 5 | 0.060 | 10 | 92.5 | 0.06, 1.46, 2.86, 4.26, 5.66 |
| T (P1, T_rescan = 1 s) | PSO | 2 | 1 | 1: P1 | 99.55 | 3 | 0.060 | 42 | 87.1 | 0.06, 2.74, 5.42 |
| T (P1, T_rescan = 1 s) | GWO | 2 | 1 | 1: P1 | 34.52 | 4 | 0.060 | 30 | 73.5 | 0.06, 2.26, 4.46, 6.66 |
| C (R1, P1 at 4 s, P0 at 8 s) | DIRECT | 2 | 1 | 1: R1 | 99.97 | 1 | 0.060 | 15 | 96.3 | 0.06 |
| C (R1, P1 at 4 s, P0 at 8 s) | DIRECT | 2 | 1 | 2: P1 | 99.98 | 1 | 0.020 | 14 | 96.2 | 4.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | DIRECT | 2 | 1 | 3: P0 | 99.99 | 1 | 0.020 | 11 | 97.7 | 8.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | Idea B | 2 | 1 | 1: R1 | 99.93 | 1 | 0.060 | 14 | 96.3 | 0.06 |
| C (R1, P1 at 4 s, P0 at 8 s) | Idea B | 2 | 1 | 2: P1 | 99.99 | 1 | 0.020 | 11 | 96.4 | 4.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | Idea B | 2 | 1 | 3: P0 | 99.84 | 1 | 0.020 | 9 | 97.6 | 8.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | Idea C | 2 | 1 | 1: R1 | 99.64 | 1 | 0.060 | 17 | 95.3 | 0.06 |
| C (R1, P1 at 4 s, P0 at 8 s) | Idea C | 2 | 1 | 2: P1 | 100.00 | 1 | 0.020 | 10 | 97.5 | 4.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | Idea C | 2 | 1 | 3: P0 | 99.89 | 1 | 0.020 | 11 | 97.2 | 8.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | PSO | 2 | 1 | 1: R1 | 99.69 | 1 | 0.060 | 60 | 91.2 | 0.06 |
| C (R1, P1 at 4 s, P0 at 8 s) | PSO | 2 | 1 | 2: P1 | 99.98 | 1 | 0.020 | 42 | 92.7 | 4.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | PSO | 2 | 1 | 3: P0 | 99.98 | 1 | 0.020 | 45 | 96.0 | 8.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | GWO | 2 | 1 | 1: R1 | 97.22 | 1 | 0.060 | 30 | 86.0 | 0.06 |
| C (R1, P1 at 4 s, P0 at 8 s) | GWO | 2 | 1 | 2: P1 | 100.00 | 1 | 0.020 | 30 | 86.7 | 4.02 |
| C (R1, P1 at 4 s, P0 at 8 s) | GWO | 2 | 1 | 3: P0 | 99.99 | 1 | 0.020 | 30 | 86.5 | 8.02 |
