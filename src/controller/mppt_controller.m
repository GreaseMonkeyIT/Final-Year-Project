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
%     dI is the change since the first period of the hold (Iref), not
%     since the last period. Changed on 2026-11-22: with the change since
%     the last period, a slow irradiance ramp (about 0.1 % of the current
%     in one period) never ended the hold, and the duty stayed fixed. The
%     reference current is a choice of this project, not of a paper.
%     More current at the held duty moves the duty up, less current moves
%     it down (changed on 2026-11-22, see incStep).
%
%   p.alg = 3 to 8: global search, then a local stage.
%     gmppt_search.m selects the search: 3 DIRECT (Nguyen and Low 2010),
%     4 Idea B refined, 5 Idea C, 6 PSO (Ishaque et al. 2012), 7 GWO
%     (Mohanty et al. 2016), 8 not used. Each call of gmppt_search gets
%     the averages of the last probe and gives the next probe duty. At
%     the end of the search, the local stage starts at the hand-over duty.
%
%     Local stage. p.local selects it. p.local is one value for all the
%     searches, or a list with one entry for each p.alg (entry p.alg is
%     used). The config gives 3 (the parabolic stage) for all five
%     searches.
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
%          direction that p.vs_hold_dir gives. As for p.alg = 2, dI is
%          the change since the first period of the hold (2026-11-22).
%       3  Parabolic stage (added 2026-11-21, docs/notes/
%          gmppt_local_stage_2026-11-21.md, section 5). It uses the
%          samples of the search. The final tests run it after all five
%          searches.
%          a) Fresh reading. The first local period measures the best
%             duty again, with the probe timing. If the power differs from
%             the stored sample by more than p.chk_eps, the stored samples
%             are old: the stage goes to the check (d) at once.
%          b) Refinement. The best sample and its two neighbours on the
%             duty axis give the bracket. A parabola P(D) through three
%             points gives the next duty (Pai et al., IEEE Trans. Sustain.
%             Energy 2(1), 2011, Eqs. (1) to (3)). If the best sample has
%             no neighbour on one side, a probe p.par_h away is taken first
%             (the shifting procedure of Pai et al., section III-A). The
%             safeguards and the end test are those of the procedure
%             localmin of R. P. Brent, "Algorithms for Minimization without
%             Derivatives," 1973, chapter 5, section 4: a golden-section
%             step if the parabolic step is not acceptable, no probe nearer
%             than p.par_tol to a known point, and the end when the bracket
%             is 2 p.par_tol or less on each side. Each refinement probe
%             has the probe timing. At most p.par_kmax probes.
%          c) Hold. The duty stays at the best duty D0.
%          d) Check, after each p.chk_T seconds of hold. Five periods at
%             D0, D0 + d, D0, D0 - d, D0 with d = p.chk_d. Each side power
%             is corrected by the mean of the two centre powers around it.
%             This removes a change of irradiance at a constant rate (the
%             extra measurement of the dP-P&O of Sera et al., IEEE Trans.
%             Ind. Electron. 55(7), 2008, Eq. (1)). A parabola through the
%             three corrected points gives the move of D0, at most 2 d.
%             D0 moves only if the gain is more than p.chk_db * P. If the
%             centre power changed by more than p.chk_ramp * P during the
%             check, the next check follows at once. The next check also
%             follows at once if the move was at its limit: the peak of the
%             parabola is more than 2 d away, or the fit has no maximum and
%             D0 moved one step d to the higher side (added on 2026-11-22,
%             a choice of this project: far from the peak the stage then
%             moves 2 d in each check of 0.1 s, not in each p.chk_T).
%       4  The INC of p.alg = 2 (the INC of the mid-review) with the
%          fixed step p.dD, the hold band p.eps_inc and the current band
%          p.eps_di (added 2026-11-21 for the comparison of the local
%          stages, docs/notes/final_test_plan.md). The first local period
%          makes one step (+p.dD) with no test.
%     With p.paper_end = 1, each search ends as its paper says instead:
%     DIRECT with a P&O of step p.dir_dcr, PSO and GWO with a fixed duty.
%     The search reports this in st.end_kind (gmppt_init.m).
%
%     Restart. A new search starts in two cases:
%       a) Power change. The test is |P - P_ref| > p.dP_restart * P_ref
%          (a level test as in Wang et al. 2016, Furtado et al. 2018, Li
%          et al. 2019 and Ahmed et al. 2023), made only in steady state
%          (Boztepe et al. 2014: no test until the tracker settles). Steady
%          state: the power changes by at most p.st_band * P per period,
%          measured over the last p.st_win periods (since 2026-11-23, so
%          that sensor noise does not block the test).
%          P_ref is the power at the first steady state after the hand-over,
%          when the local stage has settled. Parabolic stage (p.local = 3):
%          the test runs in each hold period. The slope of a least-squares
%          line through the powers of the last p.st_win hold periods gives
%          the rate of change. A check (a move of the duty) starts a new
%          window.
%          Local stages 1, 2 and 4: the test is made only at the end of a
%          local period whose duty is the same as the duty of one of the
%          four local periods before it (the P&O visits each of its three
%          duties again in four periods), so a step of the local stage
%          alone cannot start a search. With p.restart_ref = 2, the rate of
%          change is the mean of (P - P of the matched period) / jm over the
%          last p.st_win matched periods. With
%          p.restart_ref = 1, P_ref is the power of the matched period
%          (a test of the rate of change, used until 2026-11-22).
%          p.dP_restart = 0 turns this test off.
%       Voltage hold (p.local = 3, p.vh_on = 1, added 2026-11-22). In the
%          hold between two checks, the stage moves the duty so that the
%          voltage stays at the voltage V0 of the first hold period. A
%          change of irradiance on all panels moves the peak voltage only
%          a little, so the operating point stays near the peak while the
%          light changes (the reason for the voltage loop of Boztepe et al.
%          2014, Furtado et al. 2018 and Kermadi et al. 2019). The step
%          uses the relation of the ideal buck-boost (see loc3Step).
%       Power floor (added 2026-11-24). The level test a) is off while
%          the power is below p.P_floor, and on again above
%          p.P_floor_hys * p.P_floor. P_ref does not change below the
%          floor. p.P_floor = 0 turns the floor off.
%       b) Timer. After p.T_rescan seconds of the local stage, whatever
%          the power does. p.T_rescan = 0 turns the timer off. The time
%          is counted in control samples, so the longer probe periods of
%          the parabolic stage count with their true length.
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
persistent loc dDloc heldL armed Dh Ph nl L Iref Rw nR lowP
if isempty(n) || p.reset == 1              % p.reset: static test bench only (static_run.m)
    lowP = false;                          % The power is below the floor p.P_floor
    n = 0; Vsum = 0; Isum = 0;
    Dk = p.Dstart; Pold = 0; Vold = 0; Iold = 0;
    Iref = 0;                              % INC and VS-INC: current at the start of the hold
    Rw = zeros(1, 32);                     % Local stages 1, 2, 4: rates of change of the last
    nR = 0;                                % matched periods (newest first) and their number
    dirn = 1; held = false; k = 0;
    Vlast = 0; Ilast = 0;
    st = gmppt_init(p);
    mode = 0;                              % 0 wait, 1 global search, 2 tracking
    kt = 0;                                % Local periods after the hand-over
    Pref = 0;                              % Reference power of the restart test
    NperNow = p.Nper;                      % Length and window of the running period
    NavgNow = p.Navg;
    loc = 1;                               % Local stage: 1 P&O, 2 variable-step INC,
                                           % 3 parabolic stage, 4 INC, 0 hold
    nl = 0;                                % Control samples of the local stage
    L = loc3Init(st, p);                   % State of the parabolic stage
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
                nR = 0;
                nl = 0;
                if numel(p.local) >= p.alg     % One entry for each p.alg
                    loc = p.local(p.alg);
                else                           % One value for all searches
                    loc = p.local(1);
                end
                dDloc = p.dD;
                if p.paper_end == 1        % Ending of the paper of the search
                    if st.end_kind == 1
                        loc = 1;
                        dDloc = st.end_step;
                    elseif st.end_kind == 2
                        loc = 0;
                    end
                end
                if loc == 3                % Parabolic stage: fresh reading at the best duty
                    L = loc3Init(st, p);
                    Dk = L.x;
                    probe = true;
                end
            else
                probe = true;
            end
        else
            kt = kt + 1;
            nl = nl + NperNow;             % Length of the period that just ended

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
            if p.dP_restart > 0 && jm > 0 && loc ~= 3   % Stage 3 has its own test (loc3Step)
                if p.restart_ref == 2
                    % Steady state (Boztepe et al. 2014: no test until the
                    % tracker settles): the mean rate of change of the last
                    % p.st_win matched periods is at most p.st_band * P per
                    % period. Each rate is (P - P of the matched period) / jm.
                    % The mean over the window keeps the sensor noise below the
                    % band (changed on 2026-11-23, see loc3Step).
                    [Rw, nR] = winPush(Rw, nR, (P - Ph(jm)) / jm);
                    if nR >= p.st_win && abs(winMean(Rw, p.st_win)) <= p.st_band * P
                        if armed
                            restart = abs(P - Pref) > p.dP_restart * Pref;   % Level test
                        else
                            % First steady state after the hand-over: the local
                            % stage has settled, so its power is the reference.
                            % (Changed on 2026-11-22: before, P_ref was the power
                            % of the first matched period, which can fall while
                            % the local stage still climbs.)
                            Pref = P;
                            armed = true;
                        end
                    end
                else
                    Pref = Ph(jm);
                    restart = abs(P - Pref) > p.dP_restart * Pref;
                end
                if restart
                    Pbefore = Pref;
                end
            end
            % Parabolic stage: one decision. In its hold it holds the voltage
            % and makes the level test in steady state (loc3Step).
            Dn = Dk;
            if loc == 3
                [L, Dn, probe, trig] = loc3Step(L, P, Vlast, NperNow, p);
                if trig
                    restart = true;
                    Pbefore = L.Pref;
                end
            end
            % Power floor (2026-11-24): no level test while the power is
            % below p.P_floor. The test is on again above p.P_floor_hys *
            % p.P_floor. The timer still runs.
            if p.P_floor > 0
                if P < p.P_floor
                    lowP = true;
                elseif P > p.P_floor_hys * p.P_floor
                    lowP = false;
                end
                if lowP
                    restart = false;
                end
            end
            % Restart test b): timer.
            if p.T_rescan > 0 && nl >= round(p.T_rescan / p.Tc)
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
                rs = st.rng;               % Keep the random generator state of the last search
                st = gmppt_init(p);
                st.rng = rs;
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
                    dDv = vsIncStep(Vlast, Ilast, Vold, Iold, heldL, Iref, p);
                    if dDv == 0 && ~heldL
                        Iref = Ilast;      % Start of a hold: keep the current
                    end
                end
                heldL = (kt >= 2) && (dDv == 0);
            elseif loc == 3                % Parabolic stage (decision made above)
                dDv = Dn - Dk;
            elseif loc == 4                % INC of p.alg = 2 with the step p.dD
                if kt == 1
                    dDv = p.dD;            % Perturbation only
                    heldL = false;
                else
                    sL = incStep(Vlast, Ilast, Vold, Iold, heldL, Iref, p);
                    if sL == 0 && ~heldL
                        Iref = Ilast;      % Start of a hold: keep the current
                    end
                    dDv = sL * p.dD;
                    heldL = (sL == 0);
                end
            end                            % loc = 0: hold the duty
        end
    elseif p.alg == 9
        % Replay: entry j covers the next period.
        j = floor((k - p.Nwait) / p.Nhold) + 1;
        if j >= 1 && j <= p.Nrep
            Dk = p.Drep(j);
        end
    elseif k == p.Nwait
        % First step: a perturbation only. At the end of period Nwait, as the
        % first probe of a global search (changed on 2026-11-22: before, at
        % the end of period Nwait + 1, one period later than the searches).
        step = dirn;
        mode = 2;
    elseif k > p.Nwait
        if p.alg == 1
            if P < Pold
                dirn = -dirn;
            end
            step = dirn;
        elseif p.alg == 2
            step = incStep(Vlast, Ilast, Vold, Iold, held, Iref, p);
            if step == 0 && ~held
                Iref = Ilast;              % Start of a hold: keep the current
            end
        end
    end
    held = (k > p.Nwait) && (step == 0);

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

