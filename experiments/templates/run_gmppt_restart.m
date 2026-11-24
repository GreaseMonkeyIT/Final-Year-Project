%RUN_GMPPT_RESTART Restart of the global search after a change of the shading.
%
%   Note of 2026-11-21: this script is a record of the preliminary study.
%   Its algorithm numbers and result files are those of the preliminary
%   study, not of the current tracker (README.md, section "Templates").
%   The current scripts are experiments/run_gmppt_baseline.m and
%   experiments/run_gmppt_restart_tests.m.
%
%   Task T5 of HANDOFF_ideas_B_C.md. During P&O, the controller starts a
%   new search if |P - P_ref| > mppt.dP_restart * P_ref, or after
%   mppt.T_rescan seconds of P&O (mppt_controller.m). P_ref is the power
%   of the first P&O period, at the hand-over duty.
%
%   1. False restarts. From the start-up runs of run_gmppt_demo.m (set A,
%      no change of the shading, so no restart starts), the
%      script finds the largest |P - P_ref| / P_ref of the P&O stage. It
%      must be below mppt.dP_restart, or the restart starts a search with
%      no reason. The test uses the same averages Vm and Im as the
%      controller, so this check is exact.
%   2. Simulation, with algs = 1 (P&O), 3 (DIRECT), 4 (Idea B), 5 (Idea C):
%      C  Winter morning: R1, then P1 at 1.2 s, then P0 at 2.4 s.
%      E  Winter evening: P0, then P1 at 1.2 s, then R1 at 2.4 s. When
%         the shadow arrives, P&O alone climbs to the local peak of P1 at
%         167 V.
%      Sets C and E run with the restart on and off (P&O only once).
%      T  Timer: Idea C on P1 with mppt.T_rescan = 1 s and no change.
%   For each phase: power (mean of the last 0.3 s of the phase) as a % of
%   the GMPP of the phase, the searches that start in the phase, and the
%   time from the start of the phase to 98 % of its final power.
%
%   Outputs in the folder "results":
%     gmppt_restart.mat, gmppt_restart.csv
%     fig_gmppt_evening.png   set E, restart on and off
%     fig_gmppt_morning.png   set C, restart on and off
%
%   Run scripts/build_mppt_4x4.m, run_pv4x4_sweeps.m and run_gmppt_demo.m
%   first. Run time: about 10 min. To change only the figures, set
%   redraw_only = true. The script then loads results/gmppt_restart.mat.

clear; clc;
projectDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % This script is in <project>/experiments/templates
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
cfg = pv4x4_config();
p0  = cfg.mppt;
st  = plot_style();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
ids = {sw.id};
gm  = @(id) sw(strcmp(ids, id));
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C'};
algCol  = st.series([1 2 3 7 8], :);   % As run_gmppt_demo.m

redraw_only = false;          % true: no simulation. Load results/gmppt_restart.mat and draw the figures again.

if redraw_only
    Lr = load(fullfile(resDir, 'gmppt_restart.mat'));
    R = Lr.R; sets = Lr.sets;
    fprintf('Loaded %d runs from gmppt_restart.mat. No simulation.\n', numel(R));
