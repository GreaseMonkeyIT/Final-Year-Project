## Nine project patterns, no noise. Cells: search probes / final % of GMPP

Lipschitz constant of LIPO and of the Khong stop: k = 44504 W per unit duty (1.2 x the largest |dP/dD| of the nine patterns).

| Method | P0 | P1 | P2 | P3 | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|---|---|---|---|
| P&O, start D = 0.30 | 0 / 99.7 | 0 / 46.6 | 0 / 99.8 | 0 / 95.9 | 0 / 35.0 | 0 / 99.8 | 0 / 99.8 | 0 / 99.8 | 0 / 99.8 |
| M1 Zaki 2023 (r = 0.8) | 2 / 99.8 | 3 / 99.8 | 2 / 99.8 | 3 / 99.8 | 4 / 97.3 | 2 / 99.8 | 2 / 99.7 | 2 / 99.7 | 2 / 99.8 |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 7 / 99.7 | 8 / 99.6 | 40 / 99.8 | 40 / 99.8 | 6 / 99.3 | 40 / 99.8 | 40 / 99.8 | 40 / 99.8 | 6 / 99.8 |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 30 / 99.7 | 33 / 99.7 | 28 / 99.8 | 28 / 99.8 | 25 / 99.1 | 23 / 99.8 | 24 / 99.8 | 29 / 99.8 | 26 / 99.8 |
| M3 Kouchaki 2023 (paper ξ(G)) | 2 / 99.8 | 9 / 99.8 | 2 / 99.8 | 9 / 99.8 | 9 / 99.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 2 / 99.8 |
| M4 DIRECT, Nguyen & Low 2010 | 9 / 99.7 | 11 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 |
| Idea A: DIRECT + bound pruning | 9 / 99.7 | 10 / 99.7 | 9 / 99.8 | 11 / 99.8 | 9 / 97.2 | 9 / 99.8 | 9 / 99.8 | 9 / 99.8 | 9 / 99.7 |
| Idea B: DIRECT + bound check | 11 / 99.7 | 12 / 99.7 | 11 / 99.8 | 17 / 99.8 | 16 / 99.5 | 12 / 99.8 | 13 / 99.8 | 12 / 99.8 | 12 / 99.7 |
| Idea C: BSP + bound (best-first) | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 18 / 99.8 | 16 / 99.3 | 14 / 99.7 | 16 / 99.8 | 11 / 99.8 | 12 / 99.7 |
| LIPO, Li 2019 (k tuned) | 13 / 99.8 | 19 / 99.7 | 19 / 99.8 | 39 / 99.8 | 33 / 99.4 | 31 / 99.8 | 26 / 99.7 | 19 / 99.8 | 21 / 99.8 |
| LIPO, Li 2019 (k halved) | 5 / 99.8 | 9 / 99.8 | 8 / 99.8 | 21 / 99.8 | 17 / 99.4 | 13 / 99.8 | 13 / 99.7 | 7 / 99.7 | 9 / 99.7 |
| DIRECT + Lipschitz stop, Khong 2013 | 17 / 99.8 | 25 / 99.8 | 25 / 99.8 | 39 / 99.8 | 39 / 99.4 | 35 / 99.8 | 33 / 99.8 | 21 / 99.8 | 27 / 99.8 |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 21 / 99.8 | 17 / 99.8 | 21 / 99.8 | 19 / 99.8 | 14 / 99.4 | 17 / 99.8 | 20 / 99.8 | 21 / 99.8 | 21 / 99.8 |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 11 / 99.7 | 10 / 99.8 | 11 / 99.7 | 11 / 99.8 | 9 / 99.4 | 9 / 99.8 | 11 / 99.8 | 11 / 99.8 | 11 / 99.8 |
| DIRECT as in the paper, Nguyen & Low 2010 | 11 / 99.8 | 14 / 99.7 | 11 / 99.8 | 15 / 99.8 | 15 / 99.4 | 13 / 99.8 | 13 / 99.8 | 11 / 99.8 | 11 / 99.8 |
| PSO, Ishaque 2012 (3 particles) | 33 / 99.8 | 36 / 99.7 | 30 / 99.8 | 39 / 99.8 | 30 / 99.5 | 27 / 99.8 | 36 / 99.8 | 42 / 99.8 | 30 / 99.8 |
| PSO, Ishaque 2012 (5 particles) | 85 / 99.8 | 50 / 99.8 | 55 / 99.8 | 40 / 99.8 | 45 / 97.3 | 60 / 99.8 | 50 / 99.8 | 65 / 99.8 | 60 / 99.8 |
| Idea B refined | 8 / 99.7 | 10 / 99.8 | 8 / 99.8 | 14 / 99.8 | 11 / 99.4 | 10 / 99.8 | 13 / 99.8 | 8 / 99.8 | 9 / 99.8 |

