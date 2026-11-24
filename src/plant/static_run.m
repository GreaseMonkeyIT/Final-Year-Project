function [Pl, Vl, Pr, phl, Dl, nS, Es] = static_run(Vg, Ib, Pgb, xc, tk, xk, dxt, Tstop, nLog, rinA, p, s)
%STATIC_RUN One closed-loop run of mppt_controller.m on the static array model.
%
%   [Pl, Vl, Pr, phl, Dl, nS, Es] = static_run(Vg, Ib, Pgb, xc, tk, xk, dxt, Tstop, nLog, rinA, p, s)
%   runs the controller at each control sample p.Tc from t = 0 to Tstop.
%   The plant is static: at each sample, the operating point is the point
%   where the active I-V curve meets the input line of the converter
%   (pv_static_point.m). The sensors and the ADC are those of
%   sensor_adc.m with the values s (s.on = 0: exact values).
%
%   Curve bank. The I-V curves are on one voltage grid Vg (column). Column
%   j of Ib is the curve at the coordinate xc(j), and Pgb(j) is its GMPP
%   power. xc rises. The coordinate can be an irradiance scale (a ramp) or
%   a time (a cloud event). The schedule (tk, xk) gives the coordinate at
%   each time, linear between the points. Two points with the same time
%   make a step. At a coordinate between xc(j) and xc(j+1), the curve is
%   the linear blend of the two columns. The function makes the operating
%   point again when the duty changes or the coordinate moves by more than
%   dxt.
%
%   Other inputs:
%     Tstop   stop time [s]
%     nLog    control samples in one log interval (40 = 2 ms)
%     rinA    [Rload RL]: input resistance of the ideal buck-boost,
%             Rin = (Rload*(1 - D)^2 + RL)/D^2
%     p, s    cfg.mppt and cfg.sens of pv4x4_config.m
%   Outputs, one value for each log interval of nLog control samples:
%   true power Pl [W] and GMPP power Pr [W] (blend of Pgb), both the mean
%   over the interval, so that sum(Pl)*nLog*p.Tc is the exact energy. Vl
%   [V], phase phl (0 wait, 1 search, 2 local stage) and duty Dl are the
%   values at the end of the interval. nS is the number of searches (each
%   change of the phase to 1) and Es [J] the energy lost during the
%   searches (GMPP power minus array power, phase 1), both counted at
%   each control sample.
%
%   The new duty applies from the next control sample, as the unit delay
%   "Computation delay" of MPPT_4x4.slx. The plant has no dynamics, so a
%   probe gives the settled power. Use the MEX file of this function
%   (build/build_static_mex.m). The first call of each run sets p.reset =
%   1, so the controller starts from its first state with no reload of
%   the MEX file.

N   = round(Tstop / p.Tc);
nl  = floor(N / nLog);
Pl  = zeros(nl, 1); Vl = Pl; Pr = Pl; phl = Pl; Dl = Pl;
if s.on ~= 0
    rng(s.seed, 'twister');
end
nC = numel(xc); nK = numel(tk);
Ic = Ib(:, 1);
D = p.Dstart; Dlast = -1; xlast = -1e300; kk = 1;
v0 = 0; i0 = 0; ph = 0; kl = 0; pg = Pgb(1); sP = 0; sR = 0;
nS = 0; Es = 0; phPrev = 0;
for n = 1:N
    t = (n - 1) * p.Tc;
    % Coordinate of the schedule at time t.
    while kk < nK - 1 && t >= tk(kk + 1)
        kk = kk + 1;
    end
    if nK == 1 || t >= tk(nK)
        x = xk(nK);
    elseif t <= tk(1)
        x = xk(1);
    else
        a = (t - tk(kk)) / max(tk(kk + 1) - tk(kk), 1e-12);
        a = min(max(a, 0), 1);
        x = xk(kk) + a * (xk(kk + 1) - xk(kk));
    end
    newx = abs(x - xlast) > dxt;
    if newx
        if nC == 1 || x <= xc(1)
            Ic = Ib(:, 1); pg = Pgb(1);
        elseif x >= xc(nC)
            Ic = Ib(:, nC); pg = Pgb(nC);
        else
            j = 1;
            while xc(j + 1) < x
                j = j + 1;
            end
            b = (x - xc(j)) / (xc(j + 1) - xc(j));
            Ic = (1 - b) * Ib(:, j) + b * Ib(:, j + 1);
            pg = (1 - b) * Pgb(j) + b * Pgb(j + 1);
        end
        xlast = x;
    end
    if D ~= Dlast || newx
        Rin = (rinA(1) * (1 - D)^2 + rinA(2)) / D^2;
        [v0, i0] = pv_static_point(Vg, Ic, Rin);
        Dlast = D;
    end
    w = zeros(1, 4);
    if s.on ~= 0
        w = randn(1, 4);
    end
    [vm, im] = sensor_adc(v0, i0, w, s);
    if n == 1
        p1 = p; p1.reset = 1;              % Start the controller from its first state
        [Dn, ~, ~, ph] = mppt_controller(vm, im, p1);
    else
        [Dn, ~, ~, ph] = mppt_controller(vm, im, p);
    end
    sP = sP + v0 * i0; sR = sR + pg;
    if ph == 1
        Es = Es + (pg - v0 * i0) * p.Tc;
        if phPrev ~= 1
            nS = nS + 1;
        end
    end
    phPrev = ph;
    if mod(n, nLog) == 0
        kl = kl + 1;
        Pl(kl) = sP / nLog; Vl(kl) = v0; Pr(kl) = sR / nLog; phl(kl) = ph; Dl(kl) = D;
        sP = 0; sR = 0;
    end
    D = Dn;
end
end
