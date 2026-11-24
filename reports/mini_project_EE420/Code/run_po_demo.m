%RUN_PO_DEMO Show that P&O and INC on the duty cycle stop on a local peak.
%
%   The script runs MPPT_4x4.slx for each case of the section "Cases",
%   once for each algorithm in the list algs (1 = P&O, 2 = INC). The sets:
%     A. Start-up. Each pattern of shading_patterns.m, from the start duty
%        (array near Voc). The tracker climbs to the first peak it meets,
%        which is the highest-voltage peak.
%     B. Start point. P1 and P3 again, with a different start duty. The
%        peak that the tracker finds depends on where it starts.
%     C. Winter morning. The inter-row shadow R1 shrinks to the row shading
%        P1, then the sky is clear (P0). The tracker stays on a local peak
%        until the shade is gone.
%     D. Your own cases.
%   The global peak (GMPP) of each pattern comes from run_pv4x4_sweeps.m.
%
%   Outputs in the folder "results". <alg> is "po" or "inc".
%     mppt_results.mat, mppt_results.csv   all runs of both algorithms
%     fig_<alg>_startup.png   power reached as a percentage of the GMPP, set A
%     fig_<alg>_trap.png      operating points on the P-V curves of P1 and P3
%     fig_<alg>_morning.png   power and voltage against time, set C
%     fig_po_vs_inc.png       P&O and INC side by side
%
%   Run scripts/build_mppt_4x4.m and run_pv4x4_sweeps.m first. Run time: about 5 min.
%   To draw one figure from the saved results, use graph_menu.m.
%   To change only the figures, set redraw_only = true. The script then
%   loads results/mppt_results.mat and draws the figures in about 20 s.

clear; clc;
projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir, fullfile(projectDir, 'plots'));
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));   % res: curves and GMPP of each pattern
sw  = S.res;
cfg = pv4x4_config();
st  = plot_style();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, [mdl '.slx']));
ids = {sw.id};
gm  = @(id) sw(strcmp(ids, id));

redraw_only = false;          % true: no simulation. Load results/mppt_results.mat and draw the figures again.
algs    = [1 2];              % Algorithms to run: 1 = P&O, 2 = INC
algName = {'P&O', 'INC'};
algFile = {'po', 'inc'};
algCol  = st.series([1 2], :); % P&O blue, INC orange, in every figure

