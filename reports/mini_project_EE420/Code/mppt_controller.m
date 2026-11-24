function [D, Vm, Im] = mppt_controller(V, I, p)
%MPPT_CONTROLLER Maximum power point tracker that sets the duty cycle directly.
%
%   [D, Vm, Im] = mppt_controller(V, I, p) runs once per control sample
%   p.Tc. V and I are the measured PV voltage and current. p is the mppt
%   struct of pv4x4_config. The MATLAB Function block "MPPT" in
%   MPPT_4x4.slx calls this function.
%
%   Timing. One MPPT period has p.Nper control samples. The function adds
%   up V and I over the last p.Navg samples of the period, while the
%   converter has settled. At the end of the period it makes one decision
%   and sets the duty D for the next period. Vm and Im are the averages
%   that the last decision used. They are outputs for logging only.
%
%   The first p.Nwait periods hold the duty at p.Dstart, while the input
%   capacitor charges. The next period makes one duty step (+p.dD) with no
%   test, because the points before it have the same duty. After that,
%   p.alg selects the rule:
%
%   p.alg = 1: perturb and observe (P&O).
%     If the power increased, step the duty again in the same direction.
%     If the power decreased, reverse the direction.
%
%   p.alg = 2: incremental conductance (INC).
%     At a peak, dP/dV = 0, which is the same as dI/dV = -I/V.
%     If dI/dV > -I/V, the point is left of a peak: raise V (duty down).
%     If dI/dV < -I/V, the point is right of a peak: lower V (duty up).
%     If |dI/dV + I/V| <= p.eps_inc * I/V, hold the duty.
%     After a hold, V does not change, so only dI is tested: a current
%     change larger than p.eps_di * I means that the irradiance changed.
%
%   Any other value of p.alg holds the duty at p.Dstart.
%   In a buck-boost converter, a higher duty gives a lower PV voltage.
%
%   Code generation. The function uses only persistent scalars and
%   fixed-size arithmetic, so Simulink Coder can generate C code from it
%   for a real-time target such as the dSPACE MicroLabBox.

persistent n Vsum Isum Dk Pold Vold Iold dirn held k Vlast Ilast
if isempty(n)
    n = 0; Vsum = 0; Isum = 0;
    Dk = p.Dstart; Pold = 0; Vold = 0; Iold = 0;
    dirn = 1; held = false; k = 0;
    Vlast = 0; Ilast = 0;
end

% Add up the samples of the averaging window.
n = n + 1;
if n > p.Nper - p.Navg
    Vsum = Vsum + V;
    Isum = Isum + I;
end

% End of one MPPT period: one decision.
if n >= p.Nper
    Vlast = Vsum / p.Navg;
    Ilast = Isum / p.Navg;
    P = Vlast * Ilast;
    k = k + 1;

    step = 0;                              % Duty step: -1, 0, or +1 times p.dD
    if k == p.Nwait + 1
        step = dirn;                       % First step: a perturbation only
    elseif k > p.Nwait + 1
        if p.alg == 1
            if P < Pold
                dirn = -dirn;
            end
            step = dirn;
        elseif p.alg == 2
            step = incStep(Vlast, Ilast, Vold, Iold, held, p);
        end
    end
    held = (k > p.Nwait + 1) && (step == 0);

    Dk = min(max(Dk + step * p.dD, p.Dmin), p.Dmax);
    Pold = P; Vold = Vlast; Iold = Ilast;
    n = 0; Vsum = 0; Isum = 0;
end

D  = Dk;
Vm = Vlast;
Im = Ilast;
end

function step = incStep(V, I, Vold, Iold, held, p)
% One INC decision. Returns the duty step: -1 (V up), 0 (hold), or +1 (V down).
dV = V - Vold;
dI = I - Iold;
if held || abs(dV) < 1e-6
    % The duty did not change, so only a change of irradiance can change
    % the current. More current means that the MPP voltage is higher.
    if abs(dI) <= p.eps_di * I
        step = 0;
    elseif dI > 0
        step = -1;
    else
        step = 1;
    end
else
    e = dI / dV + I / V;                   % Same sign as dP/dV
    if abs(e) <= p.eps_inc * I / V
        step = 0;                          % At a peak
    elseif e > 0
        step = -1;                         % Left of a peak
    else
        step = 1;                          % Right of a peak
    end
end
end