## panel, noise 0.0 % (300 patterns)

| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 23.0 % | 21.6 % | 0.0 | 0 | 51.6 % |
| M1 Zaki 2023 (r = 0.8) | 96.0 % | 92.5 % | 2.8 | 4 | 98.5 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 99.7 % | 90.1 % | 18.1 | 40 | 91.7 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 100.0 % | 99.2 % | 28.9 | 37 | 74.0 % |
| M3 Kouchaki 2023 (paper ξ(G)) | 99.0 % | 93.7 % | 9.0 | 9 | 94.0 % |
| M4 DIRECT, Nguyen & Low 2010 | 91.3 % | 88.2 % | 10.3 | 13 | 95.3 % |
| Idea A: DIRECT + bound pruning | 91.3 % | 88.2 % | 10.1 | 13 | 95.4 % |
| Idea B: DIRECT + bound check | 100.0 % | 99.2 % | 13.8 | 20 | 95.2 % |
| Idea C: BSP + bound (best-first) | 100.0 % | 99.3 % | 12.9 | 21 | 94.1 % |
| LIPO, Li 2019 (k tuned) | 100.0 % | 99.4 % | 27.3 | 40 | 89.8 % |
| LIPO, Li 2019 (k halved) | 100.0 % | 99.1 % | 12.9 | 29 | 94.2 % |
| DIRECT + Lipschitz stop, Khong 2013 | 100.0 % | 99.4 % | 32.6 | 39 | 89.0 % |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 100.0 % | 98.1 % | 17.5 | 21 | 87.4 % |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 98.7 % | 97.1 % | 10.2 | 11 | 91.8 % |
| DIRECT as in the paper, Nguyen & Low 2010 | 94.0 % | 89.2 % | 13.5 | 16 | 94.6 % |
| PSO, Ishaque 2012 (3 particles) | 94.3 % | 80.3 % | 31.3 | 60 | 89.3 % |
| PSO, Ishaque 2012 (5 particles) | 97.0 % | 83.2 % | 58.0 | 100 | 85.5 % |
| Idea B refined | 100.0 % | 99.4 % | 12.0 | 17 | 95.8 % |

## panel, noise 0.5 % (300 patterns)

| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 23.0 % | 21.6 % | 0.0 | 0 | 51.5 % |
| M1 Zaki 2023 (r = 0.8) | 96.0 % | 92.2 % | 2.8 | 4 | 98.3 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 100.0 % | 98.4 % | 15.4 | 40 | 92.0 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 100.0 % | 98.5 % | 28.9 | 37 | 73.9 % |
| M3 Kouchaki 2023 (paper ξ(G)) | 97.7 % | 93.1 % | 9.0 | 9 | 93.8 % |
| M4 DIRECT, Nguyen & Low 2010 | 91.7 % | 85.9 % | 10.2 | 13 | 95.2 % |
| Idea A: DIRECT + bound pruning | 90.3 % | 88.8 % | 10.1 | 13 | 95.2 % |
| Idea B: DIRECT + bound check | 100.0 % | 98.5 % | 13.7 | 20 | 95.0 % |
| Idea C: BSP + bound (best-first) | 100.0 % | 98.6 % | 12.8 | 19 | 93.9 % |
| LIPO, Li 2019 (k tuned) | 100.0 % | 98.1 % | 25.5 | 40 | 89.7 % |
| LIPO, Li 2019 (k halved) | 100.0 % | 98.0 % | 12.6 | 29 | 94.0 % |
| DIRECT + Lipschitz stop, Khong 2013 | 100.0 % | 98.6 % | 30.8 | 39 | 89.0 % |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 100.0 % | 98.5 % | 17.5 | 21 | 87.3 % |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 98.0 % | 96.0 % | 10.2 | 11 | 91.7 % |
| DIRECT as in the paper, Nguyen & Low 2010 | 93.3 % | 90.7 % | 13.5 | 16 | 94.4 % |
| PSO, Ishaque 2012 (3 particles) | 93.3 % | 79.8 % | 31.0 | 60 | 89.2 % |
| PSO, Ishaque 2012 (5 particles) | 95.0 % | 83.0 % | 58.8 | 100 | 85.3 % |
| Idea B refined | 100.0 % | 98.0 % | 11.7 | 17 | 95.7 % |

