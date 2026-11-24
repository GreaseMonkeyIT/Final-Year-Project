%RUN_GMPPT_LOCAL3 Parabolic local stage (mppt.local = 3) against the variable-step INC.
%
%   Made on 2026-11-21. The script runs MPPT_4x4.slx with the searches 3 to
%   5 (DIRECT, Idea B refined, Idea C). PSO and GWO are not part of this
%   test (decision of the user, 2026-11-21).
%     Part 1. Each pattern of shading_patterns.m from start-up, 4 s, with
%             three local stages: variable-step INC with eps_inc = 0.30
%             (the config value), variable-step INC with eps_inc = 0.10,
%             and the parabolic stage (local = 3). T_rescan = 0.
%     Part 2. The restart sets of run_gmppt_restart_tests.m with the
%             parabolic stage: E (P0 to R1 at 3 s), F (R1 to P0 at 3 s),
%             C (R1, P1 at 4 s, P0 at 8 s) and T (P1, T_rescan = 1 s).
%   All the other values come from pv4x4_config.m.
%
%   Values of part 1: pct (final power, % of the GMPP), effRun (mean power
%   over the run, % of the GMPP), t999 (time after which the power stays at
%   99.9 % of the GMPP or more, from t = 0), nSrch (searches), nMove (duty
%   changes after the end of the first 0.5 s of the local stage).
%   Values of part 2 for each phase: searches, detection time, end power.
%
%   Outputs in the folder "results": gmppt_local3.mat, gmppt_local3.csv
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
V1 = struct('name', {'VS-INC 0.30', 'VS-INC 0.10', 'Parabolic'}, 'local', {2, 2, 3}, 'eps', {0.30, 0.10, 0.30});

runs = struct('part', {}, 'alg', {}, 'var', {}, 'pats', {}, 'tph', {}, 'Tres', {}, 'set', {});
for v = 1:numel(V1)
    for a = 3:5
        for k = 1:numel(sw)
            runs(end+1) = struct('part', 1, 'alg', a, 'var', v, 'pats', {{sw(k).id}}, 'tph', [0 4], ...
                                 'Tres', 0, 'set', 'A'); %#ok<SAGROW>
        end
    end
end
sets = struct('set', {'E', 'F', 'C', 'T'}, 'pats', {{'P0', 'R1'}, {'R1', 'P0'}, {'R1', 'P1', 'P0'}, {'P1'}}, ...
              'tph', {[0 3 6.5], [0 3 6.5], [0 4 8 12], [0 7]}, 'Tres', {0, 0, 0, 1});
for s = 1:numel(sets)
    for a = 3:5
        runs(end+1) = struct('part', 2, 'alg', a, 'var', 3, 'pats', {sets(s).pats}, 'tph', sets(s).tph, ...
                             'Tres', sets(s).Tres, 'set', sets(s).set); %#ok<SAGROW>
    end
end

