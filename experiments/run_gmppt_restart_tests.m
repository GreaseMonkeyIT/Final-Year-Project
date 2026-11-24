%RUN_GMPPT_RESTART_TESTS Restart rule and timer of the global searches in MPPT_4x4.slx.
%
%   Made on 2026-11-21. The script runs algorithms 3 to 7 (DIRECT, Idea B
%   refined, Idea C, PSO, GWO) on schedules where the shading changes:
%     E. P0 (no shade) to R1 at 3 s. Power falls. Three variants:
%        local 2 with restart_ref 1 (default), local 2 with restart_ref 2,
%        local 1 with restart_ref 1.
%     F. R1 to P0 at 3 s. Power rises. local 2, restart_ref 1.
%     T. P1 for 7 s with mppt.T_rescan = 1 s. Test of the timer.
%        local 2, restart_ref 1.
%     C. Winter morning: R1, then P1 at 4 s, then P0 at 8 s. local 2,
%        restart_ref 1. Each phase is long enough for the longest search.
%   All the other values come from pv4x4_config.m. Sets E, F and C use
%   mppt.T_rescan = 0, so only the power-change test can start a search.
%
%   Values for each run and each phase:
%     pct      mean power of the last 0.3 s of the phase, % of the GMPP of the phase
%     nSrch    searches that start in the phase
%     tDet     time from the start of the phase to the first search in it [s]
%     nProbe   probes of the first search in the phase
%     effPh    mean power over the phase, % of the GMPP of the phase
%
%   Outputs in the folder "results":
%     gmppt_restart_tests.mat, gmppt_restart_tests.csv
%
%   Run build/build_mppt_4x4.m and experiments/run_pv4x4_sweeps.m first.
%   The script uses parsim with 4 workers (sim_pool.m), to keep the RAM use
%   at about 10 to 12 GiB.

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
cfg = pv4x4_config();
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
ids = {sw.id};
gm  = @(id) sw(strcmp(ids, id));
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};

% Each test: set, phase patterns, phase start times and stop time, local, restart_ref, T_rescan
T = struct('set', {}, 'pats', {}, 'tph', {}, 'local', {}, 'ref', {}, 'Tres', {});
T(end+1) = struct('set', 'E', 'pats', {{'P0', 'R1'}},       'tph', [0 3 6.5],   'local', 2, 'ref', 1, 'Tres', 0);
T(end+1) = struct('set', 'E', 'pats', {{'P0', 'R1'}},       'tph', [0 3 6.5],   'local', 2, 'ref', 2, 'Tres', 0);
T(end+1) = struct('set', 'E', 'pats', {{'P0', 'R1'}},       'tph', [0 3 6.5],   'local', 1, 'ref', 1, 'Tres', 0);
T(end+1) = struct('set', 'F', 'pats', {{'R1', 'P0'}},       'tph', [0 3 6.5],   'local', 2, 'ref', 1, 'Tres', 0);
T(end+1) = struct('set', 'T', 'pats', {{'P1'}},             'tph', [0 7],       'local', 2, 'ref', 1, 'Tres', 1);
T(end+1) = struct('set', 'C', 'pats', {{'R1', 'P1', 'P0'}}, 'tph', [0 4 8 12],  'local', 2, 'ref', 1, 'Tres', 0);