else
    %% 1. Margin against a false restart (set A of run_gmppt_demo.m)
    L = load(fullfile(resDir, 'gmppt_results.mat'));
    fprintf('Largest |P - P_ref| / P_ref in the P&O stage, set A (limit %.1f %%):\n', 100 * p0.dP_restart);
    dev = zeros(0, 1);
    for a = 3:5
        A = L.R([L.R.set] == 'A' & [L.R.alg] == a);
        d = zeros(numel(A), 1);
        for k = 1:numel(A)
            Pm = A(k).Pm;                                   % Pm(i): period that ends at i * Tmppt
            i0 = round((A(k).tHand + p0.Tmppt) / p0.Tmppt); % First P&O period
            d(k) = max(abs(Pm(i0+1:end) - Pm(i0))) / Pm(i0);
        end
        [dm, km] = max(d);
        fprintf('  %-7s %.2f %% (worst: %s)\n', algName{a}, 100 * dm, A(km).id);
        dev = [dev; d]; %#ok<AGROW>
    end
    fprintf('  All: %.2f %%. Margin to the limit: %.2f %%\n\n', 100 * max(dev), 100 * (p0.dP_restart - max(dev)));

    %% 2. Cases
    tM = [0 1.2 2.4 3.6];
    sets = struct('set', {'C', 'E', 'T'}, 'pats', {{'R1', 'P1', 'P0'}, {'P0', 'P1', 'R1'}, {'P1'}}, ...
                  'tM', {tM, tM, [0 2.5]});
    runs = struct('set', {}, 'alg', {}, 'restart', {}, 'Trescan', {});
    for a = [1 3 4 5], runs(end+1) = struct('set', 'C', 'alg', a, 'restart', true,  'Trescan', 0); end %#ok<SAGROW>
    for a = [1 3 4 5], runs(end+1) = struct('set', 'E', 'alg', a, 'restart', true,  'Trescan', 0); end %#ok<SAGROW>
    for a = [3 4 5],   runs(end+1) = struct('set', 'C', 'alg', a, 'restart', false, 'Trescan', 0); end %#ok<SAGROW>
    for a = [3 4 5],   runs(end+1) = struct('set', 'E', 'alg', a, 'restart', false, 'Trescan', 0); end %#ok<SAGROW>
    runs(end+1) = struct('set', 'T', 'alg', 5, 'restart', true, 'Trescan', 1.0);

    in = Simulink.SimulationInput.empty;
    for r = 1:numel(runs)
        s0 = sets([sets.set] == runs(r).set);
        Gs = zeros(numel(s0.pats), 17);
        for j = 1:numel(s0.pats), Gs(j,:) = [s0.tM(j) gm(s0.pats{j}).G(:)']; end
        m = p0;
        m.alg = runs(r).alg;
        if ~runs(r).restart, m.dP_restart = 0; end
        m.T_rescan = runs(r).Trescan;
        s = Simulink.SimulationInput(mdl);
        s = s.setVariable('mppt',   m,  'Workspace', mdl);
        s = s.setVariable('Gsched', Gs, 'Workspace', mdl);
        s = s.setVariable('Tstop',  s0.tM(end), 'Workspace', mdl);
        in(end+1) = s; %#ok<SAGROW>
    end
    tic;
    out = sim(in, 'ShowProgress', 'off');
    fprintf('%d runs in %.0f s\n\n', numel(in), toc);

    %% Results: one row for each phase of each run
    R = struct('set', {}, 'alg', {}, 'algName', {}, 'restart', {}, 'Trescan', {}, 't', {}, 'P', {}, 'V', {}, ...
               'ph', {}, 'tSearch', {});
    rows = struct('set', {});
    fprintf('%-3s %-7s %-7s %-6s %-3s %8s %8s %8s %8s %9s\n', 'Set', 'Alg', 'Restart', 'Phase', 'Pat', 'P', 'GMPP', ...
            '% GMPP', 'Searches', 't98 [s]');
    for r = 1:numel(runs)
        o  = out(r);
        s0 = sets([sets.set] == runs(r).set);
        x  = struct('set', runs(r).set, 'alg', runs(r).alg, 'algName', algName{runs(r).alg}, ...
                    'restart', runs(r).restart, 'Trescan', runs(r).Trescan, 't', o.Ppv.Time, ...
                    'P', squeeze(o.Ppv.Data), 'V', squeeze(o.Vpv.Data), 'ph', squeeze(o.ph.Data), 'tSearch', []);
        k1 = find(x.ph == 1 & [0; x.ph(1:end-1)] ~= 1);      % First sample of each search
        x.tSearch = x.t(k1);
        R(r) = x;
        for j = 1:numel(s0.pats)
            g  = gm(s0.pats{j});
            ta = s0.tM(j); tb = s0.tM(j+1);
            inP  = x.t >= ta & x.t < tb;
            last = x.t > tb - 0.3 & x.t <= tb;
            Pend = mean(x.P(last));
            kl = find(inP & x.P < 0.98 * Pend, 1, 'last');
            t98 = 0;
            if ~isempty(kl), t98 = x.t(kl + 1) - ta; end
            nS = sum(x.tSearch >= ta & x.tSearch < tb);
            q = numel(rows) + 1;
            rows(q).set = string(x.set); rows(q).alg = string(x.algName);
            rows(q).restart = x.restart; rows(q).T_rescan = x.Trescan;
            rows(q).phase = sprintf('%.1f-%.1f s', ta, tb); rows(q).pattern = string(g.id);
            rows(q).P_W = Pend; rows(q).P_gmpp_W = g.gmpp(2); rows(q).pct_of_gmpp = 100 * Pend / g.gmpp(2);
            rows(q).searches = nS; rows(q).t98_s = t98;
            fprintf('%-3s %-7s %-7s %-6s %-3s %6.0f W %6.0f W %8.1f %8d %9.3f\n', x.set, x.algName, ...
                    ifelse(x.restart, 'on', 'off'), sprintf('%.1f', ta), g.id, Pend, g.gmpp(2), ...
                    100 * Pend / g.gmpp(2), nS, t98);
        end
    end
    rT = R([R.set] == 'T');
    fprintf('\nTimer test (Idea C, P1, T_rescan = 1 s): searches start at %s s\n', mat2str(round(rT.tSearch', 3)));

    T = struct2table(rows(:));
    writetable(T, fullfile(resDir, 'gmppt_restart.csv'));
    save(fullfile(resDir, 'gmppt_restart.mat'), 'R', 'T', 'sets', 'cfg', 'dev');
end   % if redraw_only

%% Figures
sE = sets([sets.set] == 'E');
sC = sets([sets.set] == 'C');
exportgraphics(plot_gmppt_schedule({R([R.set] == 'E' & [R.restart]), R([R.set] == 'E' & ~[R.restart])}, ...
               {'Winter evening, restart on', 'Winter evening, restart off'}, sE.tM, sE.pats, algName, ...
               algCol, gm, st), fullfile(resDir, 'fig_gmppt_evening.png'), 'Resolution', 200);
exportgraphics(plot_gmppt_schedule({R([R.set] == 'C' & [R.restart]), R([R.set] == 'C' & ~[R.restart])}, ...
               {'Winter morning, restart on', 'Winter morning, restart off'}, sC.tM, sC.pats, ...
               algName, algCol, gm, st), fullfile(resDir, 'fig_gmppt_morning.png'), 'Resolution', 200);
close all
fprintf('\nSaved results in %s\n', resDir);

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