function step = incStep(V, I, Vold, Iold, held, Iref, p)
% One INC decision. Returns the duty step: -1 (V up), 0 (hold), or +1 (V down).
% Iref is the current at the start of the hold (used only if held).
dV = V - Vold;
dI = I - Iold;
if held
    dI = I - Iref;                         % Change since the start of the hold
end
if held || abs(dV) < 1e-6
    % The duty did not change, so only a change of irradiance can change
    % the current. At a fixed duty the input resistance of the converter is
    % fixed. More light then moves the operating point to a voltage above
    % the new MPP (the MPP voltage changes much less), so the duty must go
    % up. Less light moves it below the MPP, so the duty must go down.
    % Changed on 2026-11-22. Before, more current gave duty down: the rule
    % of INC with a voltage reference, where V stays fixed during a hold.
    % The variable-step INC uses the same direction (p.vs_hold_dir = 1).
    if abs(dI) <= p.eps_di * I
        step = 0;
    elseif dI > 0
        step = 1;                          % More light: duty up
    else
        step = -1;                         % Less light: duty down
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

function dD = vsIncStep(V, I, Vold, Iold, held, Iref, p)
% One decision of the variable-step INC of Liu et al. (2008). Returns the
% signed duty step. A negative step raises V. Zero holds the duty.
% Iref is the current at the start of the hold (used only if held).
dV = V - Vold;
dI = I - Iold;
if held
    dI = I - Iref;                         % Change since the start of the hold