runs = struct('test', {}, 'alg', {});
in = Simulink.SimulationInput.empty;
for i = 1:numel(T)
    np_ = numel(T(i).pats);
    Gs = zeros(np_, 17);
    for j = 1:np_, Gs(j,:) = [T(i).tph(j) gm(T(i).pats{j}).G(:)']; end
    for a = 3:7
        m = cfg.mppt;
        m.alg = a; m.local = T(i).local; m.restart_ref = T(i).ref; m.T_rescan = T(i).Tres;
        s = Simulink.SimulationInput(mdl);
        s = s.setVariable('mppt',   m,              'Workspace', mdl);
        s = s.setVariable('Gsched', Gs,             'Workspace', mdl);
        s = s.setVariable('Tstop',  T(i).tph(end),  'Workspace', mdl);
        in(end+1) = s; %#ok<SAGROW>
        runs(end+1) = struct('test', i, 'alg', a); %#ok<SAGROW>
    end
end
sim_pool(4);                                % 4 workers: RAM use of about 10 to 12 GiB (sim_pool.m)
tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
fprintf('%d runs in %.0f s\n', numel(in), toc);

%% Results
R = struct([]);
fid = fopen(fullfile(resDir, 'gmppt_restart_tests.csv'), 'w');
fprintf(fid, 'set,alg,local,restart_ref,T_rescan,phase,pattern,t0_s,t1_s,pct_end,n_searches,t_detect_s,probes_first,pct_phase,search_starts_s\n');
fprintf('\n%-3s %-7s %-5s %-3s %-4s %-3s %-3s %7s %5s %7s %6s %7s  %s\n', 'Set', 'Alg', 'Local', 'Ref', ...
        'Tres', 'Ph', 'Pat', 'End %', 'Srch', 'tDet', 'Probes', 'Ph %', 'Search starts [s]');
for k = 1:numel(runs)
    tt = T(runs(k).test);
    r = struct('set', tt.set, 'alg', runs(k).alg, 'algName', algName{runs(k).alg}, 'local', tt.local, ...
               'ref', tt.ref, 'Tres', tt.Tres, 'pats', {tt.pats}, 'tph', tt.tph);
    o = out(k);
    r = gmppt_metrics(r, o, gm(tt.pats{end}), tt.tph(end));
    r.phase = [];
    if ~isempty(o.ErrorMessage)
        fprintf('Run %d (%s, set %s): %s\n', k, r.algName, r.set, o.ErrorMessage);
        r = rmfield(r, {'t', 'V', 'D'});
        if isempty(R), R = r; else, R(end+1) = r; end %#ok<AGROW>
        continue
    end
    np = squeeze(o.np.Data); tp = o.ph.Time;
    phs = cell(1, numel(tt.pats));
    for j = 1:numel(tt.pats)
        t0 = tt.tph(j); t1 = tt.tph(j+1);
        g = gm(tt.pats{j});
        sel = r.t > t1 - 0.3 & r.t <= t1;
        pct = 100 * mean(r.P(sel)) / g.gmpp(2);
        inph = r.tSrch(r.tSrch >= t0 & r.tSrch < t1);
        if isempty(inph)
            tDet = NaN; nPr = 0;
        else
            tDet = inph(1) - t0;
            k0 = find(tp >= inph(1), 1);
            k1 = find(r.ph == 2 & (1:numel(r.ph))' > k0, 1);
            if isempty(k1), k1 = numel(np); end
            nPr = max(np(k0:k1));
        end
        selp = r.t >= t0 & r.t <= t1;
        effPh = 100 * trapz(r.t(selp), r.P(selp)) / (t1 - t0) / g.gmpp(2);
        phs{j} = struct('pat', tt.pats{j}, 't0', t0, 't1', t1, 'pct', pct, 'nSrch', numel(inph), ...
                            'tDet', tDet, 'nProbe', nPr, 'effPh', effPh, 'starts', inph);
        sst = strjoin(arrayfun(@(x) sprintf('%.3f', x), inph, 'UniformOutput', false), ' ');
        fprintf('%-3s %-7s %-5d %-3d %-4g %-3d %-3s %7.2f %5d %7.3f %6d %7.1f  %s\n', r.set, r.algName, ...
                r.local, r.ref, r.Tres, j, tt.pats{j}, pct, numel(inph), tDet, nPr, effPh, sst);
        fprintf(fid, '%s,%s,%d,%d,%g,%d,%s,%.2f,%.2f,%.3f,%d,%.4f,%d,%.3f,"%s"\n', r.set, r.algName, ...
                r.local, r.ref, r.Tres, j, tt.pats{j}, t0, t1, pct, numel(inph), tDet, nPr, effPh, sst);
    end
    r.phase = [phs{:}];
    r = rmfield(r, {'t', 'V', 'D'});            % Keep the file small: P and ph stay
    if isempty(R), R = r; else, R(end+1) = r; end %#ok<AGROW>
end
fclose(fid);
save(fullfile(resDir, 'gmppt_restart_tests.mat'), 'R', 'T', 'cfg', 'algName');
fprintf('\nSaved results in %s\n', resDir);