%% Cases: one simulation run for each case and algorithm
% Each case is a struct with five fields:
%   set     One letter. 'A' start-up, 'B' other start point, 'C' winter
%           morning, 'D' your own cases.
%           Set A goes into fig_<alg>_startup.png. Sets A and B of P1 and
%           P3 go into fig_<alg>_trap.png. Set D goes only into the printed
%           table and mppt_results.csv.
%   id      ID of a pattern in shading_patterns.m. The table compares the
%           final power with the GMPP of this pattern. For a schedule that
%           changes, give the pattern that is active at the end.
%           For a new pattern, add it to shading_patterns.m and run
%           run_pv4x4_sweeps.m first, so that its GMPP is known.
%   Dstart  Duty at start-up. 0.30 puts the array near Voc.
%   Gsched  Irradiance schedule. One row [t, G(:)'] for each change.
%           gm('P1').G is the 4 x 4 matrix of pattern P1.
%   Tstop   Stop time [s]. The table uses the mean of the last 0.3 s.
% Each case runs once for each algorithm in algs.
Tstatic = 2.5;
cases = struct('set', {}, 'id', {}, 'Dstart', {}, 'Gsched', {}, 'Tstop', {});

% Your cases (set 'D'). Remove the % signs from an example to run it.
% cases(end+1) = struct('set', 'D', 'id', 'R2', 'Dstart', 0.70, ...
%                       'Gsched', [0 gm('R2').G(:)'], 'Tstop', 2);
% cases(end+1) = struct('set', 'D', 'id', 'P1', 'Dstart', cfg.mppt.Dstart, ...
%                       'Gsched', [0.0 gm('P0').G(:)'
%                                  1.0 gm('P1').G(:)'], 'Tstop', 2.5);

% Set A: every pattern, from start-up.
for k = 1:numel(sw)
    cases(end+1) = struct('set', 'A', 'id', sw(k).id, 'Dstart', cfg.mppt.Dstart, ...
                          'Gsched', [0 sw(k).G(:)'], 'Tstop', Tstatic); %#ok<SAGROW>
end
% Set B: P1 and P3 from a different start point.
cases(end+1) = struct('set', 'B', 'id', 'P1', 'Dstart', 0.66, 'Gsched', [0 gm('P1').G(:)'], 'Tstop', 1.5);
cases(end+1) = struct('set', 'B', 'id', 'P3', 'Dstart', 0.75, 'Gsched', [0 gm('P3').G(:)'], 'Tstop', 1.5);
% Set C: winter morning, R1 then P1 then P0. Keep only one case in set C.
tM = [0 1.2 2.4 3.6];                       % Phase start times of set C, and the stop time
morning = {'R1', 'P1', 'P0'};
Gs = zeros(3, 17);
for j = 1:3, Gs(j,:) = [tM(j) gm(morning{j}).G(:)']; end
cases(end+1) = struct('set', 'C', 'id', 'R1>P1>P0', 'Dstart', cfg.mppt.Dstart, 'Gsched', Gs, 'Tstop', tM(4));

%% Simulation inputs: every case with every algorithm
if redraw_only
    L = load(fullfile(resDir, 'mppt_results.mat'));
    R = L.R; tM = L.tM; morning = L.morning; algs = L.algs;
    fprintf('Loaded %d runs from mppt_results.mat. No simulation.\n', numel(R));
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
               'P', {}, 'D', {}, 'Vm', {}, 'Pm', {}, 'Vend', {}, 'Pend', {}, 'Vswing', {}, ...
               'Pgmpp', {}, 'pct', {}, 'onPeak', {});
    for k = 1:numel(runs)
        c = cases(runs(k).c);
        o = out(k);
        r = struct();
        r.set = c.set; r.id = c.id; r.alg = runs(k).alg; r.algName = algName{r.alg};
        r.Dstart = c.Dstart;
        r.t = o.Ppv.Time; r.V = o.Vpv.Data; r.P = o.Ppv.Data; r.D = o.D.Data;
        keep = o.Vm.Data > 0;
        r.Vm = o.Vm.Data(keep); r.Pm = o.Vm.Data(keep) .* o.Im.Data(keep);
        last = r.t > c.Tstop - 0.3;
        r.Vend = mean(r.V(last)); r.Pend = mean(r.P(last));
        r.Vswing = max(r.V(last)) - min(r.V(last));  % Peak-to-peak V at the end. 0 = the tracker holds still.
        if r.set == 'C'
            r.Pgmpp = NaN; r.pct = NaN; r.onPeak = '';
        else
            g = gm(r.id);
            r.Pgmpp = g.gmpp(2);
            r.pct = 100 * r.Pend / r.Pgmpp;
            [~, j] = min(abs(g.peaks(:,1) - r.Vend));
            if abs(g.peaks(j,1) - g.gmpp(1)) < 0.5, r.onPeak = 'global';
            else, r.onPeak = sprintf('local, %.1f V', g.peaks(j,1)); end
        end
        R(k) = r;
    end

    fprintf('\n%-4s %-3s %-9s %-7s %9s %9s %9s %7s %8s  %s\n', 'Alg', 'Set', 'Pattern', 'Dstart', ...
            'V end', 'P end', 'GMPP', '% GMPP', 'V swing', 'Stops on');
    fid = fopen(fullfile(resDir, 'mppt_results.csv'), 'w');
    fprintf(fid, 'alg,set,pattern,Dstart,V_end_V,P_end_W,P_gmpp_W,pct_of_gmpp,V_swing_V,stops_on\n');
    for k = 1:numel(R)
        r = R(k);
        if r.set == 'C', continue; end
        fprintf('%-4s %-3s %-9s %-7.2f %7.1f V %7.0f W %7.0f W %6.1f %6.2f V  %s\n', r.algName, r.set, ...
                r.id, r.Dstart, r.Vend, r.Pend, r.Pgmpp, r.pct, r.Vswing, r.onPeak);
        fprintf(fid, '%s,%s,%s,%.2f,%.2f,%.1f,%.1f,%.1f,%.2f,"%s"\n', r.algName, r.set, r.id, r.Dstart, ...
                r.Vend, r.Pend, r.Pgmpp, r.pct, r.Vswing, r.onPeak);
    end
    for a = algs
        rc = R([R.set] == 'C' & [R.alg] == a);  % The winter-morning run of this algorithm
        fprintf('\nSet C, winter morning, %s:\n', algName{a});
        for j = 1:3
            sel = rc.t > tM(j+1) - 0.3 & rc.t <= tM(j+1);
            g = gm(morning{j});
            p = mean(rc.P(sel));
            sw_ = max(rc.V(sel)) - min(rc.V(sel));
            fprintf('  %.1f s to %.1f s  %-3s  P %5.0f W of %5.0f W (%5.1f %%) at %.1f V, V swing %.2f V\n', ...
                    tM(j), tM(j+1), morning{j}, p, g.gmpp(2), 100 * p / g.gmpp(2), mean(rc.V(sel)), sw_);
            fprintf(fid, '%s,C,%s,%.2f,%.2f,%.1f,%.1f,%.1f,%.2f,"phase %.1f s to %.1f s"\n', algName{a}, ...
                    morning{j}, rc.Dstart, mean(rc.V(sel)), p, g.gmpp(2), 100 * p / g.gmpp(2), sw_, tM(j), tM(j+1));
        end
    end
    fclose(fid);
    save(fullfile(resDir, 'mppt_results.mat'), 'R', 'cases', 'cfg', 'tM', 'morning', 'algs', 'algName');
end   % if redraw_only

%% Figures (the plot functions are in the folder plots)
for a = algs
    exportgraphics(plot_startup(R([R.alg] == a), algName{a}, algCol(a,:), gm, st), ...
                   fullfile(resDir, sprintf('fig_%s_startup.png', algFile{a})), 'Resolution', 200);
    exportgraphics(plot_trap(R([R.alg] == a), algName{a}, gm, st), ...
                   fullfile(resDir, sprintf('fig_%s_trap.png', algFile{a})), 'Resolution', 200);
    exportgraphics(plot_morning(R([R.set] == 'C' & [R.alg] == a), algName{a}, algCol(a,:), gm, st, tM, morning), ...
                   fullfile(resDir, sprintf('fig_%s_morning.png', algFile{a})), 'Resolution', 200);
end
exportgraphics(plot_compare(R, algs, algName, algCol, gm, st, tM, morning), ...
               fullfile(resDir, 'fig_po_vs_inc.png'), 'Resolution', 200);
close all
fprintf('\nSaved results in %s\n', resDir);