end
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

function L = loc3Init(st, p)
% State of the parabolic stage (p.local = 3) at a hand-over. The bracket
% comes from the sample store of the search: the best sample and its
% nearest neighbours with a different duty. f = -P, because the procedure
% of Brent finds a minimum.
L.ph   = 1;                                % 1 fresh reading, 2 end probe, 5 refinement probe,
                                           % 3 hold, 4 check
L.x    = p.Dstart;  L.fx = 0;  L.Pst = 0;  % Best point and its stored power
L.a    = p.Dmin;    L.fa = 0;  L.hasA = false;
L.b    = p.Dmax;    L.fb = 0;  L.hasB = false;
L.w    = p.Dstart;  L.fw = 0;              % Points w and v of Brent
L.v    = p.Dstart;  L.fv = 0;
L.d    = 0;         L.e  = 0;  L.u = p.Dstart;
L.go   = false;                            % The refinement has its start values
L.np   = 0;                                % Probes of the stage
L.pend = 0;                                % End probe: 1 at a, 2 at b
L.D0   = p.Dstart;                         % Duty of the hold
L.th   = 0;                                % Control samples of the hold
L.ci   = 0;                                % Period of the check, 1 to 5
L.cP   = zeros(1, 5);                      % Powers of the check
L.cV   = zeros(1, 5);                      % Voltages of the check
L.V0   = 0;                                % Voltage of the hold (voltage hold, p.vh_on = 1)
L.vset = false;                            % V0 is set for this hold
L.Pref = 0;                               % Reference power of the level test (0 = not set)
L.Pw   = zeros(1, 32);                     % Powers of the last hold periods, newest first
L.nw   = 0;                                % Number of powers in L.Pw
if st.n >= 1
    ib = st.ib;
    k = 1;
    for j = 1:st.n
        if st.ord(j) == ib
            k = j;
        end
    end
    L.x   = st.D(ib);
    L.Pst = st.P(ib);
    L.fx  = -st.P(ib);
    L.D0  = L.x;
    j = k - 1;                             % Left neighbour with a lower duty
    while j >= 1 && st.D(st.ord(j)) > L.x - 1e-9
        j = j - 1;
    end
    if j >= 1
        L.a = st.D(st.ord(j));
        L.fa = -st.P(st.ord(j));
        L.hasA = true;
    else
        L.a = max(L.x - p.par_h, p.Dmin);
    end
    j = k + 1;                             % Right neighbour with a higher duty
    while j <= st.n && st.D(st.ord(j)) < L.x + 1e-9
        j = j + 1;
    end
    if j <= st.n
        L.b = st.D(st.ord(j));
        L.fb = -st.P(st.ord(j));
        L.hasB = true;
    else
        L.b = min(L.x + p.par_h, p.Dmax);
    end
