%RUN_GMPPT_BASELINE Baseline of the global searches in MPPT_4x4.slx.
%
%   Made on 2026-11-21 from experiments/templates/run_gmppt_compare.m.
%   The script runs MPPT_4x4.slx from start-up on each pattern of
%   shading_patterns.m, for each search and each local stage:
%     1 P&O and 2 INC (references, no search, no local stage)
%     3 DIRECT (Nguyen and Low 2010)        4 Idea B refined
%     5 Idea C                              6 PSO (Ishaque et al. 2012)
%     7 GWO (Mohanty et al. 2016)
%   mppt.local = 1 (P&O) and 2 (variable-step INC) for algorithms 3 to 7.
%   All the values come from pv4x4_config.m. No value is tuned. The timer
%   restart is off (mppt.T_rescan = 0), so each run measures one search
%   and its local stage. The power-change restart stays on.
%
%   Values for each run:
%     nSearch   search probes of the first search
%     tSearch   time from the first probe to the hand-over [s]
%     tHand     time of the hand-over [s]
%     Dhand     hand-over duty
%     pctHand   power in the first local period (second half), % of the GMPP
%     pct       final power (mean of the last 0.3 s), % of the GMPP
%     Vswing    peak-to-peak voltage in the last 0.3 s [V]
%     nSrch     number of searches in the run
%     t98       time after which the power stays at 98 % of the final power or more [s]
%     eff1s     mean power over the first 1 s, % of the GMPP
%     effRun    mean power over the full run, % of the GMPP
%
%   Outputs in the folder "results":
%     gmppt_baseline.mat, gmppt_baseline.csv   all runs
%     fig_baseline_summary_local<k>.png        final power, probes and t98
%
%   Run build/build_mppt_4x4.m and experiments/run_pv4x4_sweeps.m first.
%   The script uses parsim with 4 workers (sim_pool.m), to keep the RAM use
%   at about 10 to 12 GiB.

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));   % This script is in <project>/experiments
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
cfg = pv4x4_config();
st  = plot_style();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
ids = {sw.id};
gm  = @(id) sw(strcmp(ids, id));

algs    = [1 2 3 4 5 6 7];
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
algCol  = st.series([1 2 3 7 8 4 5], :);   % One colour for each algorithm
locName = {'P&O', 'VS-INC'};
Tstop   = 4;                                % [s]. The longest search (PSO, 60 probes) ends near 2.5 s.

%% Runs: each pattern, each algorithm, each local stage (algorithms 3 to 7)
runs = struct('id', {}, 'alg', {}, 'local', {});
for a = algs
    if a <= 2, locs = 0; else, locs = [1 2]; end
    for lo = locs
        for k = 1:numel(sw)
            runs(end+1) = struct('id', sw(k).id, 'alg', a, 'local', lo); %#ok<SAGROW>
        end
    end
end
in = Simulink.SimulationInput.empty;
for k = 1:numel(runs)
    m = cfg.mppt;
    m.alg      = runs(k).alg;
    m.T_rescan = 0;
    if runs(k).local > 0, m.local = runs(k).local; end
    s = Simulink.SimulationInput(mdl);
    s = s.setVariable('mppt',   m,                          'Workspace', mdl);
    s = s.setVariable('Gsched', [0 gm(runs(k).id).G(:)'],   'Workspace', mdl);
    s = s.setVariable('Tstop',  Tstop,                      'Workspace', mdl);
    in(end+1) = s; %#ok<SAGROW>
end
sim_pool(4);                                % 4 workers: RAM use of about 10 to 12 GiB (sim_pool.m)
tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
fprintf('%d runs in %.0f s\n', numel(in), toc);

%% Results
R = struct([]);
for k = 1:numel(runs)
    o = out(k);
    r = runs(k);
    r.set = 'A';
    r.algName = algName{r.alg};
    if r.local > 0, r.locName = locName{r.local}; else, r.locName = '-'; end
    r.err = o.ErrorMessage;
    if ~isempty(r.err)
        fprintf('Run %d (%s, %s): %s\n', k, r.algName, r.id, r.err);
    end
    r = gmppt_metrics(r, o, gm(r.id), Tstop);
    if isempty(R), R = r; else, R(end+1) = r; end %#ok<AGROW>
end

fprintf('\n%-7s %-6s %-3s %6s %7s %6s %7s %7s %7s %6s %7s %7s %7s  %s\n', 'Alg', 'Local', 'Pat', ...
        'Probes', 'tSrch', 'Dhand', 'Hand %', 'End %', 'Vswing', 'Srch', 't98', '1 s %', 'Run %', 'Stops on');
fid = fopen(fullfile(resDir, 'gmppt_baseline.csv'), 'w');
fprintf(fid, ['alg,local,pattern,search_probes,t_search_s,t_handover_s,D_handover,pct_handover,' ...
              'P_end_W,P_gmpp_W,pct_end,V_swing_V,n_searches,t98_s,pct_first_1s,pct_run,stops_on\n']);
for k = 1:numel(R)
    r = R(k);
    fprintf('%-7s %-6s %-3s %6d %6.3f %6.3f %7.2f %7.2f %6.2f %6d %6.3f %7.1f %7.1f  %s\n', r.algName, ...
            r.locName, r.id, r.nSearch, r.tSearch, r.Dhand, r.pctHand, r.pct, r.Vswing, r.nSrch, ...
            r.t98, r.eff1s, r.effRun, r.onPeak);
    fprintf(fid, '%s,%s,%s,%d,%.4f,%.4f,%.4f,%.3f,%.1f,%.1f,%.3f,%.3f,%d,%.4f,%.2f,%.2f,"%s"\n', ...
            r.algName, r.locName, r.id, r.nSearch, r.tSearch, r.tHand, r.Dhand, r.pctHand, r.Pend, ...
            r.Pgmpp, r.pct, r.Vswing, r.nSrch, r.t98, r.eff1s, r.effRun, r.onPeak);
end
fclose(fid);
save(fullfile(resDir, 'gmppt_baseline.mat'), 'R', 'cfg', 'algs', 'algName', 'locName', 'Tstop');

%% Figures (one for each local stage, with P&O as the reference)
for lo = [1 2]
    sel = [R.alg] <= 2 | [R.local] == lo;
    f = plot_gmppt_summary(R(sel), [1 3 4 5 6 7], algName, algCol, gm, st);
    exportgraphics(f, fullfile(resDir, sprintf('fig_baseline_summary_local%d.png', lo)), 'Resolution', 200);
end
close all
fprintf('\nSaved results in %s\n', resDir);