## edge, noise 0.0 % (300 patterns)

| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 52.0 % | 45.0 % | 0.0 | 0 | 58.1 % |
| M1 Zaki 2023 (r = 0.8) | 87.0 % | 79.7 % | 2.4 | 4 | 98.0 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 98.3 % | 92.0 % | 18.0 | 40 | 92.6 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 99.7 % | 96.5 % | 25.8 | 36 | 78.0 % |
| M3 Kouchaki 2023 (paper ξ(G)) | 85.0 % | 85.5 % | 9.0 | 9 | 92.8 % |
| M4 DIRECT, Nguyen & Low 2010 | 92.7 % | 88.0 % | 9.5 | 13 | 96.0 % |
| Idea A: DIRECT + bound pruning | 92.7 % | 88.0 % | 9.4 | 13 | 96.1 % |
| Idea B: DIRECT + bound check | 100.0 % | 99.0 % | 13.8 | 21 | 95.8 % |
| Idea C: BSP + bound (best-first) | 100.0 % | 99.1 % | 14.3 | 23 | 93.9 % |
| LIPO, Li 2019 (k tuned) | 100.0 % | 99.3 % | 31.7 | 40 | 88.7 % |
| LIPO, Li 2019 (k halved) | 100.0 % | 99.3 % | 16.5 | 37 | 93.5 % |
| DIRECT + Lipschitz stop, Khong 2013 | 100.0 % | 99.2 % | 35.5 | 39 | 88.2 % |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 99.7 % | 97.4 % | 18.7 | 21 | 87.2 % |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 98.0 % | 96.5 % | 10.5 | 11 | 92.0 % |
| DIRECT as in the paper, Nguyen & Low 2010 | 96.7 % | 94.8 % | 12.9 | 16 | 95.6 % |
| PSO, Ishaque 2012 (3 particles) | 94.3 % | 75.4 % | 31.3 | 54 | 90.2 % |
| PSO, Ishaque 2012 (5 particles) | 96.3 % | 78.0 % | 56.5 | 100 | 86.6 % |
| Idea B refined | 100.0 % | 99.1 % | 12.3 | 20 | 96.3 % |

## edge, noise 0.5 % (300 patterns)

| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 60.3 % | 44.8 % | 0.0 | 0 | 58.1 % |
| M1 Zaki 2023 (r = 0.8) | 88.3 % | 79.4 % | 2.4 | 4 | 97.9 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 99.3 % | 95.2 % | 14.8 | 40 | 93.0 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 100.0 % | 98.7 % | 25.8 | 36 | 77.9 % |
| M3 Kouchaki 2023 (paper ξ(G)) | 86.3 % | 85.1 % | 9.0 | 9 | 92.7 % |
| M4 DIRECT, Nguyen & Low 2010 | 93.7 % | 87.8 % | 9.5 | 13 | 95.9 % |
| Idea A: DIRECT + bound pruning | 93.3 % | 87.7 % | 9.4 | 13 | 95.9 % |
| Idea B: DIRECT + bound check | 99.7 % | 97.5 % | 13.6 | 21 | 95.7 % |
| Idea C: BSP + bound (best-first) | 99.7 % | 98.0 % | 14.0 | 23 | 93.7 % |
| LIPO, Li 2019 (k tuned) | 100.0 % | 98.3 % | 29.6 | 40 | 88.8 % |
| LIPO, Li 2019 (k halved) | 100.0 % | 98.4 % | 15.6 | 31 | 93.4 % |
| DIRECT + Lipschitz stop, Khong 2013 | 100.0 % | 98.2 % | 34.0 | 39 | 88.2 % |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 99.7 % | 97.6 % | 18.7 | 21 | 87.1 % |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 99.3 % | 97.4 % | 10.5 | 11 | 91.9 % |
| DIRECT as in the paper, Nguyen & Low 2010 | 97.0 % | 95.0 % | 12.9 | 16 | 95.4 % |
| PSO, Ishaque 2012 (3 particles) | 94.7 % | 74.9 % | 31.6 | 60 | 90.1 % |
| PSO, Ishaque 2012 (5 particles) | 95.7 % | 77.8 % | 56.7 | 100 | 86.5 % |
| Idea B refined | 100.0 % | 98.5 % | 12.0 | 20 | 96.2 % |

## group, noise 0.0 % (300 patterns)

| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 4.3 % | 26.4 % | 0.0 | 0 | 41.2 % |
| M1 Zaki 2023 (r = 0.8) | 75.7 % | 90.0 % | 2.9 | 4 | 97.5 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 88.7 % | 91.2 % | 20.0 | 40 | 91.6 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 99.7 % | 97.5 % | 31.4 | 37 | 71.6 % |
| M3 Kouchaki 2023 (paper ξ(G)) | 74.7 % | 80.4 % | 9.0 | 9 | 91.9 % |
| M4 DIRECT, Nguyen & Low 2010 | 89.3 % | 90.0 % | 9.7 | 11 | 95.5 % |
| Idea A: DIRECT + bound pruning | 89.3 % | 90.0 % | 9.7 | 11 | 95.5 % |
| Idea B: DIRECT + bound check | 100.0 % | 99.0 % | 15.5 | 23 | 95.3 % |
| Idea C: BSP + bound (best-first) | 100.0 % | 99.0 % | 14.2 | 24 | 94.4 % |
| LIPO, Li 2019 (k tuned) | 100.0 % | 99.1 % | 27.6 | 40 | 90.6 % |
| LIPO, Li 2019 (k halved) | 100.0 % | 99.0 % | 13.1 | 24 | 94.6 % |
| DIRECT + Lipschitz stop, Khong 2013 | 100.0 % | 99.1 % | 33.2 | 39 | 89.6 % |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 99.7 % | 97.7 % | 18.0 | 21 | 87.4 % |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 94.3 % | 95.7 % | 10.4 | 11 | 91.8 % |
| DIRECT as in the paper, Nguyen & Low 2010 | 90.0 % | 90.2 % | 12.1 | 15 | 95.1 % |
| PSO, Ishaque 2012 (3 particles) | 98.0 % | 96.3 % | 32.0 | 60 | 89.8 % |
| PSO, Ishaque 2012 (5 particles) | 99.0 % | 97.1 % | 56.3 | 100 | 86.2 % |
| Idea B refined | 100.0 % | 99.0 % | 13.9 | 24 | 95.9 % |

## group, noise 0.5 % (300 patterns)

| Method | GMPP found (≥ 98 %) | Worst case | Mean search probes | Max probes | Mean power in first 1 s |
|---|---|---|---|---|---|
| P&O, start D = 0.30 | 22.3 % | 26.5 % | 0.0 | 0 | 41.8 % |
| M1 Zaki 2023 (r = 0.8) | 85.0 % | 92.9 % | 2.9 | 4 | 97.5 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.05 | 94.7 % | 92.2 % | 18.5 | 40 | 91.7 % |
| M2 Alombah 2025, ideal [Va,Vb], λd 0.01 | 100.0 % | 98.2 % | 31.4 | 37 | 71.5 % |
| M3 Kouchaki 2023 (paper ξ(G)) | 81.0 % | 82.4 % | 9.0 | 9 | 91.8 % |
| M4 DIRECT, Nguyen & Low 2010 | 88.0 % | 90.0 % | 9.7 | 13 | 95.3 % |
| Idea A: DIRECT + bound pruning | 88.0 % | 89.5 % | 9.7 | 13 | 95.3 % |
| Idea B: DIRECT + bound check | 100.0 % | 98.0 % | 15.2 | 23 | 95.2 % |
| Idea C: BSP + bound (best-first) | 99.7 % | 97.9 % | 13.8 | 24 | 94.4 % |
| LIPO, Li 2019 (k tuned) | 100.0 % | 98.1 % | 25.4 | 40 | 90.6 % |
| LIPO, Li 2019 (k halved) | 99.7 % | 97.5 % | 12.8 | 24 | 94.5 % |
| DIRECT + Lipschitz stop, Khong 2013 | 100.0 % | 98.1 % | 31.1 | 39 | 89.7 % |
| Skip sweep, Boztepe 2014 (0.5 VocP) | 99.7 % | 97.9 % | 18.0 | 21 | 87.2 % |
| Skip sweep, Boztepe 2014 (1.0 VocP) | 94.7 % | 95.0 % | 10.4 | 11 | 91.7 % |
| DIRECT as in the paper, Nguyen & Low 2010 | 90.3 % | 90.2 % | 12.3 | 16 | 94.9 % |
| PSO, Ishaque 2012 (3 particles) | 96.0 % | 95.9 % | 32.5 | 60 | 89.6 % |
| PSO, Ishaque 2012 (5 particles) | 98.3 % | 94.8 % | 57.4 | 100 | 86.1 % |
| Idea B refined | 100.0 % | 98.2 % | 13.7 | 24 | 95.7 % |
