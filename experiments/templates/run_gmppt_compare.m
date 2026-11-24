%RUN_GMPPT_COMPARE Run Idea B, its refined form and the two baselines in MPPT_4x4.slx.
%
%   Note of 2026-11-21: this script is a record of the preliminary study.
%   Its algorithm numbers and result files are those of the preliminary
%   study, not of the current tracker (README.md, section "Templates").
%   The current scripts are experiments/run_gmppt_baseline.m and
%   experiments/run_gmppt_restart_tests.m.
%
%   Made on 2026-11-08 from run_gmppt_demo.m, with the same cases and the
%   same values. The script runs MPPT_4x4.slx for each case of the section
%   "Cases", once for each algorithm in the list algs:
%     1 P&O (reference), 3 DIRECT (simplified form), 4 Idea B,
%     6 DIRECT as in Nguyen and Low (2010), 7 PSO after Ishaque et al.
%     (2012), 8 Idea B refined.
%   The rows of algs 1, 3 and 4 must be the same as in
%   results/gmppt_results.csv (run_gmppt_demo.m). The script prints the
%   largest difference.
%   The sets are the same as in run_po_demo.m:
%     A. Start-up. Each pattern of shading_patterns.m, from the start duty.
%     B. Start point. P1 and P3 again, with a different start duty. A
%        global search does not depend much on the start point.
%     C. Winter morning. R1, then P1 at 1.2 s, then P0 at 2.4 s.
%   The global peak (GMPP) of each pattern comes from run_pv4x4_sweeps.m.
%   The global searches restart after a change of the shading, with the
%   values of pv4x4_config.m (mppt.dP_restart). run_gmppt_restart.m
%   compares sets C and E with the restart on and off.
%
%   Values for each run (sets A and B):
%     nSearch  search probes before the hand-over to P&O
%     tHand    time of the hand-over [s]
%     t98      time after which the power stays at 98 % of the final power or more [s]
%     pct      final power (mean of the last 0.3 s), % of the GMPP
%     eff1s    mean power over the first 1 s, % of the GMPP
%   Set C gives the power of each phase (mean of the last 0.3 s of the
%   phase), % of the GMPP of that phase.
%
%   Outputs in the folder "results":
%     gmppt_compare.mat, gmppt_compare.csv   all runs
%     fig_compare_summary.png  final power, search probes and t98, set A
%     fig_compare_time.png     power against time for P1, P3 and R1, set A
%     fig_<alg>_morning.png    power and voltage against time, set C, for
%                              <alg> = directpaper, pso, ideabref
%
%   Run scripts/build_mppt_4x4.m and run_pv4x4_sweeps.m first.
%   Run time: about 35 min. To change only the figures, set
%   redraw_only = true. The script then loads results/gmppt_compare.mat.

clear; clc;
projectDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));   % This script is in <project>/experiments/templates
run(fullfile(projectDir, 'startup.m'));             % Project folders on the path
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
cfg = pv4x4_config();
st  = plot_style();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
ids = {sw.id};
gm  = @(id) sw(strcmp(ids, id));

redraw_only = false;          % true: no simulation. Load results/gmppt_compare.mat and draw the figures again.
algs    = [1 3 4 6 7 8];      % 1 = P&O, 3 = DIRECT, 4 = Idea B, 6 = DIRECT (paper), 7 = PSO, 8 = Idea B refined
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'DIRECT (paper)', 'PSO', 'Idea B refined'};
algFile = {'po', 'inc', 'direct', 'ideab', 'ideac', 'directpaper', 'pso', 'ideabref'};
algCol  = st.series([1 2 3 7 8 4 5 6], :);   % One colour for each algorithm, in every figure

