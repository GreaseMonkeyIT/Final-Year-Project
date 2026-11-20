function [D, Vm, Im, ph, np] = mppt_controller(V, I, p)
%MPPT_CONTROLLER Maximum power point tracker that sets the duty cycle directly.
%
%   [D, Vm, Im, ph, np] = mppt_controller(V, I, p) runs once per control
%   sample p.Tc. V and I are the measured PV voltage and current. p is
%   the mppt struct of pv4x4_config. The MATLAB Function block "MPPT" in
%   MPPT_4x4.slx calls this function.
%
%   Timing. One MPPT period has p.Nper control samples. The function adds
%   up V and I over the last p.Navg samples of the period, while the
%   converter has settled. At the end of the period it makes one decision
%   and sets the duty D for the next period. A probe of the global search
%   uses a longer period: p.Nper_s samples, with the average over the
%   last p.Navg_s samples. A large duty jump needs this time to settle
%   (docs/notes/pv4x4_shading_and_po.md, section 5.1).
%
%   Outputs for logging only:
%     Vm, Im  the averages that the last decision used
%     ph      phase: 0 wait, 1 global search, 2 tracking (P&O or INC)
%     np      probes of the global search so far
%
%   The first p.Nwait periods hold the duty at p.Dstart, while the input
%   capacitor charges. Then p.alg selects the rule:
%
%   p.alg = 1: perturb and observe (P&O).
%     The first period makes one duty step (+p.dD) with no test, because
%     the points before it have the same duty. After that: if the power
%     increased, step the duty again in the same direction. If the power
%     decreased, reverse the direction.
%
%   p.alg = 2: incremental conductance (INC). The first step is as P&O.
%     At a peak, dP/dV = 0, which is the same as dI/dV = -I/V.
%     If dI/dV > -I/V, the point is left of a peak: raise V (duty down).
%     If dI/dV < -I/V, the point is right of a peak: lower V (duty up).
%     If |dI/dV + I/V| <= p.eps_inc * I/V, hold the duty.
%     After a hold, V does not change, so only dI is tested: a current
%     change larger than p.eps_di * I means that the irradiance changed.
%
%   p.alg = 3 to 8: global search, then P&O.
%     The slot for the global searches. gmppt_search.m and gmppt_init.m
%     hold them. Today these two files are placeholders that end the
%     search at once (one probe at p.Dstart, then P&O). The searches of
%     the preliminary study are archived in
%     archive/2026-11-21_post_midreview/src/controller/.
%     Each call of gmppt_search gets the averages of the last probe and
%     gives the next probe duty. At the end of the search, the P&O of
%     p.alg = 1 starts at the hand-over duty. Its first period measures the hand-over duty, and its second
%     period makes the first step (+p.dD) with no test.
%     Restart: the power of the first P&O period is P_ref. A new search
%     starts if |P - P_ref| > p.dP_restart * P_ref, or after p.T_rescan
%     seconds of P&O. A value of 0 turns the test off.
%
%   p.alg = 9: replay, for tests of the plant only.
%     From period p.Nwait + 1, the controller applies the entries
%     p.Drep(1) to p.Drep(p.Nrep) in turn, each for p.Nhold periods. Then
%     it holds the last entry. It does not track.
%     experiments/templates/run_settling_check.m uses this mode.
%
%   Any other value of p.alg holds the duty at p.Dstart.
%   In a buck-boost converter, a higher duty gives a lower PV voltage.
%
%   Code generation. The function uses only persistent variables of
%   fixed size and fixed-size arithmetic, so Simulink Coder can generate C
%   code from it for a real-time target such as the dSPACE MicroLabBox.

persistent n Vsum Isum Dk Pold Vold Iold dirn held k Vlast Ilast
persistent st mode kt Pref NperNow NavgNow
if isempty(n)
    n = 0; Vsum = 0; Isum = 0;
    Dk = p.Dstart; Pold = 0; Vold = 0; Iold = 0;
    dirn = 1; held = false; k = 0;
    Vlast = 0; Ilast = 0;
    st = gmppt_init(p);
    mode = 0;                              % 0 wait, 1 global search, 2 tracking
    kt = 0;                                % Tracking periods after the hand-over
    Pref = 0;                              % Power at the hand-over duty
    NperNow = p.Nper;                      % Length and window of the running period
    NavgNow = p.Navg;
end

% Add up the samples of the averaging window.
n = n + 1;
if n > NperNow - NavgNow
    Vsum = Vsum + V;
    Isum = Isum + I;
end

% End of one MPPT period: one decision.
if n >= NperNow
    Vlast = Vsum / NavgNow;
    Ilast = Isum / NavgNow;
    P = Vlast * Ilast;
    k = k + 1;

    step = 0;                              % Duty step: -1, 0, or +1 times p.dD
    probe = false;                         % True: the next period is a search probe
    if p.alg >= 3 && p.alg <= 8
        if mode == 0
            if k >= p.Nwait                % End of the wait: first probe
                st = gmppt_init(p);
                [st, Dk] = gmppt_search(st, p, 0, 0);
                mode = 1;
                probe = true;
            end
        elseif mode == 1
            [st, Dk, fin] = gmppt_search(st, p, Vlast, Ilast);
            if fin                         % Hand-over to P&O at Dk
                mode = 2;
                kt = 0;
                dirn = 1;
            else
                probe = true;
            end
        else
            kt = kt + 1;
            if kt == 1
                Pref = P;                  % Power at the hand-over duty
            end
            restart = (kt >= 2 && p.dP_restart > 0 && abs(P - Pref) > p.dP_restart * Pref) || ...
                      (p.T_rescan > 0 && kt * p.Tmppt >= p.T_rescan);
            if restart                     % New search from the first probe
                st = gmppt_init(p);
                [st, Dk] = gmppt_search(st, p, 0, 0);
                mode = 1;
                probe = true;
            else
                if kt >= 2 && P < Pold     % kt = 1: perturbation only
                    dirn = -dirn;
                end
                step = dirn;
            end
        end
    elseif p.alg == 9
        % Replay: entry j covers the next period.
        j = floor((k - p.Nwait) / p.Nhold) + 1;
        if j >= 1 && j <= p.Nrep
            Dk = p.Drep(j);
        end
    elseif k == p.Nwait + 1
        step = dirn;                       % First step: a perturbation only
        mode = 2;
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
    if probe
        NperNow = p.Nper_s;
        NavgNow = p.Navg_s;
    else
        NperNow = p.Nper;
        NavgNow = p.Navg;
    end
    n = 0; Vsum = 0; Isum = 0;
end

D  = Dk;
Vm = Vlast;
Im = Ilast;
ph = mode;
np = st.np;
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
