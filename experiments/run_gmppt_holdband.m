%RUN_GMPPT_HOLDBAND Hold band of the variable-step INC after a global search.
%
%   Made on 2026-11-21. The script runs MPPT_4x4.slx from start-up on each
%   pattern of shading_patterns.m, for the searches 3 to 7 (DIRECT, Idea B
%   refined, Idea C, PSO, GWO), with the variable-step INC as the local
%   stage (mppt.local = 2). It repeats each run for four values of the
%   hold band mppt.eps_inc: 0.30 (the value of pv4x4_config.m), 0.10, 0.05
%   and 0.02. The script sets eps_inc only in the runs of the searches, so
%   the INC of mppt.alg = 2 is not part of this test. All the other values
%   come from pv4x4_config.m. The timer restart is off.
%
%   Times for each run, from the start of the run (t = 0):
%     tHand    time of the hand-over to the local stage [s]
%     tConv    time after which the power stays within 0.02 points (of the
%              GMPP) below its final value [s]
%     t999     time after which the power stays at 99.9 % of the GMPP or
%              more [s]. NaN if the final power is below 99.9 %.
%     tLocal   tConv - tHand: time that the local stage needs [s]
%   Also: pct (final power, % of the GMPP), effRun (mean power over the
%   run, % of the GMPP), nSearch (search probes).
%
%   Outputs in the folder "results": gmppt_holdband.mat, gmppt_holdband.csv
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
epsList = [0.30 0.10 0.05 0.02];
Tstop   = 4;

runs = struct('id', {}, 'alg', {}, 'eps', {});
in = Simulink.SimulationInput.empty;
for e = epsList
    for a = 3:7
        for k = 1:numel(sw)
            m = cfg.mppt;
            m.alg = a; m.local = 2; m.T_rescan = 0; m.eps_inc = e;
            s = Simulink.SimulationInput(mdl);
            s = s.setVariable('mppt',   m,                  'Workspace', mdl);
            s = s.setVariable('Gsched', [0 sw(k).G(:)'],    'Workspace', mdl);
            s = s.setVariable('Tstop',  Tstop,              'Workspace', mdl);
            in(end+1) = s; %#ok<SAGROW>
            runs(end+1) = struct('id', sw(k).id, 'alg', a, 'eps', e); %#ok<SAGROW>
        end
    end
end
sim_pool(4);                                % 4 workers: RAM use of about 10 to 12 GiB (sim_pool.m)
tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
fprintf('%d runs in %.0f s\n', numel(in), toc);

R = struct([]);
for k = 1:numel(runs)
    o = out(k);
    r = runs(k);
    r.algName = algName{r.alg};
    r.err = o.ErrorMessage;
    if ~isempty(r.err)
        fprintf('Run %d (%s, %s, eps %.2f): %s\n', k, r.algName, r.id, r.eps, r.err);
    end
    r = gmppt_metrics(r, o, gm(r.id), Tstop);
    r.tConv = NaN; r.t999 = NaN; r.tLocal = NaN;
    if isempty(r.err)
        kl = find(r.P < r.Pend - 2e-4 * r.Pgmpp, 1, 'last');
        r.tConv = r.t(min(kl + 1, numel(r.t)));
        if r.pct >= 99.9
            kl = find(r.P < 0.999 * r.Pgmpp, 1, 'last');
            r.t999 = r.t(min(kl + 1, numel(r.t)));
        end
        r.tLocal = r.tConv - r.tHand;
    end
    r = rmfield(r, {'t', 'V', 'P', 'D', 'ph'});
    if isempty(R), R = r; else, R(end+1) = r; end %#ok<AGROW>
end

fid = fopen(fullfile(resDir, 'gmppt_holdband.csv'), 'w');
fprintf(fid, 'eps_inc,alg,pattern,search_probes,t_handover_s,t_conv_s,t_local_s,t999_s,pct_end,pct_run,stops_on\n');
for k = 1:numel(R)
    r = R(k);
    fprintf(fid, '%.2f,%s,%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,"%s"\n', r.eps, r.algName, r.id, r.nSearch, ...
            r.tHand, r.tConv, r.tLocal, r.t999, r.pct, r.effRun, r.onPeak);
end
fclose(fid);
save(fullfile(resDir, 'gmppt_holdband.mat'), 'R', 'cfg', 'epsList', 'algName', 'Tstop');

% Summary for each search and each eps_inc. d = difference from eps_inc = 0.30.
fprintf('\n%-7s %5s %13s %13s %13s %15s %9s %9s %10s %10s\n', 'Alg', 'eps', 'tHand mn/max', 'tConv mn/max', ...
        'tLocal mn/max', 'End % mn/min', 'Run %', 'n<99.9', 'd tConv', 'd Run %');
for a = 3:7
    B = R([R.alg] == a & [R.eps] == epsList(1));
    for e = epsList
        X = R([R.alg] == a & [R.eps] == e);
        fprintf('%-7s %5.2f %6.2f/%5.2f %6.2f/%5.2f %6.2f/%5.2f %7.3f/%6.3f %9.2f %9d %+10.3f %+10.3f\n', ...
                algName{a}, e, mean([X.tHand]), max([X.tHand]), mean([X.tConv]), max([X.tConv]), ...
                mean([X.tLocal]), max([X.tLocal]), mean([X.pct]), min([X.pct]), mean([X.effRun]), ...
                sum([X.pct] < 99.9), mean([X.tConv] - [B.tConv]), mean([X.effRun] - [B.effRun]));
    end
end
fprintf('\nSaved results in %s\n', resDir);
