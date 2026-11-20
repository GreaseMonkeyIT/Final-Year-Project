function [v, i] = pv_static_point(Vc, Ic, Rin)
%PV_STATIC_POINT Steady-state operating point of the array on a resistive input.
%
%   [v, i] = pv_static_point(Vc, Ic, Rin) returns the point where the
%   static I-V curve (Vc, Ic) meets the line I = V / Rin. Vc rises from
%   0 V to Voc, as in results/pv4x4_sweeps.mat. Rin is the input
%   resistance of the converter.
%
%   The method is the same as Plant.at_duty in archive/2026-11-21_post_midreview/python/algos.py: find
%   the first curve point below the line, then interpolate linearly
%   between that point and the point before it. If the curve never goes
%   below the line, the point is the last curve point (near Voc).

f = Ic - Vc / Rin;
k = find(f < 0, 1);
if isempty(k) || k == 1
    v = Vc(end);
    i = Ic(end);
else
    t = f(k-1) / (f(k-1) - f(k));
    v = Vc(k-1) + t * (Vc(k) - Vc(k-1));
    i = interp1(Vc, Ic, v);
end
end