%% Cases: one simulation run for each case and algorithm (see run_po_demo.m)
Tstatic = 2.5;
cases = struct('set', {}, 'id', {}, 'Dstart', {}, 'Gsched', {}, 'Tstop', {});
for k = 1:numel(sw)
    cases(end+1) = struct('set', 'A', 'id', sw(k).id, 'Dstart', cfg.mppt.Dstart, ...
                          'Gsched', [0 sw(k).G(:)'], 'Tstop', Tstatic); %#ok<SAGROW>
end
cases(end+1) = struct('set', 'B', 'id', 'P1', 'Dstart', 0.66, 'Gsched', [0 gm('P1').G(:)'], 'Tstop', 1.5);
cases(end+1) = struct('set', 'B', 'id', 'P3', 'Dstart', 0.75, 'Gsched', [0 gm('P3').G(:)'], 'Tstop', 1.5);
tM = [0 1.2 2.4 3.6];                       % Phase start times of set C, and the stop time
morning = {'R1', 'P1', 'P0'};
Gs = zeros(3, 17);
for j = 1:3, Gs(j,:) = [tM(j) gm(morning{j}).G(:)']; end
cases(end+1) = struct('set', 'C', 'id', 'R1>P1>P0', 'Dstart', cfg.mppt.Dstart, 'Gsched', Gs, 'Tstop', tM(4));

%% Simulation
if redraw_only
    L = load(fullfile(resDir, 'gmppt_compare.mat'));
    R = L.R; tM = L.tM; morning = L.morning; algs = L.algs;
    fprintf('Loaded %d runs from gmppt_results.mat. No simulation.\n', numel(R));
else
    nC   = numel(cases);
    runs = struct('c', {}, 'alg', {});
    in   = Simulink.SimulationInput.empty;
    for a = algs
        for k = 1:nC
            m = cfg.mppt;
            m.alg    = a;
            m.Dstart = cases(k).Dstart;
            s = Simulink.SimulationInput(mdl);
            s = s.setVariable('mppt',   m,               'Workspace', mdl);
            s = s.setVariable('Gsched', cases(k).Gsched, 'Workspace', mdl);
            s = s.setVariable('Tstop',  cases(k).Tstop,  'Workspace', mdl);
            in(end+1)   = s; %#ok<SAGROW>
            runs(end+1) = struct('c', k, 'alg', a); %#ok<SAGROW>
        end
    end
    tic;
    out = sim(in, 'ShowProgress', 'off');
    fprintf('%d runs in %.0f s\n', numel(in), toc);

    %% Results
    R = struct('set', {}, 'id', {}, 'alg', {}, 'algName', {}, 'Dstart', {}, 't', {}, 'V', {}, ...
               'P', {}, 'D', {}, 'ph', {}, 'Vm', {}, 'Pm', {}, 'Vend', {}, 'Pend', {}, 'Vswing', {}, ...
               'Pgmpp', {}, 'pct', {}, 'onPeak', {}, 'nSearch', {}, 'tHand', {}, 't98', {}, 'eff1s', {});
    for k = 1:numel(runs)
        c = cases(runs(k).c);
        o = out(k);
        r = struct();
        r.set = c.set; r.id = c.id; r.alg = runs(k).alg; r.algName = algName{r.alg};
        r.Dstart = c.Dstart;
        r.t = o.Ppv.Time; r.V = o.Vpv.Data; r.P = o.Ppv.Data; r.D = o.D.Data;
        r.ph = squeeze(o.ph.Data);
        np = squeeze(o.np.Data);
        keep = o.Vm.Data > 0;
        r.Vm = o.Vm.Data(keep); r.Pm = o.Vm.Data(keep) .* o.Im.Data(keep);
        last = r.t > c.Tstop - 0.3;
        r.Vend = mean(r.V(last)); r.Pend = mean(r.P(last));
        r.Vswing = max(r.V(last)) - min(r.V(last));
        kh = find(r.ph == 2, 1);                       % First sample of the tracking phase
        r.tHand = r.t(kh);
        r.nSearch = max([0; np(1:kh)]);
        kl = find(r.P < 0.98 * r.Pend, 1, 'last');     % Last sample below 98 % of the final power
        r.t98 = r.t(min(kl + 1, numel(r.t)));
        if r.set == 'C'
            r.Pgmpp = NaN; r.pct = NaN; r.onPeak = ''; r.eff1s = NaN;
        else
            g = gm(r.id);
            r.Pgmpp = g.gmpp(2);
            r.pct = 100 * r.Pend / r.Pgmpp;
            r.eff1s = 100 * mean(r.P(r.t <= 1)) / r.Pgmpp;
            [~, j] = min(abs(g.peaks(:,1) - r.Vend));
            if abs(g.peaks(j,1) - g.gmpp(1)) < 0.5, r.onPeak = 'global';
            else, r.onPeak = sprintf('local, %.1f V', g.peaks(j,1)); end
        end
        R(k) = r;
    end

    fprintf('\n%-7s %-3s %-9s %-6s %6s %7s %7s %8s %8s %8s %7s  %s\n', 'Alg', 'Set', 'Pattern', 'Dstart', ...
            'Probes', 'tHand', 't98', 'P end', '% GMPP', '1 s %', 'V swing', 'Stops on');
    fid = fopen(fullfile(resDir, 'gmppt_compare.csv'), 'w');
    fprintf(fid, ['alg,set,pattern,Dstart,search_probes,t_handover_s,t98_s,V_end_V,P_end_W,P_gmpp_W,' ...
                  'pct_of_gmpp,pct_first_1s,V_swing_V,stops_on\n']);
    for k = 1:numel(R)
        r = R(k);
        if r.set == 'C', continue; end
        fprintf('%-7s %-3s %-9s %-6.2f %6d %6.3f s %5.3f s %6.0f W %8.1f %8.1f %5.2f V  %s\n', r.algName, ...
                r.set, r.id, r.Dstart, r.nSearch, r.tHand, r.t98, r.Pend, r.pct, r.eff1s, r.Vswing, r.onPeak);
        fprintf(fid, '%s,%s,%s,%.2f,%d,%.4f,%.4f,%.2f,%.1f,%.1f,%.2f,%.2f,%.2f,"%s"\n', r.algName, r.set, ...
                r.id, r.Dstart, r.nSearch, r.tHand, r.t98, r.Vend, r.Pend, r.Pgmpp, r.pct, r.eff1s, ...
                r.Vswing, r.onPeak);
    end
    for a = algs
        rc = R([R.set] == 'C' & [R.alg] == a);
        fprintf('\nSet C, winter morning, %s:\n', algName{a});
        for j = 1:3
            sel = rc.t > tM(j+1) - 0.3 & rc.t <= tM(j+1);
            g = gm(morning{j});
            p = mean(rc.P(sel));
            sw_ = max(rc.V(sel)) - min(rc.V(sel));
            fprintf('  %.1f s to %.1f s  %-3s  P %5.0f W of %5.0f W (%5.1f %%) at %.1f V, V swing %.2f V\n', ...
                    tM(j), tM(j+1), morning{j}, p, g.gmpp(2), 100 * p / g.gmpp(2), mean(rc.V(sel)), sw_);
            fprintf(fid, '%s,C,%s,%.2f,%d,%.4f,,%.2f,%.1f,%.1f,%.1f,,%.2f,"phase %.1f s to %.1f s"\n', ...
                    algName{a}, morning{j}, rc.Dstart, rc.nSearch, rc.tHand, mean(rc.V(sel)), p, ...
                    g.gmpp(2), 100 * p / g.gmpp(2), sw_, tM(j), tM(j+1));
        end
    end
    fclose(fid);
    save(fullfile(resDir, 'gmppt_compare.mat'), 'R', 'cases', 'cfg', 'tM', 'morning', 'algs', 'algName');

    % Algorithms 1, 3 and 4 must give the same results as run_gmppt_demo.m.
    O = load(fullfile(resDir, 'gmppt_results.mat'));
    dmax = 0;
    for k = find(ismember([R.alg], [1 3 4]) & [R.set] ~= 'C')
        o = O.R([O.R.alg] == R(k).alg & [O.R.set] == R(k).set & strcmp({O.R.id}, R(k).id));
        dmax = max([dmax, abs(o.pct - R(k).pct), abs(o.nSearch - R(k).nSearch)]);
    end
    fprintf('\nLargest difference from gmppt_results.mat (algs 1, 3, 4, sets A and B): %.4g\n', dmax);
end   % if redraw_only

%% Figures (the plot functions are in the folder plots)
exportgraphics(plot_gmppt_summary(R, algs, algName, algCol, gm, st), ...
               fullfile(resDir, 'fig_compare_summary.png'), 'Resolution', 200);
exportgraphics(plot_gmppt_time(R, {'P1', 'P3', 'R1'}, algs, algName, algCol, gm, st), ...
               fullfile(resDir, 'fig_compare_time.png'), 'Resolution', 200);
for a = algs(algs >= 6)
    exportgraphics(plot_morning(R([R.set] == 'C' & [R.alg] == a), algName{a}, algCol(a,:), gm, st, tM, morning), ...
                   fullfile(resDir, sprintf('fig_%s_morning.png', algFile{a})), 'Resolution', 200);
end
close all
fprintf('\nSaved results in %s\n', resDir);
