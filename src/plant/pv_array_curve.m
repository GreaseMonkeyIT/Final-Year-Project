function c = pv_array_curve(G, Tcell, cfg, nV)
%PV_ARRAY_CURVE Static I-V and P-V curve of the 4 x 4 array for any irradiance and temperature.
%
%   c = pv_array_curve(G, Tcell, cfg) returns the static curve of the
%   array of pv4x4_config.m. It uses the equations of the Solar Cell block
%   of Simscape Electrical (datasheet parameterization, one diode, Rp
%   infinite) and the piecewise-linear bypass diode of add_pv_array.m.
%   The function has no Simulink part, so it is fast: it is the plant of
%   the static tests of docs/notes/final_test_plan.md (step 0.3).
%
%   Inputs:
%     G      irradiance [W/m^2]. Nser x Npar (one value for each panel, as
%            shading_patterns.m) or (Nser*Nbyp) x Npar (one value for each
%            bypass-diode group, as shading_patterns_grp.m).
%     Tcell  cell temperature [degC], one value for the full array.
%     cfg    struct of pv4x4_config.m.
%     nV     points of the voltage grid from 0 V to Voc (default 3000), or
%            a voltage grid (a column with more than one value). With a
%            grid, c.V is that grid, and the current is negative above Voc.
%
%   Fields of c:
%     V, I, P   curve from 0 V to the open-circuit voltage (column vectors)
%     gmpp      [V P] of the global peak, refined between grid points
%     Voc, Isc  open-circuit voltage and short-circuit current
%
%   Equations (Simscape Electrical documentation, Solar Cell block). For
%   one cell at the temperature T [K], with T0 = Tmeas:
%     I   = Iph - Is*(exp((V + I*Rs)/(N*Vt)) - 1),   Vt = k*T/q
%     Iph = Isc * (G/Ir0) * (1 + TIPH1*(T - T0))
%     Is  = Is0 * (T/T0)^(TXIS1/N) * exp(EG/(N*Vt) * (T/T0 - 1))
%     Is0 = Isc / (exp(Voc/(N*Vt0)) - 1)
%     Rs  = Rs0 * (T/T0)^TRS1
%   Bypass diode (Simscape Diode, piecewise linear), with Vd = -Vgroup:
%     Id = Vd*Goff                       for Vd <= Vf
%     Id = (Vd - Vf)/Ron + Vf*Goff       for Vd >  Vf
%
%   Method. Each group gives the current of the string as a monotonic
%   function of the cell current, so the group voltage is a table of the
%   string current. The string voltage is the sum of its group voltages.
%   The four strings are in parallel: for each array voltage, the string
%   currents come from the inverse tables and add up.

if nargin < 4, nV = 3000; end
m  = cfg.mod;
Ns = cfg.arr.Nser; Np = cfg.arr.Npar; Nb = m.Nbyp;
if size(G, 1) == Ns
    G = kron(G, ones(Nb, 1));               % Panel values to group values
end
k  = 1.380649e-23; q = 1.602176634e-19;
T0 = m.Tmeas + 273.15;
T  = Tcell + 273.15;
N  = m.n;
Vt0 = k * T0 / q;
Vt  = k * T / q;
Is0 = m.Isc_cell / (exp(m.Voc_cell / (N * Vt0)) - 1);
Is  = Is0 * (T / T0)^(m.TXIS1 / N) * exp(m.EG / (N * Vt) * (T / T0 - 1));
Rs  = m.Rs_cell * (T / T0)^m.TRS1;
Ng  = m.Ncell / Nb;                         % Cells in one group
b   = cfg.byp;

% Common grid of the string current.
Iph_all = m.Isc_cell * G / m.Ir0 * (1 + m.TIPH1 * (T - T0));
Imax = max(Iph_all(:)) + 0.5;
Ig   = [linspace(-3, -0.2, 200)'; linspace(-0.2 + Imax / 20000, Imax, 20000)'];
Vs   = zeros(numel(Ig), Np);

% Table of each distinct irradiance (many groups share a value).
[gu, ~, ix] = unique(Iph_all(:));
Vgu = zeros(numel(Ig), numel(gu));
for u = 1:numel(gu)
    Iph = gu(u);
    dl  = logspace(log10(1e-4 * Is), log10(Iph + Is + Imax + 1), 6000)';   % Iph + Is - Ic
    Ic  = Iph + Is - dl;
    Vg  = Ng * (N * Vt * log(dl / Is) - Ic * Rs);
    Vd  = -Vg;
    Id  = Vd * b.Goff;
    on  = Vd > b.Vf;
    Id(on) = (Vd(on) - b.Vf) / b.Ron + b.Vf * b.Goff;
    Istr = Ic + Id;                          % Rises with Ic
    [Istr, iu] = unique(Istr);
    Vgu(:, u) = interp1(Istr, Vg(iu), Ig, 'linear', 'extrap');
end
Vgrp = reshape(ix, size(Iph_all));
for s = 1:Np
    Vs(:, s) = sum(Vgu(:, Vgrp(:, s)), 2);   % String voltage, falls with the current
end

fixedGrid = numel(nV) > 1;
if fixedGrid
    V = nV(:);
else
    % Open circuit: the voltage where the sum of the string currents is 0.
    Vtry = linspace(0, max(Vs(1, :)), 4000)';
    Itry = arrayCurrent(Vtry, Vs, Ig, Np);
    kz   = find(Itry <= 0, 1);
    Voc  = Vtry(kz - 1) + (Vtry(kz) - Vtry(kz - 1)) * Itry(kz - 1) / (Itry(kz - 1) - Itry(kz));
    V    = linspace(0, Voc, nV)';
end
I = arrayCurrent(V, Vs, Ig, Np);
if ~fixedGrid
    I(end) = max(I(end), 0);
else
    kz  = find(I <= 0, 1);
    Voc = V(end);
    if ~isempty(kz) && kz > 1
        Voc = V(kz - 1) + (V(kz) - V(kz - 1)) * I(kz - 1) / (I(kz - 1) - I(kz));
    end
end
P = V .* I;
c.V = V; c.I = I; c.P = P;
c.Voc = Voc; c.Isc = I(1);

% Refine the global peak between grid points.
[~, j] = max(P);
lo = V(max(j - 1, 1)); hi = V(min(j + 1, numel(V)));
f  = @(v) -v * arrayCurrent(v, Vs, Ig, Np);
[vb, fb] = fminbnd(f, lo, hi, optimset('TolX', 1e-6));
c.gmpp = [vb, -fb];
end

function i = arrayCurrent(v, Vs, Ig, Np)
i = zeros(size(v));
for s = 1:Np
    i = i + interp1(flipud(Vs(:, s)), flipud(Ig), v, 'linear', 'extrap');
end
end
