# Mini project (EE420 Microgrids and Smart Grids): P&O and INC on the 4 x 4 PV array

This folder holds the mini project report, the MATLAB code and the Simulink models of the simulation runs, the results of 29 September 2026, and the reference papers that the report cites.

## Contents

| Path | Content |
|---|---|
| `MiniProject_EE420_Report_PO_INC.docx` | The mini project report for EE420 Microgrids and Smart Grids, in the format of the IEEE A4 conference template (two columns). Edit this file. |
| `MiniProject_EE420_Report_PO_INC.pdf` | The same report as a PDF, 8 pages. |
| `Code/` | The MATLAB code and the two Simulink models of the runs (see "Code and models") |
| `Simulation_Results/` | The saved results of the simulation runs of 29 September 2026, with no change. |
| `Simulation_Results/derived_metrics.csv` | Tracking time and energy ratio of each run. The report calculates these from the saved waveforms. No new simulation was run. |
| `Simulation_Results/derive_metrics.py` | The script that writes `derived_metrics.csv` from `mppt_results.mat`. |
| `Reference_Papers/` | PDF copies of the cited papers. The number in each file name is the reference number in the report. |

## Code and models

The code in `Code/` is the code of the runs of 29 September 2026, with no change.

| File | Content |
|---|---|
| `pv4x4_config.m` | All values: panel, array, bypass diode, converter, P&O and INC |
| `shading_patterns.m` | The nine shading patterns P0 to P3 and R1 to R5 |
| `mppt_controller.m` | The tracker. `mppt.alg = 1` is P&O and `mppt.alg = 2` is INC. The block "MPPT" in `MPPT_4x4.slx` calls it every 50 us |
| `PV4x4_sweep.slx` | The voltage-sweep testbench: the 4 x 4 array and a controlled voltage source. It gives the P-V curves |
| `MPPT_4x4.slx` | The 4 x 4 array, an averaged buck-boost converter into 10 Ohm, and the tracker |
| `run_pv4x4_sweeps.m` | Sweeps each pattern. Writes the curves and the global peak of each pattern |
| `run_po_demo.m` | Runs each case with P&O and with INC (24 runs). Writes the result table and the figures |
| `graph_menu.m`, `plots/` | A menu that draws one graph from the saved results, and one function for each figure. The run scripts also use `plots/` |

The two models are complete. Some code comments name the build scripts that made the models, but these scripts are not in this folder. On 21 November 2026, the two models were made again from these scripts and all the runs were done again. The new `mppt_results.csv` and `pv4x4_peaks.csv` were the same as the files in `Simulation_Results/`.

The two models were saved in MATLAB R2025b. Simscape Electrical models cannot be saved for an earlier release, so R2024b cannot open them.

To run the simulations again:

1. Open MATLAB R2025b or later, with Simulink, Simscape and Simscape Electrical.
2. Set `Code/` as the current folder.
3. Run `run_pv4x4_sweeps`. It takes about 1 min.
4. Run `run_po_demo`. It takes about 5 min.

The scripts write their results into `Code/results/`. They do not change `Simulation_Results/`. Do not put `Code/` and the main project folder on the MATLAB path at the same time, because both folders have files with the same names.

## Results files

| File | Content |
|---|---|
| `pv4x4_peaks.csv`, `pv4x4_sweeps.mat` | Peaks and P-V curves of the nine shading patterns |
| `mppt_results.csv`, `mppt_results.mat` | Final power, voltage swing and waveforms of the 24 P&O and INC runs |
| `fig_*.png` | The figures of the simulation runs. The report uses nine of them. |

To make `derived_metrics.csv` again, run this command in `Simulation_Results`:

```bash
python derive_metrics.py mppt_results.mat derived_metrics.csv
```

## References and PDF copies

| No. | Reference | PDF in `Reference_Papers` |
|---|---|---|
| 1 | Esram and Chapman, IEEE Trans. Energy Convers., 2007, doi 10.1109/TEC.2006.874230 | No |
| 2 | Femia et al., IEEE Trans. Power Electron., 2005, doi 10.1109/TPEL.2005.850975 | No |
| 3 | Hussein et al., IEE Proc. Gener. Transm. Distrib., 1995, doi 10.1049/ip-gtd:19951577 | No |
| 4 | Patel and Agarwal, IEEE Trans. Ind. Electron., 2008, doi 10.1109/TIE.2008.917118 | No |
| 5 | Bidram et al., IEEE J. Photovolt., 2012, doi 10.1109/JPHOTOV.2012.2202879 | No |
| 6 | Nguyen and Low, IEEE Trans. Ind. Electron., 2010 | Yes |
| 7 | Boztepe et al., IEEE Trans. Ind. Electron., 2014 | Yes |
| 8 | Furtado et al., IEEE Trans. Ind. Electron., 2018 | Yes |
| 9 | Kermadi et al., IEEE Trans. Ind. Electron., 2019 | Yes |
| 10 | Ahmed et al., IEEE Trans. Power Electron., 2023 | Yes |
| 11 | Zaki et al., Scientific Reports, 2023 | Yes |
| 12 | Harrison et al., Heliyon, 2023 | Yes |
| 13 | Emmvee E325P72 datasheet (manufacturer document) | Yes |
| 14 | MathWorks, Simscape Electrical block documentation (software documentation) | No |

The project has no PDF of references 1 to 5. These papers are behind a paywall. Get them through the institute library with the DOI, and add them to `Reference_Papers` with the same name pattern. Reference 14 is online documentation at mathworks.com.
