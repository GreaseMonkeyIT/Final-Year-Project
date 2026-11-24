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
%     ph      phase: 0 wait, 1 global search, 2 tracking (local stage)
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
%   p.alg = 3 to 8: global search, then a local stage.
%     gmppt_search.m selects the search: 3 DIRECT (Nguyen and Low 2010),
%     4 Idea B refined, 5 Idea C, 6 PSO (Ishaque et al. 2012), 7 GWO
%     (Mohanty et al. 2016), 8 not used. Each call of gmppt_search gets
%     the averages of the last probe and gives the next probe duty. At
%     the end of the search, the local stage starts at the hand-over duty.
%
%     Local stage. p.local selects it:
%       1  The P&O of p.alg = 1 with the step p.dD. The first local
%          period measures the hand-over duty and then makes one step
%          (+p.dD) with no test.
%       2  Variable-step INC of Liu et al., IEEE Trans. Ind. Electron.
%          55(7), 2008. The direction comes from the INC test of
%          p.alg = 2, with the same hold band p.eps_inc. The size of the
%          step is p.vs_N * |dP/dV| (Eq. (4) of the paper), kept between
%          p.vs_dDmin and p.vs_dDmax. The first local period makes one
%          step (+p.vs_dDmin) with no test. After a hold, only dI is
%          tested against p.eps_di * I, and the move is p.vs_dDmin in the
%          direction that p.vs_hold_dir gives.
%     With p.paper_end = 1, each search ends as its paper says instead:
%     DIRECT with a P&O of step p.dir_dcr, PSO and GWO with a fixed duty.
%     The search reports this in st.end_kind (gmppt_init.m).
%
%     Restart. A new search starts in two cases:
%       a) Power change. The test is |P - P_ref| > p.dP_restart * P_ref.
%          It is made only at the end of a local period whose duty is the
%          same as the duty of one of the four local periods before it.
%          This occurs when the tracker holds, and when it steps away and
%          comes back (the P&O visits each of its three duties again in
%          four periods). A step of the local stage alone can thus not
%          start a search. With p.restart_ref = 1, P_ref is the power of
%          the latest earlier period with the same duty. With
%          p.restart_ref = 2, P_ref is the power of the first period
%          after the hand-over that has such a match. p.dP_restart = 0
%          turns this test off.
%       b) Timer. After p.T_rescan seconds of the local stage, whatever
%          the power does. p.T_rescan = 0 turns the timer off.
%     Before the first call of a restart, the controller writes the duty
%     and the powers of the restart into st (st.re, st.Dprev, st.Pprev,
%     st.Pnow). Only the PSO start of p.pso_reinit = 1 reads them.
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
persistent loc dDloc heldL armed Dh Ph
if isempty(n)
    n = 0; Vsum = 0; Isum = 0;
    Dk = p.Dstart; Pold = 0; Vold = 0; Iold = 0;
    dirn = 1; held = false; k = 0;
    Vlast = 0; Ilast = 0;
    st = gmppt_init(p);
    mode = 0;                              % 0 wait, 1 global search, 2 tracking
    kt = 0;                                % Local periods after the hand-over
    Pref = 0;                              % Reference power of the restart test
    NperNow = p.Nper;                      % Length and window of the running period
    NavgNow = p.Navg;
    loc = 1;                               % Local stage: 1 P&O, 2 variable-step INC, 3 hold
    dDloc = p.dD;                          % Step of the local P&O
    heldL = false;                         % The variable-step INC held in the last period
    armed = false;                         % p.restart_ref = 2: P_ref is set
    Dh = zeros(1, 4);                      % Duties of the last four local periods
    Ph = zeros(1, 4);                      % Powers of the last four local periods
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
    dDv = 0;                               % Duty step of the local stage after a search
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
            if fin                         % Hand-over to the local stage at Dk
                mode = 2;
                kt = 0;
                dirn = 1;
                heldL = false;
                armed = false;
                loc = p.local;
                dDloc = p.dD;
                if p.paper_end == 1        % Ending of the paper of the search
                    if st.end_kind == 1
                        loc = 1;
                        dDloc = st.end_step;
                    elseif st.end_kind == 2
                        loc = 3;
                    end
                end
            else
                probe = true;
            end
        else
            kt = kt + 1;

            % Restart test a): power change between periods of the same duty.
            % jm is the latest of the last four local periods that had the
            % duty of this period (0 = none).
            jm = 0;
            for j = 1:4
                if jm == 0 && j <= kt - 1 && abs(Dk - Dh(j)) < 1e-9
                    jm = j;
                end
            end
            restart = false;
            Pbefore = P;                   % Power before the change, for st.Pprev
            if p.dP_restart > 0 && jm > 0
                if p.restart_ref == 2
                    if armed
                        restart = abs(P - Pref) > p.dP_restart * Pref;
                    else
                        Pref = P;          % First settled period after the hand-over
                        armed = true;
                    end
                else
                    Pref = Ph(jm);
                    restart = abs(P - Pref) > p.dP_restart * Pref;
                end
                if restart
                    Pbefore = Pref;
                end
            end
            % Restart test b): timer.
            if p.T_rescan > 0 && kt * p.Tmppt >= p.T_rescan
                restart = true;
            end
            for j = 4:-1:2
                Dh(j) = Dh(j-1);
                Ph(j) = Ph(j-1);
            end
            Dh(1) = Dk;
            Ph(1) = P;

            if restart                     % New search from the first probe
                Dold = Dk;
                st = gmppt_init(p);
                st.re    = true;
                st.Dprev = Dold;
                st.Pprev = Pbefore;
                st.Pnow  = P;
                [st, Dk] = gmppt_search(st, p, 0, 0);
                mode = 1;
                probe = true;
            elseif loc == 1                % P&O with the step dDloc
                if kt >= 2 && P < Pold     % kt = 1: perturbation only
                    dirn = -dirn;
                end
                dDv = dirn * dDloc;
            elseif loc == 2                % Variable-step INC
                if kt == 1
                    dDv = p.vs_dDmin;      % Perturbation only
                else
                    dDv = vsIncStep(Vlast, Ilast, Vold, Iold, heldL, p);
                end
                heldL = (kt >= 2) && (dDv == 0);
            end                            % loc = 3: hold the duty
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

    Dk = min(max(Dk + step * p.dD + dDv, p.Dmin), p.Dmax);
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

function dD = vsIncStep(V, I, Vold, Iold, held, p)
% One decision of the variable-step INC of Liu et al. (2008). Returns the
% signed duty step. A negative step raises V. Zero holds the duty.
dV = V - Vold;
dI = I - Iold;
if held || abs(dV) < 1e-6
    % The duty did not change. dP/dV has no meaning here, so the move has
    % the smallest size. p.vs_hold_dir = 1 gives the direction of Fig. 2
    % of the paper: more current, duty up.
    if abs(dI) <= p.eps_di * I
        dD = 0;
    elseif dI > 0
        dD = p.vs_hold_dir * p.vs_dDmin;
    else
        dD = -p.vs_hold_dir * p.vs_dDmin;
    end
else
    e = dI / dV + I / V;                   % Same sign as dP/dV
    if abs(e) <= p.eps_inc * I / V
        dD = 0;                            % At a peak
    else
        s = p.vs_N * abs((V * I - Vold * Iold) / dV);    % Eq. (4) of the paper
        s = min(max(s, p.vs_dDmin), p.vs_dDmax);
        if e > 0
            dD = -s;                       % Left of a peak
        else
            dD = s;                        % Right of a peak
        end
    end
end
end