end
end

function [L, Dn, probe, trig] = loc3Step(L, P, V, Nlen, p)
% One decision of the parabolic stage. P and V are the power and the
% voltage of the period that just ended and Nlen its length in control
% samples. Dn is the duty of the next period. probe = true gives the next
% period the probe timing. trig = true asks for a new global search (the
% level test of the hold).
Dn = L.D0;
probe = false;
trig = false;
if L.ph == 1                               % Fresh reading at the best duty
    if abs(P - L.Pst) > p.chk_eps * L.Pst
        L.D0 = L.x;                        % The stored samples are old: check at once
        L.ph = 4;
        L.ci = 1;
        L.cP(1) = P;
        L.cV(1) = V;
        Dn = L.D0 + p.chk_d;
        return
    end
    L.fx = -P;
    [L, Dn, probe] = loc3Next(L, p);
elseif L.ph == 2                           % End probe (shifting procedure of Pai et al.)
    f = -P;
    if L.pend == 1
        if f < L.fx                        % The end is better: shift to the left
            L.b = L.x;  L.fb = L.fx;  L.hasB = true;
            L.x = L.a;  L.fx = f;
            L.a = max(L.x - p.par_h, p.Dmin);
            L.hasA = false;
        else
            L.fa = f;
            L.hasA = true;
        end
    else
        if f < L.fx                        % The end is better: shift to the right
            L.a = L.x;  L.fa = L.fx;  L.hasA = true;
            L.x = L.b;  L.fx = f;
            L.b = min(L.x + p.par_h, p.Dmax);
            L.hasB = false;
        else
            L.fb = f;
            L.hasB = true;
        end
    end
    [L, Dn, probe] = loc3Next(L, p);
