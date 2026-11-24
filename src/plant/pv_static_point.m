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
%   The loop form (2026-11-21) gives the same point as find and interp1,
%   and MATLAB Coder accepts it (static_run.m).

k = 0;
for j = 1:numel(Vc)
    if Ic(j) - Vc(j) / Rin < 0
        k = j;
        break
    end
end
if k <= 1
    v = Vc(end);
    i = Ic(end);
else
    f1 = Ic(k-1) - Vc(k-1) / Rin;
    f2 = Ic(k) - Vc(k) / Rin;
    t = f1 / (f1 - f2);
    v = Vc(k-1) + t * (Vc(k) - Vc(k-1));
    i = Ic(k-1) + (v - Vc(k-1)) / (Vc(k) - Vc(k-1)) * (Ic(k) - Ic(k-1));
end
end
