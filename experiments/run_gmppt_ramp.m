%RUN_GMPPT_RAMP Irradiance ramp test of the local stages after a global search.
%
%   Made on 2026-11-21. The ramp follows the description of EN 50530:2010,
%   Table B.2, row 4, in Andrean, Chang and Lian, Energies 11, 2018,
%   section 3.4: from 30 % to 100 % of the irradiance and back, with a slope
%   of 30 W/m^2 per s and a dwell of 10 s at 100 %. The standard itself is
%   not in docs/references/. Profile: 3 s at 30 %, ramp up (23.3 s), 10 s at
%   100 %, ramp down (23.3 s), 3 s at 30 %. The whole matrix G of the
%   pattern is scaled by s(t), so the shape of the shade stays.
%
%   The irradiance schedule of MPPT_4x4.slx does not interpolate, so the
%   ramp is a table of steps of 10 ms. The input filter (cfg.G_tau = 1 ms)
%   smooths each step.
%
%   Reference. PV4x4_sweep.slx sweeps each pattern at s = 0.30 to 1.00 in
%   steps of 0.05. The GMPP at s(t) is a pchip interpolation of these
%   powers. Dynamic efficiency (Andrean et al., Eq. (10)): the integral of
%   P over the integral of the GMPP, from t = 2 s to the end.
%
%   Runs: patterns P0 and R1, searches 3 to 5 (DIRECT, Idea B, Idea C),
%   four local stages: P&O (local = 1), variable-step INC with restart_ref
%   1 and 2, and the parabolic stage (local = 3). T_rescan = 0.
%
%   Outputs in the folder "results": gmppt_ramp.mat, gmppt_ramp.csv
%   The script uses parsim with 4 workers (sim_pool.m).

clear; clc;
projectDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectDir, 'startup.m'));
resDir = fullfile(projectDir, 'results');
S   = load(fullfile(resDir, 'pv4x4_sweeps.mat'));
sw  = S.res;
ids = {sw.id};
cfg = pv4x4_config();
algName = {'P&O', 'INC', 'DIRECT', 'Idea B', 'Idea C', 'PSO', 'GWO'};
pats = {'P0', 'R1'};

%% Ramp profile s(t)
tUp = 0.7 / 0.03;                           % 23.3 s from 30 % to 100 % at 3 %/s (30 W/m^2/s)
tk  = [0, 3, 3 + tUp, 13 + tUp, 13 + 2 * tUp, 16 + 2 * tUp];
sk  = [0.3, 0.3, 1.0, 1.0, 0.3, 0.3];
Tstop = tk(end);
sfun = @(t) interp1(tk, sk, t, 'linear');
tg = (0:0.01:Tstop)';

%% Reference sweeps at s = 0.30 to 1.00
sl = 0.30:0.05:1.00;
sim_pool(4);                                % 4 workers: RAM use of about 10 to 12 GiB (sim_pool.m)
load_system(fullfile(projectDir, 'models', 'PV4x4_sweep.slx'));
in = Simulink.SimulationInput.empty;
for k = 1:numel(pats)
    G0 = sw(strcmp(ids, pats{k})).G;
    for j = 1:numel(sl)
        in(end+1) = Simulink.SimulationInput('PV4x4_sweep').setVariable('G', sl(j) * G0, 'Workspace', 'PV4x4_sweep'); %#ok<SAGROW>
    end
end
outS = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
              'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
Pref = zeros(numel(pats), numel(sl));
for k = 1:numel(pats)
    for j = 1:numel(sl)
        Pref(k, j) = max(outS((k - 1) * numel(sl) + j).Ppv.Data);
    end
end

%% Runs
mdl = 'MPPT_4x4';
load_system(fullfile(projectDir, 'models', [mdl '.slx']));
VR = struct('name', {'P&O', 'VS-INC ref 1', 'VS-INC ref 2', 'Parabolic'}, 'local', {1, 2, 2, 3}, 'ref', {1, 1, 2, 1});
runs = struct('pat', {}, 'alg', {}, 'var', {});
in = Simulink.SimulationInput.empty;
for k = 1:numel(pats)
    G0 = sw(strcmp(ids, pats{k})).G;
    Gs = [tg, sfun(tg) * G0(:)'];
    for a = 3:5
        for v = 1:numel(VR)
            m = cfg.mppt;
            m.alg = a; m.local = VR(v).local; m.restart_ref = VR(v).ref; m.T_rescan = 0;
            s = Simulink.SimulationInput(mdl);
            s = s.setVariable('mppt', m, 'Workspace', mdl);
            s = s.setVariable('Gsched', Gs, 'Workspace', mdl);
            s = s.setVariable('Tstop', Tstop, 'Workspace', mdl);
            in(end+1) = s; %#ok<SAGROW>
            runs(end+1) = struct('pat', k, 'alg', a, 'var', v); %#ok<SAGROW>
        end
    end
end
t0 = tic;
out = parsim(in, 'ShowProgress', 'off', 'TransferBaseWorkspaceVariables', 'off', ...
             'SetupFcn', @() run(fullfile(projectDir, 'startup.m')));
tRun = toc(t0);
fprintf('%d ramp runs in %.0f s on 4 workers\n', numel(in), tRun);

%% Dynamic efficiency
R = struct([]);
segs = [2, tk(3); tk(3), tk(4); tk(4), tk(5); tk(5), tk(6)];   % up, dwell, down, end
fid = fopen(fullfile(resDir, 'gmppt_ramp.csv'), 'w');
fprintf(fid, 'pattern,alg,local_stage,eta_total,eta_up,eta_dwell,eta_down,eta_end,n_searches\n');
fprintf('\n%-3s %-7s %-13s %8s %8s %8s %8s %8s %9s\n', 'Pat', 'Alg', 'Local', 'eta %', 'up', 'dwell', 'down', 'end', 'searches');
for k = 1:numel(runs)
    r = runs(k); o = out(k);
    r.patName = pats{r.pat}; r.algName = algName{r.alg}; r.varName = VR(r.var).name; r.err = o.ErrorMessage;
    r.eta = NaN; r.etaSeg = NaN(1, 4); r.nSrch = NaN;
    if isempty(r.err)
        t = o.Ppv.Time; P = squeeze(o.Ppv.Data);
        Pg = interp1(sl, Pref(r.pat, :), sfun(t), 'pchip');
        sel = t >= 2;
        r.eta = 100 * trapz(t(sel), P(sel)) / trapz(t(sel), Pg(sel));
        for q = 1:4
            sq = t >= segs(q, 1) & t <= segs(q, 2);
            r.etaSeg(q) = 100 * trapz(t(sq), P(sq)) / trapz(t(sq), Pg(sq));
        end
        ph = squeeze(o.ph.Data);
        r.nSrch = sum(ph == 1 & [true; ph(1:end-1) ~= 1]);
    else
        fprintf('Run %d: %s\n', k, r.err);
    end
    fprintf('%-3s %-7s %-13s %8.3f %8.3f %8.3f %8.3f %8.3f %9d\n', r.patName, r.algName, r.varName, r.eta, r.etaSeg, r.nSrch);
    fprintf(fid, '%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%d\n', r.patName, r.algName, r.varName, r.eta, r.etaSeg, r.nSrch);
    if isempty(R), R = r; else, R(end+1) = r; end %#ok<AGROW>
end
fclose(fid);
save(fullfile(resDir, 'gmppt_ramp.mat'), 'R', 'cfg', 'VR', 'tk', 'sk', 'sl', 'Pref', 'pats', 'tRun');
fprintf('\nSaved results in %s\n', resDir);