elseif L.ph == 5                           % Refinement probe at u: update of Brent
    fu = -P;
    u = L.u;
    if fu <= L.fx
        if u >= L.x
            L.a = L.x;
        else
            L.b = L.x;
        end
        L.v = L.w;  L.fv = L.fw;
        L.w = L.x;  L.fw = L.fx;
        L.x = u;    L.fx = fu;
    else
        if u < L.x
            L.a = u;
        else
            L.b = u;
        end
        if fu <= L.fw || L.w == L.x
            L.v = L.w;  L.fv = L.fw;
            L.w = u;    L.fw = fu;
        elseif fu <= L.fv || L.v == L.x || L.v == L.w
            L.v = u;    L.fv = fu;
        end
    end
    [L, Dn, probe] = loc3Next(L, p);
elseif L.ph == 3                           % Hold
    L.th = L.th + Nlen;
    if ~L.vset                             % First hold period after the refinement or a check
        L.V0 = V;
        L.vset = true;
        L.nw = 0;                          % The duty moved: a new window of powers
        [L.Pw, L.nw] = winPush(L.Pw, L.nw, P);
    else
        % Steady state (Boztepe et al. 2014: no test until the tracker
        % settles): the slope of a least-squares line through the powers
        % of the last p.st_win hold periods is at most p.st_band * P per
        % period. Changed on 2026-11-23 with the approval of the user. Before,
        % the power had to change by at most p.st_band * P in each of
        % p.st_N periods in a row. The sensor noise of one period is larger
        % than this band at 1 x noise below about 300 W/m2 and at 10 x noise
        % in full sun, so no test was made (phase p3n). The fit over 10
        % periods lowers the noise of the slope by a factor of about 9.
        [L.Pw, L.nw] = winPush(L.Pw, L.nw, P);
        steady = L.nw >= p.st_win && abs(winSlope(L.Pw, p.st_win)) <= p.st_band * P;
        % Level test (Wang et al. 2016, Furtado et al. 2018, Li et al. 2019,
        % Ahmed et al. 2023): the power differs from the power after the
        % hand-over by more than p.dP_restart, however slow the change was.
        if steady
            if L.Pref <= 0
                L.Pref = P;                % First steady hold after the hand-over: reference power
            elseif p.dP_restart > 0 && abs(P - L.Pref) > p.dP_restart * L.Pref
                trig = true;
            end
        end
        % Voltage hold: move the duty so that V goes back to V0. For the
        % ideal buck-boost, ln R_in = ln R_load + 2 x with x = ln((1 - D) / D),
        % the relation of the corner split (gmppt_ceiling.m). With the
        % current taken as constant, V0 needs ln R to change by ln(V0 / V),
        % so x changes by ln(V0 / V) / 2. Near the peak the current also
        % changes, so this step is smaller than the full step and does not
        % overshoot. A higher V needs a higher duty.
        if p.vh_on == 1 && V > 0 && L.V0 > 0
            x  = log((1 - L.D0) / L.D0);
            xs = x + 0.5 * p.vh_k * log(L.V0 / V);
            dv = 1 / (1 + exp(xs)) - L.D0;
            dv = min(max(dv, -p.vh_max), p.vh_max);
            L.D0 = min(max(L.D0 + dv, p.Dmin), p.Dmax);
        end
    end
    Dn = L.D0;
    if p.chk_T > 0 && L.th >= round(p.chk_T / p.Tc)
        L.ph = 4;
        L.ci = 1;
        L.cP(1) = P;
        L.cV(1) = V;
        Dn = L.D0 + p.chk_d;
    end
