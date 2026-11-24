function b = bench_curve(G, T, cfg)
%BENCH_CURVE Static curve of one irradiance pattern for the static test bench.
%
%   b = bench_curve(G, T, cfg) returns the curve of pv_array_curve.m on
%   the common voltage grid of the bench (0 V to 200 V, 4000 points) and
%   its peaks (bench_peaks.m):
%     b.Vg     voltage grid (column)
%     b.I      current on the grid
%     b.gmpp   [V P] of the global peak
%     b.peaks  [V P] of each local peak
%   G is 4 x 4 (panels) or 12 x 4 (groups), T the cell temperature [degC].

Vg = linspace(0, 200, 4000)';
c  = pv_array_curve(G, T, cfg, Vg);
c0 = pv_array_curve(G, T, cfg);            % Grid from 0 V to Voc, for the peaks
b.Vg = Vg;
b.I  = c.I;
b.gmpp  = c.gmpp;
b.peaks = bench_peaks(c0);
end