in = Simulink.SimulationInput.empty;
for k = 1:numel(runs)
    r = runs(k);
    m = cfg.mppt;
    m.alg = r.alg; m.local = V1(r.var).local; m.eps_inc = V1(r.var).eps; m.T_rescan = r.Tres;
    Gs = zeros(numel(r.pats), 17);
    for j = 1:numel(r.pats), Gs(j,:) = [r.tph(j) gm(r.pats{j}).G(:)']; end
    s = Simulink.SimulationInput(mdl);
    s = s.setVariable('mppt',   m,           'Workspace', mdl);
    s = s.setVariable('Gsched', Gs,          'Workspace', mdl);
    s = s.setVariable('Tstop',  r.tph(end),  'Workspace', mdl);
    in(end+1) = s; %#ok<SAGROW>
end
sim_pool(4);                                % 4 workers: RAM use of about 10 to 12 GiB (sim_pool.m)
t0 = tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
tRun = toc(t0);
fprintf('%d runs in %.0f s on 4 workers\n', numel(in), tRun);

R = struct([]);
for k = 1:numel(runs)
    r = runs(k); o = out(k);
    r.algName = algName{r.alg}; r.varName = V1(r.var).name; r.err = o.ErrorMessage;
    if ~isempty(r.err), fprintf('Run %d (%s, %s): %s\n', k, r.algName, r.varName, r.err); end
    r = gmppt_metrics(r, o, gm(r.pats{end}), r.tph(end));
    r.t999 = NaN; r.nMove = NaN; r.phase = [];
    if isempty(r.err)
        if r.pct >= 99.9
            kl = find(r.P < 0.999 * r.Pgmpp, 1, 'last');
            r.t999 = r.t(min(kl + 1, numel(r.t)));
        end
        tD = o.D.Time; D = squeeze(o.D.Data);
        sel = tD > r.tHand + 0.5;
        r.nMove = sum(abs(diff(D(sel))) > 1e-9);
        if r.part == 2
            phs = cell(1, numel(r.pats));
            for j = 1:numel(r.pats)
                t0p = r.tph(j); t1p = r.tph(j+1); g = gm(r.pats{j});
                inph = r.tSrch(r.tSrch >= t0p & r.tSrch < t1p);
                pct = 100 * mean(r.P(r.t > t1p - 0.3 & r.t <= t1p)) / g.gmpp(2);
                tDet = NaN; if ~isempty(inph), tDet = inph(1) - t0p; end
                phs{j} = struct('pat', r.pats{j}, 'pct', pct, 'nSrch', numel(inph), 'tDet', tDet, 'starts', inph);
            end
            r.phase = [phs{:}];
        end
    end
    r = rmfield(r, {'t', 'V', 'P', 'D', 'ph'});
    if isempty(R), R = r; else, R(end+1) = r; end %#ok<AGROW>
end

fid = fopen(fullfile(resDir, 'gmppt_local3.csv'), 'w');
fprintf(fid, 'part,set,alg,local_stage,pattern,search_probes,t_handover_s,pct_end,pct_run,t999_s,n_searches,n_moves,V_swing_V\n');
for k = 1:numel(R)
    r = R(k);
    fprintf(fid, '%d,%s,%s,%s,%s,%d,%.3f,%.3f,%.3f,%.3f,%d,%d,%.3f\n', r.part, r.set, r.algName, r.varName, ...
            strjoin(r.pats, '>'), r.nSearch, r.tHand, r.pct, r.effRun, r.t999, r.nSrch, r.nMove, r.Vswing);
end
fclose(fid);
save(fullfile(resDir, 'gmppt_local3.mat'), 'R', 'cfg', 'V1', 'sets', 'tRun');

fprintf('\nPart 1: nine patterns, 4 s\n%-7s %-12s %15s %10s %15s %9s %8s %8s\n', 'Alg', 'Local', 'End % mn/min', ...
        'Run %', 't999 mn/max', 'Searches', 'Moves', 'Vswing');
for a = 3:5
    for v = 1:numel(V1)
        X = R([R.part] == 1 & [R.alg] == a & [R.var] == v);
        t = [X.t999];
        fprintf('%-7s %-12s %7.3f/%7.3f %10.3f %7.3f/%6.3f %9d %8.1f %8.2f\n', algName{a}, V1(v).name, ...
                mean([X.pct]), min([X.pct]), mean([X.effRun]), mean(t(~isnan(t))), max(t), max([X.nSrch]), ...
                mean([X.nMove]), max([X.Vswing]));
    end
end
fprintf('\nPart 2: restart sets with the parabolic stage\n');
for k = find([R.part] == 2)
    r = R(k);
    for j = 1:numel(r.phase)
        ph = r.phase(j);
        fprintf('%s %-7s phase %d %-3s searches %d, detect %.3f s, end %.3f %%, starts %s\n', r.set, r.algName, ...
                j, ph.pat, ph.nSrch, ph.tDet, ph.pct, mat2str(ph.starts, 3));
    end
end
fprintf('\nSaved results in %s\n', resDir);