else                                       % Check: D0, D0 + d, D0, D0 - d, D0
    L.ci = L.ci + 1;
    L.cP(L.ci) = P;
    L.cV(L.ci) = V;
    if L.ci == 2 || L.ci == 4
        Dn = L.D0;
    elseif L.ci == 3
        Dn = L.D0 - p.chk_d;
    else
        % Side powers, corrected by the mean of the centre powers around them
        dp = L.cP(2) - 0.5 * (L.cP(1) + L.cP(3));
        dm = L.cP(4) - 0.5 * (L.cP(3) + L.cP(5));
        c2 = 0.5 * (dp + dm);              % Parabola c2 z^2 + s1 z, z in units of d
        s1 = 0.5 * (dp - dm);
        Pr = L.cP(3);
        sh = 0;
        lim = false;                       % The move is at its limit: the peak is further away
        if c2 < 0
            if -s1 * s1 / (4 * c2) > p.chk_db * Pr
                z = -s1 / (2 * c2);
                lim = abs(z) > 2;
                sh = min(max(z, -2), 2) * p.chk_d;
            end
        elseif dp > dm && dp > p.chk_db * Pr
            sh = p.chk_d;                  % No maximum in the fit: one step to the higher side
            lim = true;
        elseif dm > dp && dm > p.chk_db * Pr
            sh = -p.chk_d;
            lim = true;
        end
        L.D0 = min(max(L.D0 + sh, p.Dmin), p.Dmax);
        L.ph = 3;
        L.th = 0;
        L.vset = false;                    % The next hold period sets V0 again
        drift = abs(L.cP(5) - L.cP(1)) > p.chk_ramp * Pr;
        if (drift && p.vh_on == 0) || lim
            L.th = round(p.chk_T / p.Tc);  % The power drifts (without the voltage hold), or the
        end                                % move was at its limit: the next check follows at once
        Dn = L.D0;
    end
end
end

function [L, Dn, probe] = loc3Next(L, p)
% Next probe of the refinement, or the end of the refinement.
% A missing end of the bracket first (Pai et al.), then the steps of Brent.
probe = true;
if ~L.hasA && L.np < p.par_kmax && L.a < L.x - 1e-9
    L.pend = 1;  L.ph = 2;  L.np = L.np + 1;  Dn = L.a;
    return
