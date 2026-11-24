function pk = bench_peaks(c)
%BENCH_PEAKS Local peaks of a static P-V curve.
%
%   pk = bench_peaks(c) returns [V P] of each local peak of the curve c of
%   pv_array_curve.m, one row each, with the voltage rising. A peak counts
%   if its prominence is at least 0.2 % of the largest power. This is the
%   rule of experiments/run_pv4x4_sweeps.m. The global peak uses the
%   refined value c.gmpp.

j  = find(islocalmax(c.P, 'MinProminence', 0.002 * max(c.P)));
pk = [c.V(j) c.P(j)];
[~, g] = max(pk(:, 2));
if isempty(pk), pk = c.gmpp; else, pk(g, :) = c.gmpp; end
end
