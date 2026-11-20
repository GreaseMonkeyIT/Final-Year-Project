"""Derive the tracking time and the energy ratio of each mid-review run.

Usage: python derive_metrics.py mppt_results.mat derived_metrics.csv

The script reads the logged waveforms in mppt_results.mat (the runs of
29 September 2026). It writes one row for each run, or for each phase of a
set C run. The report uses these values in its tables.

t98     time from the start of the run (or phase) to the end of the first
        20 ms MPPT period in which the period-average power is at least
        98 % of the final power.
E_ratio energy that the array gives over the run (or phase), divided by the
        energy at the global peak over the same time, in percent.
"""
import csv
import sys

import numpy as np
import scipy.io as sio

T_MPPT = 0.02  # MPPT period [s]


def main(mat_path, csv_path):
    m = sio.loadmat(mat_path, squeeze_me=True, struct_as_record=False)
    t_m = np.atleast_1d(m["tM"])
    rows = []
    for r in m["R"]:
        pm = np.atleast_1d(r.Pm)
        tk = (np.arange(len(pm)) + 1) * T_MPPT
        t = np.asarray(r.t)
        p = np.asarray(r.P)
        if r.set in "AB":
            spans = [(0.0, t[-1], r.id, r.Pgmpp, r.Pend)]
        else:
            ids = ["R1", "P1", "P0"]
            gmpp = {"R1": 2562.9, "P1": 3849.8, "P0": 5194.1}
            spans = []
            for i in range(3):
                sel = (tk > t_m[i] + 1e-9) & (tk <= t_m[i + 1] + 1e-9)
                spans.append((t_m[i], t_m[i + 1], ids[i], gmpp[ids[i]],
                              pm[sel][-15:].mean()))
        for t0, t1, pid, p_g, p_end in spans:
            sel = (tk > t0 + 1e-9) & (tk <= t1 + 1e-9)
            k = np.argmax(pm[sel] >= 0.98 * p_end)
            st = (t >= t0) & (t <= t1)
            energy = np.trapezoid(p[st], t[st])
            rows.append({
                "alg": r.algName, "set": r.set, "pattern": pid,
                "Dstart": f"{r.Dstart:.2f}", "t_start_s": f"{t0:.1f}",
                "t_end_s": f"{t1:.1f}", "P_end_W": f"{p_end:.1f}",
                "t98_s": f"{tk[sel][k] - t0:.2f}",
                "mean_P_W": f"{energy / (t1 - t0):.1f}",
                "E_ratio_pct": f"{100 * energy / (p_g * (t1 - t0)):.1f}",
            })
    with open(csv_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} rows written to {csv_path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