end
if ~L.hasB && L.np < p.par_kmax && L.b > L.x + 1e-9
    L.pend = 2;  L.ph = 2;  L.np = L.np + 1;  Dn = L.b;
    return
end
if ~L.go                                   % Start values of Brent: w is the better neighbour
    L.go = true;
    if L.hasA && L.hasB
        if L.fa <= L.fb
            L.w = L.a;  L.fw = L.fa;  L.v = L.b;  L.fv = L.fb;
        else
            L.w = L.b;  L.fw = L.fb;  L.v = L.a;  L.fv = L.fa;
        end
    elseif L.hasA
        L.w = L.a;  L.fw = L.fa;  L.v = L.a;  L.fv = L.fa;
    elseif L.hasB
        L.w = L.b;  L.fw = L.fb;  L.v = L.b;  L.fv = L.fb;
    else
        L.w = L.x;  L.fw = L.fx;  L.v = L.x;  L.fv = L.fx;
    end
    L.d = 0;
    L.e = L.b - L.a;                       % Brent starts with e = 0 (a golden step). Here three
                                           % points are known, so the first step may be
                                           % parabolic, as in Pai et al.
end
cg   = 0.5 * (3 - sqrt(5));                % 0.381966, Eq. (4.1) of Brent
xm   = 0.5 * (L.a + L.b);
tol1 = p.par_tol;
tol2 = 2 * tol1;
if abs(L.x - xm) <= tol2 - 0.5 * (L.b - L.a) || L.np >= p.par_kmax
    L.D0 = L.x;                            % End of the refinement: hold at the best point
    L.ph = 3;
    L.th = 0;
    Dn = L.x;
    probe = false;
    return
end
golden = true;
if abs(L.e) > tol1                         % Parabola through x, w and v, Eqs. (4.3) to (4.6)
    r  = (L.x - L.w) * (L.fx - L.fv);
    q  = (L.x - L.v) * (L.fx - L.fw);
    pp = (L.x - L.v) * q - (L.x - L.w) * r;
    q  = 2 * (q - r);
    if q > 0
        pp = -pp;
    end
    q = abs(q);
    etemp = L.e;
    L.e = L.d;
    if ~(abs(pp) >= abs(0.5 * q * etemp) || pp <= q * (L.a - L.x) || pp >= q * (L.b - L.x))
        L.d = pp / q;                      % Parabolic step
        u = L.x + L.d;
        if (u - L.a) < tol2 || (L.b - u) < tol2
            L.d = tol1 * sgn(xm - L.x);
        end
        golden = false;
    end
end
if golden                                  % Golden-section step, Eq. (4.7)
    if L.x >= xm
        L.e = L.a - L.x;
    else
        L.e = L.b - L.x;
    end
    L.d = cg * L.e;
end
if abs(L.d) >= tol1
    u = L.x + L.d;
else
    u = L.x + tol1 * sgn(L.d);
end
L.u  = u;
L.np = L.np + 1;
L.ph = 5;
Dn   = u;
end

function s = sgn(x)
% Sign with sgn(0) = 1, as in the procedure localmin of Brent.
if x >= 0
    s = 1;
else
    s = -1;
end
end

function [w, nw] = winPush(w, nw, x)
% Put x at the front of the window w (newest first). nw counts the values,
% up to the size of w (32). Fixed size for code generation.
for j = numel(w):-1:2
    w(j) = w(j - 1);
end
w(1) = x;
nw = min(nw + 1, numel(w));
end

function m = winMean(w, N)
% Mean of the newest N values of the window w.
s = 0;
for j = 1:N
    s = s + w(j);
end
m = s / N;
end

function b = winSlope(w, N)
% Slope per period of the least-squares line through the newest N values
% of the window w (w(1) is the newest, at time N; w(N) at time 1).
tm = (N + 1) / 2;
sxy = 0; sxx = 0;
for j = 1:N
    tj = N - j + 1 - tm;
    sxy = sxy + tj * w(j);
    sxx = sxx + tj * tj;
end
b = sxy / sxx;
end
