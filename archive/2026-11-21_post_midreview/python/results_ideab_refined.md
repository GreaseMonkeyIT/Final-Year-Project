## 1. Ablation, 900 cases, noise 0.0 %

| Variant | GMPP found | Worst | Mean probes | Max | Cert mean | Cert p95 | Cert max |
|---|---|---|---|---|---|---|---|
| Idea B (eps 0.02, tol 0.01) | 100.0 % | 99.0 % | 14.38 | 23 | 1.016 | 1.022 | 1.034 |
| B, no extra cycles | 100.0 % | 99.0 % | 14.24 | 23 | 1.016 | 1.022 | 1.034 |
| B, no local stage | 100.0 % | 99.0 % | 13.76 | 24 | 1.017 | 1.028 | 1.042 |
| B, corner split | 100.0 % | 99.0 % | 13.80 | 23 | 1.016 | 1.023 | 1.035 |
| B, no extra cycles, no local stage | 100.0 % | 99.0 % | 13.69 | 24 | 1.017 | 1.027 | 1.042 |
| Idea B refined (all three) | 100.0 % | 99.0 % | 12.70 | 24 | 1.015 | 1.024 | 1.040 |
| Idea C (eps 0.02, tol 0.01) | 100.0 % | 99.0 % | 13.78 | 24 | 1.017 | 1.025 | 1.032 |
| Idea C, corner split | 100.0 % | 99.0 % | 12.62 | 21 | 1.016 | 1.025 | 1.035 |

## 1. Ablation, 900 cases, noise 0.5 %

| Variant | GMPP found | Worst | Mean probes | Max | Cert mean | Cert p95 | Cert max |
|---|---|---|---|---|---|---|---|
| Idea B (eps 0.02, tol 0.01) | 99.4 % | 97.3 % | 14.12 | 23 | 1.018 | 1.032 | 1.044 |
| B, no extra cycles | 99.8 % | 97.5 % | 14.03 | 23 | 1.018 | 1.031 | 1.048 |
| B, no local stage | 99.8 % | 97.4 % | 13.42 | 24 | 1.019 | 1.034 | 1.056 |
| B, corner split | 99.9 % | 97.5 % | 13.57 | 24 | 1.019 | 1.033 | 1.045 |
| B, no extra cycles, no local stage | 99.7 % | 97.4 % | 13.42 | 24 | 1.019 | 1.033 | 1.043 |
| Idea B refined (all three) | 99.9 % | 97.5 % | 12.39 | 21 | 1.020 | 1.031 | 1.051 |
| Idea C (eps 0.02, tol 0.01) | 99.7 % | 97.0 % | 13.60 | 25 | 1.019 | 1.032 | 1.057 |
| Idea C, corner split | 99.9 % | 97.4 % | 12.40 | 22 | 1.020 | 1.032 | 1.043 |

## 2. Probes against the certificate, 900 cases, no noise

| Variant | GMPP found | Worst | Mean probes | Max | Cert mean | Cert p95 | Cert max |
|---|---|---|---|---|---|---|---|
| Idea B, eps 0.02 | 100.0 % | 99.0 % | 14.38 | 23 | 1.016 | 1.022 | 1.034 |
| Idea B refined, eps 0.02 | 100.0 % | 99.0 % | 12.70 | 24 | 1.015 | 1.024 | 1.040 |
| Idea B, eps 0.03 | 100.0 % | 99.0 % | 13.50 | 21 | 1.021 | 1.029 | 1.034 |
| Idea B refined, eps 0.03 | 100.0 % | 99.0 % | 11.62 | 19 | 1.021 | 1.029 | 1.040 |
| Idea B, eps 0.04 | 100.0 % | 99.0 % | 12.57 | 19 | 1.026 | 1.038 | 1.040 |
| Idea B refined, eps 0.04 | 100.0 % | 99.0 % | 10.50 | 18 | 1.026 | 1.039 | 1.040 |
| Idea B, eps 0.05 | 100.0 % | 98.7 % | 11.95 | 16 | 1.030 | 1.048 | 1.050 |
| Idea B refined, eps 0.05 | 100.0 % | 98.9 % | 9.70 | 17 | 1.030 | 1.048 | 1.050 |
| Idea B, eps 0.06 | 100.0 % | 98.7 % | 11.59 | 16 | 1.034 | 1.058 | 1.060 |
| Idea B refined, eps 0.06 | 100.0 % | 98.7 % | 9.11 | 16 | 1.035 | 1.058 | 1.060 |
| Rejected: window test, eps 0.0 | 100.0 % | 99.0 % | 10.26 | 18 | 1.027 | 1.041 | 1.046 |
| Rejected: window test, eps 0.01 | 100.0 % | 98.9 % | 9.52 | 16 | 1.032 | 1.051 | 1.057 |
| Rejected: window test, eps 0.02 | 100.0 % | 98.9 % | 8.91 | 16 | 1.036 | 1.062 | 1.067 |

## 3. PSO settings, 900 cases, no noise

| Start points | vstop | GMPP found | Worst | Mean probes | Max |
|---|---|---|---|---|---|
| centres of 3 parts | 0.005 | 93.3 % | 74.3 % | 35.1 | 60 |
| centres of 3 parts | 0.01 | 93.0 % | 74.3 % | 28.9 | 60 |
| centres of 3 parts | 0.02 | 92.0 % | 74.3 % | 22.4 | 60 |
| centres of 3 parts | 0.04 | 88.7 % | 74.3 % | 15.7 | 42 |
| ends and middle | 0.005 | 95.7 % | 75.4 % | 37.9 | 60 |
| ends and middle | 0.01 | 95.6 % | 75.4 % | 31.6 | 60 |
| ends and middle | 0.02 | 94.2 % | 75.4 % | 25.1 | 54 |
| ends and middle | 0.04 | 92.1 % | 75.4 % | 18.7 | 51 |

Seed spread of the chosen PSO (ends and middle, vstop 0.01): three seed sets.

| Seed set | GMPP found | Worst | Mean probes |
|---|---|---|---|
| +0 | 95.6 % | 75.4 % | 31.6 |
| +1000 | 94.3 % | 74.9 % | 31.5 |
| +2000 | 93.7 % | 78.8 % | 31.4 |

## 4. DIRECT as in the paper: two readings of the re-test, 900 cases

When only one shading test holds, the paper gives the re-test for a failed (19) only.
"held": the pair of the test that held, with the new sample between them (the default).
"outer": the triple (D2, best new sample, D3) in both cases.

| Variant | GMPP found | Worst | Mean probes | Max | Cert mean | Cert p95 | Cert max |
|---|---|---|---|---|---|---|---|
| held, noise 0.0 % | 93.6 % | 89.2 % | 12.84 | 16 | 1.082 | 1.225 | 1.369 |
| outer, noise 0.0 % | 94.6 % | 92.7 % | 13.41 | 16 | 1.067 | 1.143 | 1.266 |
| held, noise 0.5 % | 93.0 % | 90.2 % | 12.82 | 16 | 1.081 | 1.226 | 1.405 |
| outer, noise 0.5 % | 93.9 % | 92.6 % | 13.42 | 16 | 1.065 | 1.143 | 1.266 |
